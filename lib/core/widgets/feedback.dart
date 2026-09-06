import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../data/models/models.dart';
import '../utils/formatters.dart';
import 'rank.dart';
import 'user.dart';

/// Modal padrão do app.
class AppModal extends StatelessWidget {
  const AppModal({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => AppModal(title: title, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toast padrão do app.
class AppToast {
  AppToast._();

  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Linha da tabela de ranking (SPEC §8).
///
/// Adaptativo (rodada 4, §1–§10): abaixo de 560px de largura útil vira um
/// cartão simplificado com APENAS posição, nome (com cor de Elo alto),
/// rank uma única vez, nível e XP total acumulado — sem username, média,
/// quantidade de projetos ou colunas extras. Desktop mantém a tabela cheia.
class RankingRow extends StatelessWidget {
  const RankingRow({super.key, required this.entry, this.onTap});

  final LeaderboardEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 560
          ? _MobileRankingRow(entry: entry, onTap: onTap)
          : _buildDesktop(context),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final highlight = entry.isCurrentUser;

    return Material(
      color: highlight ? AppColors.surface2 : Colors.transparent,
      borderRadius: AppRadii.controlRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.controlRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadii.controlRadius,
            border: highlight
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.5))
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text('#${entry.position}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              Expanded(
                flex: 3,
                child: UserRow(user: entry.user, rank: entry.rank),
              ),
              Expanded(
                child: Text('Nível ${entry.position > 0 ? _level : 0}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
              Expanded(
                child: Text('${entry.projectCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
              Expanded(
                child: Text(Fmt.rating(entry.ratingAvg),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
              Expanded(
                child: Text('${Fmt.number(entry.xpTotal)} XP',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: AppSpacing.md),
              RankBadge(tier: entry.rank, mode: RankBadgeMode.compact),
            ],
          ),
        ),
      ),
    );
  }

  int get _level => entry.xpTotal ~/ 200 + 1;
}

/// Linha do ranking para telas estreitas (rodada 4, §1–§10).
///
/// Hierarquia (§2): 1. nome · 2. rank · 3. nível · 4. XP total acumulado.
/// O rank aparece UMA única vez (§4); o XP é sempre o total acumulado (§6).
/// Sem username, média, projetos ou outras estatísticas (§1).
class _MobileRankingRow extends StatelessWidget {
  const _MobileRankingRow({required this.entry, this.onTap});

  final LeaderboardEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = entry.isCurrentUser;
    final level = entry.xpTotal ~/ 200 + 1;

    return Material(
      color: highlight ? AppColors.surface2 : Colors.transparent,
      borderRadius: AppRadii.controlRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.controlRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadii.controlRadius,
            border: highlight
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.5))
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text('#${entry.position}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                  ),
                  // O nome recebe todo o espaço restante (§3): máximo
                  // possível, com ellipsis elegante só se necessário.
                  Expanded(
                    child: UserDisplayName(
                      name: entry.user.name,
                      rank: entry.rank,
                      isDeveloper: entry.user.isDeveloper,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${Fmt.number(entry.xpTotal)} XP',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Row(
                  children: [
                    RankBadge(tier: entry.rank, mode: RankBadgeMode.compact),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Nível $level',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
