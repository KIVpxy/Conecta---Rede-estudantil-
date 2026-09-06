import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../app/tokens.dart';
import '../../core/services/permission_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'discover_page.dart' show discoverProjectsProvider;

/// Edição de um projeto existente (autor e colaboradores):
/// título, subtítulo, descrição/conteúdo e o repositório de arquivos
/// (adicionar novos ou remover existentes). Também é aqui que o
/// projeto é marcado como 100% concluído — o card "Continue seu
/// projeto" da aba Status aponta para esta tela.
class EditProjectPage extends ConsumerWidget {
  const EditProjectPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectByIdProvider(projectId));
    final me = ref.watch(currentUserProvider).value;
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;

    return projectAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (project) {
        if (project == null) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'Projeto não encontrado',
            action: AppButton(
              label: 'Voltar para Descobrir',
              onPressed: () => context.go('/projetos'),
            ),
          );
        }
        if (me == null || !project.involves(me.id)) {
          return EmptyState(
            icon: Icons.lock_outline,
            title: 'Você não participa deste projeto',
            subtitle: 'Só o autor e os colaboradores podem editá-lo.',
            action: AppButton(
              label: 'Ver projeto',
              onPressed: () => context.go('/projetos/${project.id}'),
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              // O form é um StatefulWidget separado para inicializar os
              // controllers UMA vez com os dados carregados do projeto.
              child: _EditForm(
                project: project,
                // Só o autor principal pode excluir o projeto (rodada 6)
                // — colaborador edita, mas não exclui.
                canDelete: PermissionService.canDeleteProject(me, project),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.project, required this.canDelete});

  final Project project;

  /// Somente o autor principal (PermissionService.canDeleteProject).
  final bool canDelete;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _description;
  late final TextEditingController _textContent;
  final _linkController = TextEditingController();
  late final List<ProjectMedia> _media;

  bool _saving = false;
  bool _togglingCompleted = false;
  bool _deleting = false;

  bool get _isTexto => widget.project.type == ProjectType.texto;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _title = TextEditingController(text: p.title);
    _subtitle = TextEditingController(text: p.subtitle);
    _description = TextEditingController(text: p.description);
    _textContent = TextEditingController(text: p.textContent ?? '');
    _media = [...p.media];
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _description.dispose();
    _textContent.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        _media.add(ProjectMedia(
          id: const Uuid().v4(),
          url: f.path,
          kind: ProjectMediaKind.image,
          label: f.name,
        ));
      }
    });
  }

  void _addLink() {
    final url = _linkController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _media.add(ProjectMedia(
        id: const Uuid().v4(),
        url: url,
        kind: url.contains('github.com')
            ? ProjectMediaKind.github
            : ProjectMediaKind.link,
      ));
      _linkController.clear();
    });
  }

  void _invalidate() {
    ref.invalidate(projectByIdProvider(widget.project.id));
    ref.invalidate(discoverProjectsProvider);
    ref.invalidate(savedProjectsProvider);
    // Atualiza as estatísticas da escola do autor (rodada 6).
    final sid = ref.read(currentUserProvider).value?.schoolId;
    if (sid != null) ref.invalidate(schoolStatsProvider(sid));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(projectRepositoryProvider).updateProject(
            widget.project.id,
            title: _title.text,
            subtitle: _subtitle.text,
            description: _description.text,
            textContent: _isTexto ? _textContent.text : null,
            media: _media,
          );
      _invalidate();
      if (mounted) {
        AppToast.show(context, 'Alterações salvas.');
        context.go('/projetos/${widget.project.id}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleCompleted() async {
    if (_togglingCompleted) return;
    setState(() => _togglingCompleted = true);
    try {
      final completed = !widget.project.isCompleted;
      await ref
          .read(projectRepositoryProvider)
          .setCompleted(widget.project.id, completed);
      _invalidate();
      if (mounted) {
        AppToast.show(
            context,
            completed
                ? 'Projeto marcado como concluído! 🎉'
                : 'Projeto reaberto.');
        // Recarrega o form com o novo estado.
        context.go('/projetos/${widget.project.id}');
      }
    } finally {
      if (mounted) setState(() => _togglingCompleted = false);
    }
  }

  /// Exclusão do projeto (rodada 6): confirmação obrigatória, aparência
  /// claramente destrutiva. Ao excluir, todas as relações que apontam
  /// para o projeto são removidas na camada de dados (feed, perfil,
  /// Biblioteca, pesquisa e estatísticas derivam da fonte única).
  Future<void> _delete() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Excluir projeto?'),
        content: const Text(
            'Esta ação removerá o projeto do Conecta. Tem certeza de que deseja continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir projeto',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(projectRepositoryProvider)
          .deleteProject(widget.project.id);
      ref.invalidate(discoverProjectsProvider);
      ref.invalidate(savedProjectsProvider);
      ref.invalidate(projectByIdProvider(widget.project.id));
      if (mounted) {
        AppToast.show(context, 'Projeto excluído.');
        context.go('/projetos');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Editar projeto',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        const Text('Atualize as informações e o repositório de arquivos.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xxl),

        // ---------- Informações ----------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Informações',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(controller: _title, label: 'Título'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: _subtitle, label: 'Subtítulo'),
              if (!_isTexto) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _description,
                  label: 'Descrição',
                  maxLines: 5,
                ),
              ],
              if (_isTexto) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _textContent,
                  label: 'Texto',
                  hint: 'Continue escrevendo seu texto aqui...',
                  maxLines: 10,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---------- Repositório de arquivos ----------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Repositório (${_media.length} ${_media.length == 1 ? 'arquivo' : 'arquivos'})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _linkController,
                      hint: 'Cole um link (site ou GitHub)',
                      prefixIcon: Icons.link,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Adicionar',
                    variant: AppButtonVariant.secondary,
                    onPressed: _addLink,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Adicionar imagens',
                icon: Icons.image_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: _pickImages,
              ),
              if (_media.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const Divider(color: AppColors.border, height: 1),
                for (final m in _media)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_iconFor(m.kind),
                        color: AppColors.textSecondary),
                    title: Text(m.label ?? m.url,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.textSecondary),
                      tooltip: 'Remover',
                      onPressed: () => setState(() => _media.remove(m)),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---------- Conclusão ----------
        AppCard(
          child: LayoutBuilder(
            builder: (context, cons) {
              final texts = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.isCompleted
                        ? 'Projeto concluído (100%)'
                        : 'Projeto em andamento',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    p.isCompleted
                        ? 'Concluído ${Fmt.relativeTime(p.completedAt!)}. Você ainda pode reabri-lo.'
                        : 'Quando terminar, marque como 100% concluído.',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              );
              final button = AppButton(
                label: p.isCompleted
                    ? 'Reabrir projeto'
                    : 'Marcar como 100% concluído',
                icon: p.isCompleted ? Icons.undo : Icons.check,
                variant: p.isCompleted
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                loading: _togglingCompleted,
                onPressed: _toggleCompleted,
              );
              final icon = Icon(
                p.isCompleted
                    ? Icons.check_circle
                    : Icons.rocket_launch_outlined,
                color: p.isCompleted
                    ? AppColors.accent
                    : AppColors.textSecondary,
              );
              // Em telas estreitas o botão iria para baixo do texto —
              // nunca espremer a coluna até quebrar caractere a caractere.
              if (cons.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      icon,
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: texts),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    button,
                  ],
                );
              }
              return Row(
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: texts),
                  const SizedBox(width: AppSpacing.md),
                  button,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // ---------- Zona de perigo (somente o autor principal) ----------
        if (widget.canDelete) ...[
          Container(
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.06),
              borderRadius: AppRadii.cardRadius,
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.35)),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, cons) {
                const texts = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Excluir projeto',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger)),
                    Text(
                      'Remove o projeto do Conecta, incluindo avaliações, comentários e salvamentos.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                );
                final button = TextButton.icon(
                  onPressed: _deleting ? null : _delete,
                  icon: _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Excluir projeto'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                );
                const icon =
                    Icon(Icons.delete_outline, color: AppColors.danger);
                if (cons.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(children: [
                        icon,
                        SizedBox(width: AppSpacing.md),
                        Expanded(child: texts),
                      ]),
                      Align(alignment: Alignment.centerRight, child: button),
                    ],
                  );
                }
                return Row(
                  children: [
                    icon,
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(child: texts),
                    const SizedBox(width: AppSpacing.md),
                    button,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],

        // ---------- Ações ----------
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    context.go('/projetos/${widget.project.id}'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Salvar alterações',
                icon: Icons.check,
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static IconData _iconFor(ProjectMediaKind kind) => switch (kind) {
        ProjectMediaKind.image => Icons.image_outlined,
        ProjectMediaKind.video => Icons.play_circle_outline,
        ProjectMediaKind.pdf => Icons.picture_as_pdf_outlined,
        ProjectMediaKind.github => Icons.code,
        ProjectMediaKind.link => Icons.link,
        _ => Icons.insert_drive_file_outlined,
      };
}
