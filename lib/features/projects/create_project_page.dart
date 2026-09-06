import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../app/tokens.dart';
import '../../core/utils/limits.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import 'discover_page.dart';

/// Fluxo "Novo Projeto" em 4 etapas (SPEC §11):
/// 1. Informações · 2. Repositório · 3. Colaboradores · 4. Publicação
class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({super.key});

  @override
  ConsumerState<CreateProjectPage> createState() =>
      _CreateProjectPageState();
}

class _CreateProjectPageState extends ConsumerState<CreateProjectPage> {
  int _step = 0;
  bool _publishing = false;

  // Etapa 1
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  ProjectCategory _category = ProjectCategory.ciencias;
  ProjectType _type = ProjectType.estudantil;

  // Etapa 1 — exclusivo do tipo Texto (SPEC §35–45)
  final _textContent = TextEditingController();
  TextCardTone _cardTone = TextCardTone.vinho;

  bool get _isTexto => _type == ProjectType.texto;

  // Etapa 2
  final List<ProjectMedia> _media = [];
  final _linkController = TextEditingController();

  // Etapa 3
  final _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  final List<UserProfile> _collaborators = [];

  static const _steps = [
    'Informações',
    'Repositório',
    'Colaboradores',
    'Publicação',
  ];

  bool get _stepValid => switch (_step) {
        // Texto: título e corpo obrigatórios, subtítulo opcional (§35).
        0 => _isTexto
            ? _title.text.trim().isNotEmpty &&
                _textContent.text.trim().isNotEmpty
            : _title.text.trim().isNotEmpty &&
                _subtitle.text.trim().isNotEmpty,
        _ => true,
      };

  List<String> get _tagList => _tags.text
      .split(RegExp(r'[,\s]+'))
      .where((t) => t.isNotEmpty)
      .map((t) => t.startsWith('#') ? t.substring(1) : t)
      .toList();

  @override
  Widget build(BuildContext context) {
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Novo Projeto',
                  style:
                      TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              const Text('Transforme uma ideia em projeto.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              _StepperHeader(current: _step, steps: _steps),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: switch (_step) {
                  0 => _buildInfo(),
                  1 => _buildRepository(),
                  2 => _buildCollaborators(),
                  _ => _buildPublish(),
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  if (_step > 0)
                    AppButton(
                      label: 'Voltar',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.arrow_back,
                      onPressed: () => setState(() => _step--),
                    ),
                  const Spacer(),
                  if (_step < 3)
                    AppButton(
                      label: 'Continuar',
                      icon: Icons.arrow_forward,
                      onPressed:
                          _stepValid ? () => setState(() => _step++) : null,
                    )
                  else
                    AppButton(
                      label: 'Publicar projeto',
                      icon: Icons.rocket_launch,
                      loading: _publishing,
                      onPressed: _publish,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Etapa 1: Informações ----------
  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final t in ProjectType.values)
              AppFilterChip(
                label: t.label,
                selected: _type == t,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
            controller: _title,
            label: 'Título do projeto',
            hint: _isTexto
                ? 'Ex.: Crônicas do intervalo'
                : 'Ex.: Estação meteorológica de baixo custo',
            onChanged: (_) => setState(() {})),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
            controller: _subtitle,
            label: _isTexto
                ? 'Subtítulo (opcional)'
                : 'Subtítulo / descrição curta',
            hint: 'Uma frase que resume o projeto',
            onChanged: (_) => setState(() {})),
        const SizedBox(height: AppSpacing.lg),
        if (_isTexto) ...[
          AppTextField(
            controller: _textContent,
            label: 'Texto',
            hint: 'Escreva aqui o seu texto completo...',
            maxLines: 12,
            maxLength: AppLimits.textProjectMaxLength,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Cor do card',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          ColorSelector(
            selected: _cardTone,
            onChanged: (tone) => setState(() => _cardTone = tone),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('PREVIEW AO VIVO',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          TextCardPreview(
            tone: _cardTone,
            title: _title.text.trim(),
            excerpt: _textContent.text.trim(),
          ),
        ] else
          AppTextField(
            controller: _description,
            label: 'Descrição completa',
            hint:
                'Sobre o projeto, objetivo, processo e resultados...',
            maxLines: 6,
          ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Categoria',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<ProjectCategory>(
          initialValue: _category,
          decoration: const InputDecoration(),
          items: [
            for (final c in ProjectCategory.values)
              DropdownMenuItem(value: c, child: Text(c.label)),
          ],
          onChanged: (v) => setState(() => _category = v!),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _tags,
          label: 'Tags',
          hint: 'Tecnologia, Ciência, Arduino',
        ),
      ],
    );
  }

  // ---------- Etapa 2: Repositório ----------
  Widget _buildRepository() {
    final images = _media
        .where((m) =>
            m.kind == ProjectMediaKind.image ||
            m.kind == ProjectMediaKind.video)
        .toList();
    final docs = _media
        .where((m) =>
            m.kind == ProjectMediaKind.pdf ||
            m.kind == ProjectMediaKind.file)
        .toList();
    final links = _media
        .where((m) =>
            m.kind == ProjectMediaKind.link ||
            m.kind == ProjectMediaKind.github)
        .toList();

    Widget treeItem(String indent, IconData icon, String name,
            {VoidCallback? onRemove}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Text(indent,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace')),
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ),
              if (onRemove != null)
                InkWell(
                  onTap: onRemove,
                  child: const Icon(Icons.close,
                      size: 14, color: AppColors.textSecondary),
                ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickImages,
          borderRadius: AppRadii.controlRadius,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadii.controlRadius,
              border:
                  Border.all(color: AppColors.border, style: BorderStyle.solid),
            ),
            child: const Column(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 32, color: AppColors.accentSoft),
                SizedBox(height: AppSpacing.sm),
                Text('Arraste um arquivo aqui',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: AppSpacing.xs),
                Text('ou toque para selecionar • fotos, vídeos, PDF',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                  controller: _linkController,
                  hint: 'Cole um link externo ou do GitHub...'),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: 'Adicionar',
              variant: AppButtonVariant.secondary,
              onPressed: _addLink,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_media.isNotEmpty) ...[
          const Text('REPOSITÓRIO DO PROJETO',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: AppRadii.controlRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title.text.isEmpty ? 'meu-projeto' : _title.text,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace')),
                const Divider(color: AppColors.border),
                if (images.isNotEmpty) ...[
                  treeItem('', Icons.folder_outlined, '/media'),
                  for (final m in images)
                    treeItem('    ', Icons.image_outlined,
                        m.label ?? m.url.split('/').last,
                        onRemove: () =>
                            setState(() => _media.remove(m))),
                ],
                if (docs.isNotEmpty) ...[
                  treeItem('', Icons.folder_outlined, '/documentos'),
                  for (final m in docs)
                    treeItem('    ', Icons.description_outlined,
                        m.label ?? m.url.split('/').last,
                        onRemove: () =>
                            setState(() => _media.remove(m))),
                ],
                treeItem('', Icons.description_outlined, 'README'),
                for (final m in links)
                  treeItem(
                      '',
                      m.kind == ProjectMediaKind.github
                          ? Icons.code
                          : Icons.link,
                      m.url,
                      onRemove: () =>
                          setState(() => _media.remove(m))),
              ],
            ),
          ),
        ],
      ],
    );
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

  // ---------- Etapa 3: Colaboradores ----------
  Widget _buildCollaborators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                hint: 'Adicionar colaborador',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: 'Buscar',
              variant: AppButtonVariant.secondary,
              onPressed: () async {
                final results = await ref
                    .read(projectRepositoryProvider)
                    .searchUsers(_searchController.text.trim());
                setState(() => _searchResults = results);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_collaborators.isNotEmpty) ...[
          const Text('COLABORADORES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          for (final u in _collaborators)
            UserRow(
              user: u,
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    size: 20, color: AppColors.danger),
                onPressed: () =>
                    setState(() => _collaborators.remove(u)),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_searchResults.isNotEmpty) ...[
          const Text('RESULTADOS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          for (final u in _searchResults)
            if (!_collaborators.any((c) => c.id == u.id))
              UserRow(
                user: u,
                trailing: AppButton(
                  label: 'Adicionar',
                  variant: AppButtonVariant.secondary,
                  onPressed: () =>
                      setState(() => _collaborators.add(u)),
                ),
              ),
        ] else
          const Text(
            'Pesquise usuários para construir junto — como no GitHub.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
      ],
    );
  }

  // ---------- Etapa 4: Publicação ----------
  Widget _buildPublish() {
    final me = ref.read(currentUserProvider).value;
    final draftProject = Project(
      id: 'preview',
      authorId: me?.id ?? '',
      title: _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      description: _isTexto ? _textContent.text.trim() : _description.text.trim(),
      category: _category,
      type: _type,
      tags: _tagList,
      media: _media,
      collaborators: _collaborators,
      textContent: _isTexto ? _textContent.text.trim() : null,
      cardTone: _isTexto ? _cardTone : null,
      createdAt: DateTime.now(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PREVIEW DA POSTAGEM',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        if (me != null)
          ProjectCard(
            project: draftProject,
            author: me,
            authorRank: RankTier.diamante,
          ),
      ],
    );
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final draft = ProjectDraft(
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim(),
        description:
            _isTexto ? _textContent.text.trim() : _description.text.trim(),
        category: _category,
        type: _type,
        tags: _tagList,
        media: _media,
        collaboratorIds: [for (final c in _collaborators) c.id],
        textContent: _isTexto ? _textContent.text.trim() : null,
        cardTone: _isTexto ? _cardTone : null,
      );
      final project =
          await ref.read(projectRepositoryProvider).create(draft);
      ref.invalidate(discoverProjectsProvider);
      // Atualiza as estatísticas da escola do autor (rodada 6).
      final meNow = ref.read(currentUserProvider).value;
      final sid = meNow?.schoolId;
      if (sid != null) ref.invalidate(schoolStatsProvider(sid));
      if (mounted) {
        AppToast.show(context, 'Projeto publicado! Compartilhe o que você descobriu.');
        context.go('/projetos/${project.id}');
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }
}

class _StepperHeader extends StatelessWidget {
  const _StepperHeader({required this.current, required this.steps});

  final int current;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                color: i <= current
                    ? AppColors.accent
                    : AppColors.border,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < current
                      ? AppColors.success
                      : i == current
                          ? AppColors.accent
                          : AppColors.surface3,
                ),
                child: Center(
                  child: i < current
                      ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
                      : Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: i == current
                                  ? AppColors.onAccent
                                  : AppColors.textSecondary)),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(steps[i],
                  style: TextStyle(
                      fontSize: 11,
                      color: i == current
                          ? AppColors.textPrimary
                          : AppColors.textSecondary)),
            ],
          ),
        ],
      ],
    );
  }
}
