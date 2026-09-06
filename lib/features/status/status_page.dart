import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/level_math.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';

// ---------- Providers da tela ----------

final _statsProvider = FutureProvider.family<UserStats, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).stats(uid);
});

final _rankProvider = FutureProvider.family<RankTier, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).rankOf(uid);
});

final _positionProvider = FutureProvider.family<int, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).positionInRank(uid);
});

final _xpEventsProvider =
    FutureProvider.family<List<XpEvent>, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).xpEvents(uid);
});

final _lastProjectProvider =
    FutureProvider.family<Project?, String>((ref, uid) {
  return ref.watch(projectRepositoryProvider).lastEditedProject(uid);
});

final _topRankingProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(rankingRepositoryProvider).leaderboard();
});

/// Dashboard do usuário (SPEC §7.1) — ordem visual:
/// 1. Perfil+Nível+XP+Rank · 2. Continuar criando · 3. Estatísticas
/// 4. Atividade de XP · 5. Ranking resumido
class StatusPage extends ConsumerWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Faça login para continuar.'));
        }
        return _Dashboard(user: user);
      },
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = AppBreakpoints.isMobile(width);
    final padding = isMobile ? AppSpacing.lg : AppSpacing.xxxl;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Olá, ${user.name.split(' ').first} 👋',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              const Text('Veja sua evolução como criador.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              _HeroCard(user: user),
              const SizedBox(height: AppSpacing.xl),
              _ContinueCreating(user: user),
              const SizedBox(height: AppSpacing.xl),
              _StatsGrid(userId: user.id),
              const SizedBox(height: AppSpacing.xl),
              _XpTimeline(userId: user.id),
              const SizedBox(height: AppSpacing.xl),
              _RankingPreview(currentUserId: user.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(_rankProvider(user.id)).value ?? RankTier.bronze;
    final position = ref.watch(_positionProvider(user.id)).value ?? 0;
    final level = LevelMath.levelFor(user.xpTotal);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RankAvatar(
                  tier: rank,
                  url: user.avatarUrl,
                  name: user.name,
                  size: 64),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('@${user.username}',
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RankBadge(tier: rank),
                        if (position > 0)
                          Text('Posição #$position no ${rank.label}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Fmt.number(user.xpTotal),
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w700)),
                  const Text('XP TOTAL',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0.8)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Progresso dentro do rank atual — zera a cada promoção (§13–15).
          _RankProgress(user: user, rank: rank),
          const SizedBox(height: AppSpacing.xl),
          XpBar(
            level: level,
            current: LevelMath.xpInCurrentLevel(user.xpTotal),
            max: LevelMath.xpPerLevel,
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Como ganhar XP?',
              variant: AppButtonVariant.ghost,
              icon: Icons.help_outline,
              onPressed: () => AppModal.show(
                context,
                title: 'Como ganhar XP?',
                child: const _XpRules(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progresso dentro do rank atual (SPEC §15):
/// "300 / 1.000 XP" com barra que zera a cada promoção. O XP total,
/// acumulado para sempre, aparece separado no topo do card.
class _RankProgress extends StatelessWidget {
  const _RankProgress({required this.user, required this.rank});

  final UserProfile user;
  final RankTier rank;

  @override
  Widget build(BuildContext context) {
    final xp = user.xpTotal;
    final into = LevelMath.xpIntoRank(xp);
    final required = LevelMath.xpRequiredInRank(xp);
    final progress = LevelMath.rankProgress(xp);
    final next = LevelMath.nextRank(rank);
    final cfg = rankConfigs[rank]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'PROGRESSO NO RANK ${rank.label.toUpperCase()}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${Fmt.number(into)} / ${Fmt.number(required)} XP',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadii.pillRadius,
          child: SizedBox(
            height: 12,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: AppColors.surface3),
                FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        cfg.primary.withValues(alpha: 0.85),
                        cfg.secondary,
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          next == null
              ? 'Rank máximo alcançado · XP Total: ${Fmt.number(xp)}'
              : 'Faltam ${Fmt.number(required - into)} XP para o ${next.label} · XP Total: ${Fmt.number(xp)}',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _XpRules extends StatelessWidget {
  const _XpRules();

  @override
  Widget build(BuildContext context) {
    Widget rule(String range, String xp) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                  child: Text('Avaliação média $range',
                      style: const TextStyle(fontSize: 14))),
              Text(xp,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentSoft)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Projetos publicados geram XP baseado na avaliação média recebida. Quem avalia também ganha XP. XP é acumulativo e nunca desaparece.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        rule('1–5', '+30 XP'),
        const Divider(color: AppColors.border, height: 1),
        rule('6–8', '+50 XP'),
        const Divider(color: AppColors.border, height: 1),
        rule('9–10', '+200 XP'),
        const Divider(color: AppColors.border, height: 1),
        rule('Cada avaliação que você faz', '+${LevelMath.xpPerEvaluation} XP'),
      ],
    );
  }
}

class _ContinueCreating extends ConsumerWidget {
  const _ContinueCreating({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(_lastProjectProvider(user.id)).value;
    final isMobile =
        AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);

    final continueCard = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTINUE SEU PROJETO',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          Text(last?.title ?? 'Nenhum projeto em andamento',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (last != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Última edição: ${Fmt.relativeTime(last.lastActivity)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadii.pillRadius,
              child: LinearProgressIndicator(
                // 100% só quando o autor marcar como concluído na
                // tela de edição — nunca um número inventado.
                value: last.isCompleted ? 1.0 : null,
                minHeight: 8,
                backgroundColor: AppColors.surface3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
                last.isCompleted
                    ? '100% concluído 🎉'
                    : 'Em andamento',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: last.isCompleted
                  ? 'Revisar projeto'
                  : 'Continuar projeto',
              icon: last.isCompleted ? Icons.visibility : Icons.play_arrow,
              onPressed: () => last.isCompleted
                  ? context.go('/projetos/${last.id}')
                  : context.go('/projetos/${last.id}/editar'),
            ),
          ],
        ],
      ),
    );

    final newCard = AppCard(
      onTap: () => context.go('/projetos/novo'),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline,
                size: 32, color: AppColors.accentSoft),
            SizedBox(height: AppSpacing.sm),
            Text('Começar novo projeto',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: AppSpacing.xs),
            Text('Seu próximo projeto começa aqui.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          continueCard,
          const SizedBox(height: AppSpacing.md),
          newCard,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: continueCard),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: newCard),
      ],
    );
  }
}

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_statsProvider(userId)).value;
    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final cards = [
      (Icons.rocket_launch_outlined, 'Projetos publicados',
          Fmt.number(stats.projectsPublished)),
      (Icons.star_outline, 'Avaliações recebidas',
          Fmt.number(stats.ratingsReceived)),
      (Icons.favorite_border, 'Curtidas', Fmt.number(stats.likesReceived)),
      (Icons.leaderboard_outlined, 'Avaliação média',
          '${Fmt.rating(stats.ratingAvg)} / 10'),
      (Icons.check_circle_outline, 'Respostas corretas em Materiais',
          Fmt.number(stats.correctAnswers)),
      (Icons.bolt_outlined, 'XP total', Fmt.number(stats.xpTotal)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 980
            ? 6
            : constraints.maxWidth > 560
                ? 3
                : 2;
        // Células mais altas que largas: labels longos (ex.: "Respostas
        // corretas em Materiais") quebram em até 3 linhas sem estourar
        // a altura fixa do GridView (rodada 6, correção de overflow).
        final aspectRatio = constraints.maxWidth > 980
            ? 1.0
            : constraints.maxWidth > 560
                ? 1.05
                : 0.92;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: aspectRatio,
          children: [
            for (final (icon, label, value) in cards)
              StatCard(icon: icon, label: label, value: value),
          ],
        );
      },
    );
  }
}

class _XpTimeline extends ConsumerWidget {
  const _XpTimeline({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(_xpEventsProvider(userId)).value ?? [];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ATIVIDADE DE XP',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
          if (events.isEmpty)
            const Text('Publique um projeto para ganhar XP.',
                style: TextStyle(color: AppColors.textSecondary))
          else
            for (final e in events)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Text(
                        '${e.amount > 0 ? '+' : ''}${e.amount} XP',
                        style: const TextStyle(
                            color: AppColors.accentSoft,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.reason,
                              style: const TextStyle(fontSize: 13)),
                          Text(Fmt.relativeTime(e.createdAt),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RankingPreview extends ConsumerWidget {
  const _RankingPreview({required this.currentUserId});

  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_topRankingProvider).value ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    final top = entries.take(5).toList();
    final mine =
        entries.where((e) => e.user.id == currentUserId).firstOrNull;
    final showMine = mine != null && !top.any((e) => e.isCurrentUser);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('RANKING',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary)),
              ),
              AppButton(
                label: 'Ver ranking completo',
                variant: AppButtonVariant.ghost,
                icon: Icons.arrow_forward,
                onPressed: () => context.go('/ranking'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final e in top)
            RankingRow(
              entry: e,
              onTap: () => context.go('/perfil/${e.user.username}'),
            ),
          if (showMine) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Center(
                  child: Text('⋮',
                      style:
                          TextStyle(color: AppColors.textSecondary))),
            ),
            RankingRow(
              entry: mine,
              onTap: () => context.go('/perfil/${mine.user.username}'),
            ),
          ],
        ],
      ),
    );
  }
}
