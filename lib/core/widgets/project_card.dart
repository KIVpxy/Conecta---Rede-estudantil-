import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../data/models/models.dart';
import '../utils/formatters.dart';
import 'buttons.dart';
import 'cards.dart';
import 'inputs.dart';
import 'rank.dart';
import 'rank_frame.dart';
import 'user.dart';
import 'xp.dart';

/// Card de projeto do feed (SPEC §10).
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.author,
    required this.authorRank,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onCollaboratorsTap,
    this.onReport,
  });

  final Project project;
  final UserProfile author;
  final RankTier authorRank;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onCollaboratorsTap;

  /// Quando não nulo, o menu ⋮ do card oferece "Reportar projeto"
  /// (só faz sentido para projetos de outros usuários).
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                RankAvatar(
                    tier: authorRank,
                    url: author.avatarUrl,
                    name: author.name,
                    size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(author.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          RankBadge(tier: authorRank, mode: RankBadgeMode.compact),
                        ],
                      ),
                      Text(
                        '@${author.username} • ${Fmt.relativeTime(project.createdAt)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (onReport != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz,
                        color: AppColors.textSecondary),
                    tooltip: 'Mais opções',
                    color: AppColors.surface2,
                    onSelected: (value) {
                      if (value == 'report') onReport!();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined,
                                size: 18, color: AppColors.textSecondary),
                            SizedBox(width: AppSpacing.sm),
                            Text('Reportar projeto'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Título + subtítulo + tags
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  project.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                if (project.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final tag in project.tags.take(4))
                        AppTag(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Conteúdo visual: card editorial para Textos, mídia para os demais.
          if (project.type == ProjectType.texto)
            _TextoPreview(project: project)
          else if (project.media.isNotEmpty)
            _MediaPreview(project: project),
          // Interações
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RatingStars(
                    avg: project.ratingAvg, count: project.ratingCount),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _ActionButton(
                      icon: project.likedByMe
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: Fmt.number(project.likeCount),
                      active: project.likedByMe,
                      onTap: onLike,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    _ActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: Fmt.number(project.commentCount),
                      onTap: onTap,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    _ActionButton(
                      icon: project.savedByMe
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      label: Fmt.number(project.saveCount),
                      active: project.savedByMe,
                      onTap: onSave,
                    ),
                  ],
                ),
                if (project.collaborators.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      CollaboratorAvatarGroup(
                        users: project.collaborators,
                        onTap: onCollaboratorsTap,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          '${project.collaborators.first.name.split(' ').first} + ${project.collaborators.length - 1}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Ver projeto',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.arrow_forward,
                  onPressed: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Prévia editorial de um projeto do tipo Texto (SPEC §42):
/// bloco colorido da paleta centralizada, com trecho do texto e o
/// convite "Continuar lendo →".
class _TextoPreview extends StatelessWidget {
  const _TextoPreview({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final tone = project.cardTone ?? TextCardTone.vinho;
    final color = TextCardPalette.of(tone);

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.9),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            project.textContent?.trim().isNotEmpty == true
                ? project.textContent!.trim()
                : project.subtitle,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              Text(
                'Continuar lendo →',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final media = project.media;
    final first = media.first;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (first.kind == ProjectMediaKind.image)
            CachedNetworkImage(
              imageUrl: first.url,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.surface2),
              errorWidget: (_, _, _) => _mediaPlaceholder(first.kind),
            )
          else
            _mediaPlaceholder(first.kind),
          if (media.length > 1)
            Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: AppRadii.pillRadius,
                ),
                child: Text(
                  '1 / ${media.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mediaPlaceholder(ProjectMediaKind kind) {
    final icon = switch (kind) {
      ProjectMediaKind.video => Icons.play_circle_outline,
      ProjectMediaKind.pdf => Icons.picture_as_pdf_outlined,
      ProjectMediaKind.github => Icons.code,
      ProjectMediaKind.link => Icons.link,
      _ => Icons.image_outlined,
    };
    return Container(
      color: AppColors.surface2,
      child: Center(
        child: Icon(icon, size: 48, color: AppColors.textSecondary),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? AppColors.accentSoft : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.controlRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
