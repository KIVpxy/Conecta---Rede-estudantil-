import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/tokens.dart';
import '../../core/services/permission_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'discover_page.dart' show discoverProjectsProvider;
import 'report_project_dialog.dart';

final _ratingsProvider =
    FutureProvider.family<List<Rating>, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).ratings(id);
});

final _authorProvider =
    FutureProvider.family<UserProfile?, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).authorOf(id);
});

final _authorRankProvider =
    FutureProvider.family<RankTier, String>((ref, id) {
  return ref.watch(profileRepositoryProvider).rankOf(id);
});

final _commentsProvider =
    FutureProvider.family<List<ProjectComment>, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).comments(id);
});

/// Página individual do projeto (SPEC §12).
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectByIdProvider(projectId));
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
        // Textos usam coluna de leitura mais estreita e confortável (§43).
        final maxWidth =
            project.type == ProjectType.texto ? 680.0 : 900.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _ProjectBody(project: project),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectBody extends ConsumerWidget {
  const _ProjectBody({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(_authorProvider(project.authorId)).value;
    final rank =
        ref.watch(_authorRankProvider(project.authorId)).value ??
            RankTier.bronze;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        if (author != null)
          UserRow(
            user: author,
            rank: rank,
            subtitle:
                '@${author.username} • ${Fmt.relativeTime(project.createdAt)}',
            onTap: () => context.go('/perfil/${author.username}'),
          ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.title,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(project.subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                ],
              ),
            ),
            if (project.isCompleted)
              Container(
                margin: const EdgeInsets.only(left: AppSpacing.md),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: AppRadii.pillRadius,
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        size: 14, color: AppColors.accent),
                    SizedBox(width: AppSpacing.xs),
                    Text('Concluído',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [for (final t in project.tags) AppTag(label: t)],
        ),
        if (project.collaborators.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              CollaboratorAvatarGroup(users: project.collaborators),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Colaboradores: ${project.collaborators.map((c) => c.name.split(' ').first).join(' • ')}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        // Ações sociais reais: curtir, comentar e salvar — com as
        // contagens públicas do projeto (independentes de avaliação).
        _ActionsRow(project: project),
        const SizedBox(height: AppSpacing.xl),
        // Conteúdo: página de leitura para Textos, mídia + descrição
        // para os demais tipos (SPEC §35–45).
        if (project.type == ProjectType.texto)
          _ReadingContent(project: project)
        else ...[
          if (project.media.isNotEmpty) _MediaCarousel(media: project.media),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sobre o projeto',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                Text(project.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        // Repositório
        if (project.media.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Repositório',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                for (final m in project.media)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      switch (m.kind) {
                        ProjectMediaKind.image => Icons.image_outlined,
                        ProjectMediaKind.video =>
                          Icons.play_circle_outline,
                        ProjectMediaKind.pdf =>
                          Icons.picture_as_pdf_outlined,
                        ProjectMediaKind.github => Icons.code,
                        ProjectMediaKind.link => Icons.link,
                        _ => Icons.insert_drive_file_outlined,
                      },
                      color: AppColors.textSecondary,
                    ),
                    title: Text(m.label ?? m.url,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    onTap: m.kind == ProjectMediaKind.link ||
                            m.kind == ProjectMediaKind.github
                        ? () => launchUrl(Uri.parse(m.url))
                        : null,
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        // Avaliações
        _RatingsSection(project: project),
        const SizedBox(height: AppSpacing.lg),
        // Comentários soltos (sem nota)
        _CommentsSection(project: project),
        const SizedBox(height: AppSpacing.xl),
        _RateArea(project: project, onRate: () => _showRateModal(context, ref)),
      ],
    );
  }

  Future<void> _showRateModal(BuildContext context, WidgetRef ref) async {
    int selected = 0;
    final commentController = TextEditingController();

    await AppModal.show(
      context,
      title: 'Avaliar projeto',
      child: StatefulBuilder(
        builder: (context, setModalState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dê uma nota de 1 até 10.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 1; i <= 10; i++)
                  InkWell(
                    onTap: () => setModalState(() => selected = i),
                    borderRadius: AppRadii.controlRadius,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected == i
                            ? AppColors.accent
                            : AppColors.surface3,
                        borderRadius: AppRadii.controlRadius,
                      ),
                      child: Center(
                        child: Text('$i',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: selected == i
                                    ? AppColors.onAccent
                                    : AppColors.textSecondary)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: commentController,
              label: 'Comentário (opcional)',
              hint: 'O que você achou do projeto?',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Enviar avaliação',
              expand: true,
              onPressed: selected == 0
                  ? null
                  : () async {
                      await ref.read(projectRepositoryProvider).rate(
                          project.id,
                          selected,
                          commentController.text.trim().isEmpty
                              ? null
                              : commentController.text.trim());
                      ref.invalidate(projectByIdProvider(project.id));
                      ref.invalidate(_ratingsProvider(project.id));
                      // Média da escola do autor muda com a avaliação.
                      final authorSchool = ref
                          .read(_authorProvider(project.authorId))
                          .value
                          ?.schoolId;
                      if (authorSchool != null) {
                        ref.invalidate(schoolStatsProvider(authorSchool));
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        AppToast.show(context,
                            'Avaliação enviada. Você ajudou um criador a evoluir!');
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Página de leitura de um projeto do tipo Texto (SPEC §43):
/// coluna confortável, line-height generoso, texto longo permitido,
/// acento visual na cor editorial escolhida pelo autor.
class _ReadingContent extends StatelessWidget {
  const _ReadingContent({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final tone = project.cardTone ?? TextCardTone.vinho;
    final color = TextCardPalette.of(tone);
    final text = project.textContent ?? project.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadii.pillRadius,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SelectableText(
          text,
          style: const TextStyle(
            fontSize: 16.5,
            height: 1.75,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Área de ação de avaliação (SPEC §53–62): quem participa do projeto
/// (autor ou colaborador) não pode avaliá-lo — a regra também é
/// validada na camada de dados, nunca apenas escondendo o botão.
class _RateArea extends ConsumerWidget {
  const _RateArea({required this.project, required this.onRate});

  final Project project;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;

    if (me != null && project.involves(me.id)) {
      return Center(
        child: AppCard(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Você participa deste projeto e não pode avaliá-lo.',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: AppButton(
        label: 'Avaliar projeto',
        icon: Icons.star_outline,
        onPressed: onRate,
      ),
    );
  }
}

class _MediaCarousel extends StatefulWidget {
  const _MediaCarousel({required this.media});

  final List<ProjectMedia> media;

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: AppRadii.cardRadius,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.media.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final m = widget.media[i];
                if (m.kind != ProjectMediaKind.image) {
                  return Container(
                    color: AppColors.surface2,
                    child: const Center(
                      child: Icon(Icons.insert_drive_file_outlined,
                          size: 48, color: AppColors.textSecondary),
                    ),
                  );
                }
                return CachedNetworkImage(
                  imageUrl: m.url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: AppColors.surface2),
                  errorWidget: (_, _, _) =>
                      Container(color: AppColors.surface2),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('${_index + 1} / ${widget.media.length}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

/// Avatar de quem avaliou, com a moldura do rank dessa pessoa.
class _RaterAvatar extends ConsumerWidget {
  const _RaterAvatar({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(_authorRankProvider(user.id)).value ??
        RankTier.bronze;
    return RankAvatar(
        tier: rank, url: user.avatarUrl, name: user.name, size: 28);
  }
}

class _RatingsSection extends ConsumerWidget {
  const _RatingsSection({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratings = ref.watch(_ratingsProvider(project.id)).value ?? [];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Avaliações',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          RatingStars(avg: project.ratingAvg, count: project.ratingCount),
          if (ratings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.border, height: 1),
            for (final r in ratings)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (r.author != null)
                          _RaterAvatar(user: r.author!),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(r.author?.name ?? 'Estudante',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.surface3,
                            borderRadius: AppRadii.pillRadius,
                          ),
                          child: Text('${r.score}/10',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    if (r.comment != null && r.comment!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(r.comment!,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Linha de ações sociais do projeto (❤ curtir · 💬 comentários ·
/// 🔖 salvar) com as contagens públicas — curtir e comentar são
/// independentes de avaliação. Para quem participa do projeto, mostra
/// também o atalho de edição (título, subtítulo e arquivos).
class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final participant = me != null && project.involves(me.id);

    Future<void> toggleLike() async {
      await ref.read(projectRepositoryProvider).toggleLike(project.id);
      ref.invalidate(projectByIdProvider(project.id));
      ref.invalidate(discoverProjectsProvider);
    }

    Future<void> toggleSave() async {
      if (me == null) return;
      final saved = await ref
          .read(savedProjectsRepositoryProvider)
          .toggle(me.id, project.id);
      ref.invalidate(projectByIdProvider(project.id));
      ref.invalidate(discoverProjectsProvider);
      ref.invalidate(savedProjectsProvider);
      if (context.mounted) {
        AppToast.show(
            context,
            saved
                ? 'Projeto salvo na Biblioteca.'
                : 'Projeto removido da Biblioteca.');
      }
    }

    return Wrap(
      spacing: AppSpacing.xxl,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DetailAction(
          icon: project.likedByMe ? Icons.favorite : Icons.favorite_border,
          label: Fmt.number(project.likeCount),
          active: project.likedByMe,
          tooltip: 'Curtir',
          onTap: toggleLike,
        ),
        _DetailAction(
          icon: Icons.chat_bubble_outline,
          label: Fmt.number(project.commentCount),
          tooltip: 'Comentários',
        ),
        _DetailAction(
          icon: project.savedByMe ? Icons.bookmark : Icons.bookmark_border,
          label: Fmt.number(project.saveCount),
          active: project.savedByMe,
          tooltip: 'Salvar na Biblioteca',
          onTap: toggleSave,
        ),
        if (participant)
          InkWell(
            onTap: () => context.go('/projetos/${project.id}/editar'),
            borderRadius: AppRadii.controlRadius,
            child: const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.accent),
                  SizedBox(width: AppSpacing.xs),
                  Text('Editar projeto',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        // Denúncia: apenas para projetos de outros usuários (rodada 6).
        // Reportar nunca remove o projeto — envia à moderação.
        if (PermissionService.canReportProject(me, project))
          Tooltip(
            message: 'Reportar projeto',
            child: InkWell(
              onTap: () => showProjectReportDialog(context, ref, project),
              borderRadius: AppRadii.controlRadius,
              child: const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Icon(Icons.flag_outlined,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    this.active = false,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textSecondary;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.controlRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comentários soltos do projeto — qualquer estudante pode comentar,
/// sem precisar avaliar. Com nota é avaliação; sem nota é comentário.
class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({required this.project});

  final Project project;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(projectRepositoryProvider)
          .addComment(widget.project.id, text);
      _controller.clear();
      ref.invalidate(_commentsProvider(widget.project.id));
      ref.invalidate(projectByIdProvider(widget.project.id));
      ref.invalidate(discoverProjectsProvider);
      if (mounted) {
        AppToast.show(context, 'Comentário publicado.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Exclusão de comentário (rodada 6): o autor do comentário e o autor
  /// principal do projeto podem excluir (regra centralizada em
  /// PermissionService.canDeleteComment). A lista e o contador
  /// atualizam por invalidação — sem reload completo da página.
  Future<void> _deleteComment(ProjectComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Excluir comentário?'),
        content:
            const Text('Esta ação não poderá ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(projectRepositoryProvider).deleteComment(comment.id);
    ref.invalidate(_commentsProvider(widget.project.id));
    ref.invalidate(projectByIdProvider(widget.project.id));
    ref.invalidate(discoverProjectsProvider);
    if (mounted) {
      AppToast.show(context, 'Comentário excluído.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments =
        ref.watch(_commentsProvider(widget.project.id)).value ?? [];
    final me = ref.watch(currentUserProvider).value;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comentários (${comments.length})',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (me != null) ...[
                AppAvatar(url: me.avatarUrl, name: me.name, size: 32),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: AppTextField(
                  controller: _controller,
                  hint: 'Escreva um comentário...',
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: 'Comentar',
                loading: _sending,
                onPressed: _send,
              ),
            ],
          ),
          if (comments.isEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('Nenhum comentário ainda. Seja o primeiro!',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.border, height: 1),
            for (final c in comments)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(
                        url: c.author?.avatarUrl,
                        name: c.author?.name ?? '?',
                        size: 32),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                    c.author?.name ?? 'Estudante',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(Fmt.relativeTime(c.createdAt),
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(c.text,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                    // Ação discreta de excluir: autor do comentário ou
                    // autor principal do projeto (rodada 6). Não há
                    // replies encadeadas hoje, então excluir não deixa
                    // referências quebradas.
                    if (PermissionService.canDeleteComment(
                        me, c, widget.project))
                      IconButton(
                        onPressed: () => _deleteComment(c),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        color: AppColors.textSecondary,
                        tooltip: 'Excluir comentário',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
