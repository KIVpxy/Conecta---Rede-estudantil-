import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

final _scopeProvider = StateProvider<String>((ref) => 'global');
final _rankFilterProvider = StateProvider<RankTier?>((ref) => null);

final _leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(rankingRepositoryProvider).leaderboard(
        scope: ref.watch(_scopeProvider),
        rankFilter: ref.watch(_rankFilterProvider),
      );
});

/// Ranking (SPEC §8) — competição secundária à evolução pessoal.
class RankingPage extends ConsumerWidget {
  const RankingPage({super.key});

  static const _scopes = [
    ('global', 'Global'),
    ('escola', 'Minha Escola'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(_scopeProvider);
    final rankFilter = ref.watch(_rankFilterProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final padding = isMobile ? AppSpacing.lg : AppSpacing.xxxl;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ranking',
                  style:
                      TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              const Text('A competição é secundária à evolução pessoal.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              AppTabs(
                tabs: [for (final s in _scopes) s.$2],
                index: _scopes.indexWhere((s) => s.$1 == scope),
                onChanged: (i) => ref
                    .read(_scopeProvider.notifier)
                    .state = _scopes[i].$1,
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppFilterChip(
                      label: 'Todos os ranks',
                      selected: rankFilter == null,
                      onTap: () => ref
                          .read(_rankFilterProvider.notifier)
                          .state = null,
                    ),
                    for (final t in RankTier.values.reversed) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AppFilterChip(
                        label: t.label,
                        selected: rankFilter == t,
                        onTap: () => ref
                            .read(_rankFilterProvider.notifier)
                            .state = t,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ref.watch(_leaderboardProvider).when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxxl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) =>
                        Center(child: Text('Erro: $e')),
                    data: (entries) => entries.isEmpty
                        ? const EmptyState(
                            icon: Icons.emoji_events_outlined,
                            title: 'Nenhum criador neste filtro',
                          )
                        : Column(
                            children: [
                              if (entries.length >= 3)
                                _Podium(entries: entries.take(3).toList()),
                              const SizedBox(height: AppSpacing.xl),
                              // Cabeçalho de colunas só faz sentido no
                              // layout de tabela (desktop/tablet) — §8/§9.
                              if (!isMobile) _TableHeader(),
                              for (final e in entries)
                                RankingRow(
                                  entry: e,
                                  onTap: () => context
                                      .go('/perfil/${e.user.username}'),
                                ),
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

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Ordem visual: 2º, 1º, 3º
    final order = [entries[1], entries[0], entries[2]];
    final heights = [80.0, 110.0, 64.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Column(
              children: [
                RankEmblem(tier: order[i].rank, size: 64),
                const SizedBox(height: AppSpacing.sm),
                RankAvatar(
                    tier: order[i].rank,
                    url: order[i].user.avatarUrl,
                    name: order[i].user.name,
                    size: 48),
                const SizedBox(height: AppSpacing.sm),
                Text(order[i].user.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${Fmt.number(order[i].xpTotal)} XP',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: i == 1
                        ? AppColors.accent.withValues(alpha: 0.25)
                        : AppColors.surface2,
                    border: Border.all(
                      color: i == 1 ? AppColors.accent : AppColors.border,
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadii.control)),
                  ),
                  child: Center(
                    child: Text(
                      '${order[i].position}º',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: i == 1
                            ? AppColors.accentSoft
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        letterSpacing: 0.6);
    return const Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Text('POS.', style: style)),
          Expanded(flex: 3, child: Text('CRIADOR', style: style)),
          Expanded(child: Text('NÍVEL', style: style)),
          Expanded(
              child: Text('PROJETOS',
                  textAlign: TextAlign.center, style: style)),
          Expanded(
              child: Text('AVALIAÇÃO',
                  textAlign: TextAlign.center, style: style)),
          Expanded(
              child: Text('XP',
                  textAlign: TextAlign.end, style: style)),
          SizedBox(width: AppSpacing.md + 96),
        ],
      ),
    );
  }
}
