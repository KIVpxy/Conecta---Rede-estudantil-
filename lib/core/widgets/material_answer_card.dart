import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../data/models/models.dart';
import '../utils/formatters.dart';
import 'buttons.dart';
import 'cards.dart';
import 'rank_frame.dart';

/// Card de resposta de uma postagem de Materiais (SPEC §5–9).
///
/// A resposta aceita pela moderação exibe ✅, o texto oficial
/// "A moderação considera essa a melhor resposta ou correta." e o
/// selo "Resposta correta". A seleção é exclusiva da moderação —
/// a UI apenas reflete o estado vindo da camada de dados.
class MaterialAnswerCard extends StatelessWidget {
  const MaterialAnswerCard({
    super.key,
    required this.answer,
    this.authorRank = RankTier.bronze,
    this.canModerate = false,
    this.onSelectBest,
    this.onTapAuthor,
  });

  final MaterialAnswer answer;
  final RankTier authorRank;

  /// Verdadeiro apenas para moderador/admin (validado no backend também).
  final bool canModerate;
  final VoidCallback? onSelectBest;
  final VoidCallback? onTapAuthor;

  @override
  Widget build(BuildContext context) {
    final author = answer.author;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (answer.isAccepted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: AppRadii.controlRadius,
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Text('✅', style: TextStyle(fontSize: 14)),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'A moderação considera essa a melhor resposta ou correta.',
                      style: TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.18),
                  borderRadius: AppRadii.pillRadius,
                ),
                child: const Text(
                  'Resposta correta',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              RankAvatar(
                tier: authorRank,
                url: author?.avatarUrl,
                name: author?.name ?? 'Estudante',
                size: 32,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: InkWell(
                  onTap: onTapAuthor,
                  borderRadius: AppRadii.controlRadius,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author?.name ?? 'Estudante',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        '@${author?.username ?? '...'} • ${Fmt.relativeTime(answer.createdAt)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              if (canModerate && !answer.isAccepted && onSelectBest != null)
                AppButton(
                  label: 'Selecionar melhor resposta',
                  variant: AppButtonVariant.ghost,
                  icon: Icons.check_circle_outline,
                  onPressed: onSelectBest,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(answer.content,
              style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
