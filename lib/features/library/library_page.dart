import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../projects/discover_page.dart';

/// Filtro por tipo (rodada 4, §34) — adaptado aos ProjectTypes reais
/// do projeto, sem inventar tipos que não existem.
final _libraryTypeFilterProvider =
    StateProvider<ProjectType?>((ref) => null);

/// Biblioteca (rodada 4, §25–§37): os projetos que o usuário salvou.
/// Reutiliza o ProjectCard existente (§29) e abre a página normal do
/// projeto ao clicar — nunca uma cópia do conteúdo (§31–§32).
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = ref.watch(_libraryTypeFilterProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xxxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Biblioteca',
                  style:
                      TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              const Text('Seus projetos salvos para ver depois.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              // Filtros por tipo (§34).
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppFilterChip(
                      label: 'Todos',
                      selected: typeFilter == null,
                      onTap: () => ref
                          .read(_libraryTypeFilterProvider.notifier)
                          .state = null,
                    ),
                    for (final t in ProjectType.values) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AppFilterChip(
                        label: t == ProjectType.texto ? 'Textos' : t.label,
                        selected: typeFilter == t,
                        onTap: () => ref
                            .read(_libraryTypeFilterProvider.notifier)
                            .state = t,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ref.watch(savedProjectsProvider).when(
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
                      final filtered = typeFilter == null
                          ? projects
                          : projects
                              .where((p) => p.type == typeFilter)
                              .toList();
                      // Estado vazio (§35).
                      if (filtered.isEmpty) return const _EmptyLibrary();
                      return _LibraryGrid(projects: filtered);
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EmptyState(
          icon: Icons.bookmark_border,
          title: 'Sua biblioteca está vazia.',
          subtitle: 'Salve projetos para encontrá-los aqui depois.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Explorar projetos',
          icon: Icons.rocket_launch_outlined,
          onPressed: () => context.go('/projetos'),
        ),
      ],
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 2 : 1;
        if (columns == 1) {
          return Column(
            children: [
              for (final p in projects)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: ProjectCardLoader(project: p),
                ),
            ],
          );
        }
        // Wrap com largura fixa e altura natural (mesma solução do feed):
        // grid com aspectRatio fixo estourava com títulos/tags longos.
        final cardWidth = (constraints.maxWidth - AppSpacing.lg) / columns;
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
  }
}
