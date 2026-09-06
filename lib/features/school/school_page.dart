import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/services/permission_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/level_math.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

final _schoolLeaderboardProvider =
    FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(rankingRepositoryProvider).leaderboard(scope: 'escola');
});

final _mySchoolProvider = FutureProvider<School?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  final schoolId = user?.schoolId;
  if (schoolId == null) return null;
  return ref.watch(schoolRepositoryProvider).getById(schoolId);
});

/// Estatísticas REAIS da escola (rodada 6): derivadas de profiles +
/// projects + ratings pela camada de dados — nunca números fixos.
/// Provider público em providers.dart (schoolStatsProvider) para que
/// criar/excluir projeto e novas avaliações atualizem esta tela.

final _announcementsProvider =
    FutureProvider.family<List<SchoolAnnouncement>, String>((ref, schoolId) {
  return ref.watch(schoolRepositoryProvider).announcementsOf(schoolId);
});

/// Aba Escola (§37–§40): visão geral, ranking interno (por schoolId) e
/// comunicados oficiais publicados por Developers.
class SchoolPage extends ConsumerWidget {
  const SchoolPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final schoolAsync = ref.watch(_mySchoolProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = AppBreakpoints.isMobile(width);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xxxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Escola',
                  style:
                      TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xs),
              const Text('Sua comunidade escolar dentro do Conecta.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),

              // §10: sem escola selecionada, a comunidade escolar pede
              // a seleção no perfil — nunca compara por nome textual.
              if (user?.schoolId == null)
                const _NoSchoolCard()
              else ...[
                schoolAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator()),
                  error: (e, _) => Text('Erro: $e'),
                  data: (school) => _SchoolHero(
                    school: school,
                    isMobile: isMobile,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _SchoolRanking(isMobile: isMobile),
                const SizedBox(height: AppSpacing.xxl),
                if (user?.schoolId != null)
                  _SchoolAnnouncements(schoolId: user!.schoolId!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vazio do filtro "Minha escola" (§11) — texto exato da spec.
class _NoSchoolCard extends StatelessWidget {
  const _NoSchoolCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        children: [
          const Icon(Icons.school_outlined,
              size: 40, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Selecione sua escola no perfil para visualizar a comunidade escolar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Selecionar escola',
            icon: Icons.school_outlined,
            onPressed: () => context.go('/editar-perfil'),
          ),
        ],
      ),
    );
  }
}

class _SchoolHero extends ConsumerWidget {
  const _SchoolHero({required this.school, required this.isMobile});

  final School? school;
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null enquanto carrega — os números aparecem como "—".
    final stats = school == null
        ? null
        : ref.watch(schoolStatsProvider(school!.id)).value;

    // Valores reais derivados dos dados (rodada 6, §28–§36).
    // Sem avaliações ainda: mostra 0,0 — nunca NaN/erro.
    final items = [
      (
        Icons.groups_outlined,
        stats == null ? '—' : Fmt.number(stats.studentCount),
        'ALUNOS NO CONECTA'
      ),
      (
        Icons.rocket_launch_outlined,
        stats == null ? '—' : Fmt.number(stats.projectCount),
        'PROJETOS PUBLICADOS'
      ),
      (
        Icons.star_outline,
        stats == null ? '—' : Fmt.rating(stats.ratingAvg),
        'AVALIAÇÃO MÉDIA'
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.28),
            AppColors.accent.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: AppRadii.controlRadius,
                ),
                child: const Icon(Icons.school_outlined,
                    color: AppColors.onAccent, size: 26),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(school?.name ?? 'Sua escola',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    if (school != null)
                      Text(school!.location,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          isMobile
              ? Column(
                  children: [
                    for (final s in items)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _HeroStat(
                            icon: s.$1, value: s.$2, label: s.$3),
                      ),
                  ],
                )
              : Row(
                  children: [
                    for (final s in items)
                      Expanded(
                        child: _HeroStat(
                            icon: s.$1, value: s.$2, label: s.$3),
                      ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(
      {required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.accentSoft),
        const SizedBox(width: AppSpacing.md),
        // Flexible + quebra organizada: labels longos não estouram a
        // largura disponível (rodada 6, correção de overflow).
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      height: 1.35,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchoolRanking extends ConsumerWidget {
  const _SchoolRanking({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_schoolLeaderboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Ranking da escola',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => context.go('/ranking'),
              child: const Text('Ver ranking global'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        entries.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro ao carregar: $e'),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'Ainda não há ranking na sua escola',
                subtitle:
                    'Publique projetos e receba avaliações para aparecer aqui.',
              );
            }
            final top = list.take(5).toList();
            return AppCard(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in top)
                    isMobile
                        ? _CompactSchoolRow(
                            entry: e,
                            onTap: () =>
                                context.go('/perfil/${e.user.username}'),
                          )
                        : RankingRow(
                            entry: e,
                            onTap: () =>
                                context.go('/perfil/${e.user.username}'),
                          ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Linha compacta do ranking da escola para telas pequenas (§: mobile
/// mostra apenas Nome, Rank, Nível e XP — sem username nem contadores).
class _CompactSchoolRow extends StatelessWidget {
  const _CompactSchoolRow({required this.entry, this.onTap});

  final LeaderboardEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: entry.isCurrentUser ? AppColors.surface2 : Colors.transparent,
      borderRadius: AppRadii.controlRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.controlRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('#${entry.position}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              RankAvatar(
                tier: entry.rank,
                name: entry.user.name,
                url: entry.user.avatarUrl,
                size: 36,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserDisplayName(
                      name: entry.user.name,
                      rank: entry.rank,
                      isDeveloper: entry.user.isDeveloper,
                    ),
                    Text(
                      'Nível ${LevelMath.levelFor(entry.xpTotal)} · ${Fmt.number(entry.xpTotal)} XP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              RankBadge(tier: entry.rank, mode: RankBadgeMode.compact),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comunicados oficiais da escola (§37–§40). Apenas Developers veem
/// "Novo comunicado" e podem editar/remover (via PermissionService).
class _SchoolAnnouncements extends ConsumerWidget {
  const _SchoolAnnouncements({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final canManage = PermissionService.canCreateSchoolAnnouncement(me);
    final announcements = ref.watch(_announcementsProvider(schoolId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Comunicados',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            if (canManage)
              AppButton(
                label: 'Novo comunicado',
                icon: Icons.campaign_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => _showEditor(context, ref),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        announcements.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro ao carregar: $e'),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.campaign_outlined,
                title: 'Nenhum comunicado ainda',
                subtitle: 'Os comunicados oficiais da escola aparecem aqui.',
              );
            }
            return Column(
              children: [
                for (final a in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _AnnouncementCard(
                      announcement: a,
                      canManage: canManage,
                      onEdit: () => _showEditor(context, ref, existing: a),
                      onDelete: () => _confirmDelete(context, ref, a),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, SchoolAnnouncement a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Remover comunicado'),
        content: Text('Remover "${a.title}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(schoolRepositoryProvider).deleteAnnouncement(a.id);
      ref.invalidate(_announcementsProvider(schoolId));
      if (context.mounted) {
        AppToast.show(context, 'Comunicado removido.');
      }
    }
  }

  Future<void> _showEditor(BuildContext context, WidgetRef ref,
      {SchoolAnnouncement? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subtitleCtrl =
        TextEditingController(text: existing?.subtitle ?? '');
    final contentCtrl =
        TextEditingController(text: existing?.content ?? '');
    var category = existing?.category ?? AnnouncementCategory.geral;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface1,
          title: Text(existing == null
              ? 'Novo comunicado'
              : 'Editar comunicado'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(controller: titleCtrl, label: 'Título'),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                      controller: subtitleCtrl,
                      label: 'Subtítulo (opcional)'),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: contentCtrl,
                    label: 'Conteúdo',
                    maxLines: 5,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<AnnouncementCategory>(
                    initialValue: category,
                    decoration:
                        const InputDecoration(labelText: 'Categoria'),
                    items: [
                      for (final c in AnnouncementCategory.values)
                        DropdownMenuItem(value: c, child: Text(c.label)),
                    ],
                    onChanged: (v) =>
                        setState(() => category = v ?? category),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(existing == null ? 'Publicar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final repo = ref.read(schoolRepositoryProvider);
      if (existing == null) {
        await repo.createAnnouncement(
          schoolId: schoolId,
          title: titleCtrl.text.trim(),
          subtitle: subtitleCtrl.text.trim(),
          content: contentCtrl.text.trim(),
          category: category,
        );
      } else {
        await repo.updateAnnouncement(
          existing.id,
          title: titleCtrl.text.trim(),
          subtitle: subtitleCtrl.text.trim(),
          content: contentCtrl.text.trim(),
          category: category,
        );
      }
      ref.invalidate(_announcementsProvider(schoolId));
      if (context.mounted) {
        AppToast.show(context,
            existing == null ? 'Comunicado publicado.' : 'Comunicado atualizado.');
      }
    }
  }
}

/// Card diferenciado de comunicado (§39): selo "Comunicado", ícone da
/// categoria, detalhe pastel, autor [DEV] e data. Sem exagero.
class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canManage,
    this.onEdit,
    this.onDelete,
  });

  final SchoolAnnouncement announcement;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  IconData get _icon => switch (announcement.category) {
        AnnouncementCategory.aviso => Icons.campaign_outlined,
        AnnouncementCategory.evento => Icons.event_outlined,
        AnnouncementCategory.oportunidade => Icons.auto_awesome_outlined,
        AnnouncementCategory.prova => Icons.edit_note,
        AnnouncementCategory.olimpiada =>
          Icons.workspace_premium_outlined,
        AnnouncementCategory.geral => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    final color = AppColors.announcementColor(announcement.category);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filete pastel da categoria (detalhe discreto, sem exagero).
          Container(
            width: 4,
            constraints: const BoxConstraints(minHeight: 88),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadii.card),
                bottomLeft: Radius.circular(AppRadii.card),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_icon, size: 16, color: color),
                      const SizedBox(width: AppSpacing.sm),
                      // Selo "Comunicado" + categoria.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: AppRadii.pillRadius,
                        ),
                        child: Text(
                          'COMUNICADO · ${announcement.category.label.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const DevSeal(),
                      const Spacer(),
                      if (canManage) ...[
                        IconButton(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          color: AppColors.textSecondary,
                          tooltip: 'Editar',
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          color: AppColors.textSecondary,
                          tooltip: 'Remover',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(announcement.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  if (announcement.subtitle != null &&
                      announcement.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(announcement.subtitle!,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500)),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(announcement.content,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    announcement.updatedAt != null
                        ? 'Editado ${Fmt.relativeTime(announcement.updatedAt!)}'
                        : Fmt.relativeTime(announcement.createdAt),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
