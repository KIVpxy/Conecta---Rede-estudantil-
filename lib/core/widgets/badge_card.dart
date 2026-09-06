import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../data/models/models.dart';
import '../utils/formatters.dart';
import 'cards.dart';

/// Ícone de cada badge (identidade visual centralizada).
IconData badgeIcon(BadgeId id) => switch (id) {
      BadgeId.autor => Icons.edit_note,
      BadgeId.menteBrilhante1 ||
      BadgeId.menteBrilhante2 ||
      BadgeId.menteBrilhante3 =>
        Icons.lightbulb_outline,
      BadgeId.thinker1 || BadgeId.thinker2 || BadgeId.thinker3 =>
        Icons.psychology_outlined,
      BadgeId.alunoAplicado1 || BadgeId.alunoAplicado2 =>
        Icons.school_outlined,
      BadgeId.mastermind => Icons.workspace_premium_outlined,
      BadgeId.euTenhoEVoce => Icons.emoji_events_outlined,
    };

/// Card de badge com progresso e estados bloqueado/desbloqueado
/// (SPEC §20–27). Toque abre o modal de detalhe (ver [showBadgeDetail]).
class BadgeCard extends StatelessWidget {
  const BadgeCard({super.key, required this.badge, this.onTap});

  final UserBadge badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final def = badge.definition;
    final unlocked = badge.unlocked;
    final progress =
        badge.progress.clamp(0, def.target) / def.target;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Opacity(
        opacity: unlocked ? 1 : 0.45,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked
                        ? AppColors.accent.withValues(alpha: 0.16)
                        : AppColors.surface3,
                  ),
                  child: Icon(
                    unlocked ? badgeIcon(def.id) : Icons.lock_outline,
                    size: 20,
                    color: unlocked
                        ? AppColors.accentSoft
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              def.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (unlocked)
              const Text('Desbloqueado',
                  style: TextStyle(
                      color: AppColors.success, fontSize: 10.5))
            else ...[
              Text('${badge.progress.clamp(0, def.target)}/${def.target}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 10.5)),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppRadii.pillRadius,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppColors.surface3,
                  valueColor: const AlwaysStoppedAnimation(
                      AppColors.accentMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal de detalhe do badge (§7): imagem, nome, descrição, condição
/// de desbloqueio e data — fora da linha horizontal do perfil.
void showBadgeDetail(BuildContext context, UserBadge badge) {
  final def = badge.definition;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface1,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.16),
            ),
            child: Icon(badgeIcon(def.id), color: AppColors.accentSoft),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(def.name)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONDIÇÃO DE DESBLOQUEIO',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(def.description,
              style: const TextStyle(
                  color: AppColors.textPrimary, height: 1.45)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Progresso: ${badge.progress.clamp(0, def.target)}/${def.target}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            badge.unlocked
                ? 'Desbloqueado em ${Fmt.date(badge.unlockedAt!)}'
                : 'Bloqueado — continue evoluindo para desbloquear.',
            style: TextStyle(
              fontSize: 12,
              color: badge.unlocked
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
