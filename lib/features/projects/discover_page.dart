import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/services/permission_service.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import 'report_project_dialog.dart';

// ---------- Estado do feed ----------

class DiscoverFilter {
  const DiscoverFilter({
    this.tab = DiscoverTab.paraVoce,
    this.category,
    this.query = '',
    this.page = 0,
  });

  final DiscoverTab tab;
  final ProjectCategory? category;
  final String query;
  final int page;

  DiscoverFilter copyWith({
    DiscoverTab? tab,
    ProjectCategory? Function()? category,
    String? query,
    int? page,
  }) =>
      DiscoverFilter(
        tab: tab ?? this.tab,
        category: category != null ? category() : this.category,
        query: query ?? this.query,
        page: page ?? this.page,
      );
}

final discoverFilterProvider =
    StateProvider<DiscoverFilter>((ref) => const DiscoverFilter());

final discoverProjectsProvider =
    FutureProvider<List<Project>>((ref) {
  final f = ref.watch(discoverFilterProvider);
  return ref.watch(projectRepositoryProvider).list(
        tab: f.tab,
        category: f.category,
        query: f.query,
        page: f.page,
      );
});

/// Feed "Descobrir Projetos" (SPEC §9) — anti-scroll infinito (SPEC §3):
/// sessões finitas de 12 projetos + card de conclusão de sessão.
class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  static const _tabs = [
    (DiscoverTab.paraVoce, 'Para você'),
    (DiscoverTab.podio, 'Pódio'),
    (DiscoverTab.estudantis, 'Estudantis'),
    (DiscoverTab.autorais, 'Autorais'),
    (DiscoverTab.docentes, 'Docentes'),
    (DiscoverTab.recentes, 'Recentes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(discoverFilterProvider);
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Descobrir Projetos',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              const Text('Veja o que outros estudantes estão criando.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              AppSearchField(
                hint: 'Buscar projetos, criadores ou temas...',
                onChanged: (q) => ref
                    .read(discoverFilterProvider.notifier)
                    .state = filter.copyWith(query: q, page: 0),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTabs(
                tabs: [for (final t in _tabs) t.$2],
                index: _tabs.indexWhere((t) => t.$1 == filter.tab),
                onChanged: (i) => ref
                    .read(discoverFilterProvider.notifier)
                    .state = filter.copyWith(tab: _tabs[i].$1, page: 0),
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppFilterChip(
                      label: 'Todas',
                      selected: filter.category == null,
                      onTap: () => ref
                          .read(discoverFilterProvider.notifier)
                          .state = filter.copyWith(
                              category: () => null, page: 0),
                    ),
                    for (final c in ProjectCategory.values) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AppFilterChip(
                        label: c.label,
                        selected: filter.category == c,
                        onTap: () => ref
                            .read(discoverFilterProvider.notifier)
                            .state = filter.copyWith(
                                category: () => c, page: 0),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                filter.page == 0
                    ? '12 projetos para descobrir hoje'
                    : 'Sessão ${filter.page + 1} de descoberta',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              const _ProjectGrid(),
              const SizedBox(height: AppSpacing.xl),
              const _EndOfSession(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectGrid extends ConsumerWidget {
  const _ProjectGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(discoverProjectsProvider);

    return projectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Algo deu errado',
        subtitle: '$e',
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            title: 'Nenhum projeto encontrado',
            subtitle: 'Tente outros filtros ou termos de busca.',
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 900
                ? 2
                : constraints.maxWidth > 560
                    ? 2
                    : 1;
            if (columns == 1) {
              return Column(
                children: [
                  for (final p in projects)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: ProjectCardLoader(project: p),
                    ),
                ],
              );
            }
            // Wrap com largura fixa e ALTURA NATURAL do card — um GridView
            // com aspectRatio fixo estourava (bottom overflow) quando um
            // título longo ou tags extras deixavam um card mais alto.
            final cardWidth =
                (constraints.maxWidth - AppSpacing.lg) / columns;
            return Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [
                for (final p in projects)
                  SizedBox(
                    width: cardWidth,
                    child: ProjectCardLoader(project: p),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Carrega autor e rank do autor antes de montar o card.
/// Reutilizado pelo Discover e pela Biblioteca (§29).
class ProjectCardLoader extends ConsumerWidget {
  const ProjectCardLoader({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectRepositoryProvider);
    final profiles = ref.watch(profileRepositoryProvider);
    final me = ref.watch(currentUserProvider).value;

    return FutureBuilder<List<Object?>>(
      future: Future.wait([
        projects.authorOf(project.authorId),
        profiles.rankOf(project.authorId),
      ]),
      builder: (context, snapshot) {
        final author = snapshot.data?[0] as UserProfile?;
        final rank = snapshot.data?[1] as RankTier? ?? RankTier.bronze;
        if (author == null) {
          return const AppCard(child: SizedBox(height: 120));
        }
        return ProjectCard(
          project: project,
          author: author,
          authorRank: rank,
          onTap: () => context.go('/projetos/${project.id}'),
          // Menu ⋮ com "Reportar projeto" — apenas em projetos de
          // outros usuários (permissão centralizada, rodada 6).
          onReport: PermissionService.canReportProject(me, project)
              ? () => showProjectReportDialog(context, ref, project)
              : null,
          onLike: () async {
            await projects.toggleLike(project.id);
            ref.invalidate(discoverProjectsProvider);
            ref.invalidate(savedProjectsProvider);
          },
          // Salvar/remover da Biblioteca (§26–§27, §36): toggle sem
          // duplicar, com feedback discreto nos dois sentidos.
          onSave: () async {
            final user = await ref.read(currentUserProvider.future);
            if (user == null) return;
            final saved = await ref
                .read(savedProjectsRepositoryProvider)
                .toggle(user.id, project.id);
            ref.invalidate(discoverProjectsProvider);
            ref.invalidate(savedProjectsProvider);
            if (context.mounted) {
              AppToast.show(
                context,
                saved
                    ? 'Projeto salvo na Biblioteca.'
                    : 'Projeto removido da Biblioteca.',
              );
            }
          },
        );
      },
    );
  }
}

/// Card de fim de sessão (anti-scroll, SPEC §3).
class _EndOfSession extends ConsumerWidget {
  const _EndOfSession();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(discoverFilterProvider);

    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 32, color: AppColors.success),
          const SizedBox(height: AppSpacing.md),
          const Text('Você concluiu sua sessão de descoberta.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          const Text('Que tal produzir algo agora?',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: [
              AppButton(
                label: 'Criar um projeto',
                icon: Icons.add,
                onPressed: () => context.go('/projetos/novo'),
              ),
              AppButton(
                label: 'Continuar meu projeto',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/status'),
              ),
              AppButton(
                label: 'Explorar ranking',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/ranking'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Ver mais projetos',
            variant: AppButtonVariant.ghost,
            icon: Icons.expand_more,
            onPressed: () => ref
                .read(discoverFilterProvider.notifier)
                .state = filter.copyWith(page: filter.page + 1),
          ),
        ],
      ),
    );
  }
}
