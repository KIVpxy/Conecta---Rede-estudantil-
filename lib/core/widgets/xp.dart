import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../utils/formatters.dart';

/// Barra de progressão de XP: "NÍVEL 18 — 50/200 XP — 150 XP para o Nível 19".
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.level,
    required this.current,
    required this.max,
    this.compact = false,
  });

  final int level;
  final int current;
  final int max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NÍVEL $level',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            Text(
              '${Fmt.number(current)} / ${Fmt.number(max)} XP',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadii.pillRadius,
          child: SizedBox(
            height: compact ? 8 : 12,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: AppColors.surface3),
                FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.accentGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${Fmt.number(max - current)} XP para o Nível ${level + 1}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Avaliação média 0–10 com estrelas discretas.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.avg,
    this.count,
    this.size = 16,
  });

  final double avg; // 0..10
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final stars = avg / 2; // 10 pontos -> 5 estrelas

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            stars >= i + 1
                ? Icons.star_rounded
                : (stars > i ? Icons.star_half_rounded : Icons.star_border_rounded),
            size: size,
            color: stars > i ? AppColors.rankOuro : AppColors.border,
          ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          Fmt.rating(avg),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const Text(' / 10',
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${Fmt.number(count!)} avaliações',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
