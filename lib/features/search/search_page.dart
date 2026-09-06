import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/utils/limits.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';

/// Provider da pesquisa global (§27–§30): usuários, projetos e
/// materiais, com correspondência parcial.
final globalSearchProvider =
    FutureProvider.family<GlobalSearchResults, String>((ref, query) {
  return ref.watch(searchRepositoryProvider).search(query);
});

/// Filtro da página de pesquisa completa (§33).
enum SearchFilter { todos, usuarios, projetos, materiais }

extension SearchFilterX on SearchFilter {
  String get label => switch (this) {
        SearchFilter.todos => 'Todos',
        SearchFilter.usuarios => 'Usuários',
        SearchFilter.projetos => 'Projetos',
        SearchFilter.materiais => 'Materiais',
      };
}

final searchFilterProvider = StateProvider<SearchFilter>(
  (ref) => SearchFilter.todos,
);

/// Página completa de resultados da pesquisa global (§33).
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery.trim();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Debounce centralizado (§32): 250–400ms.
    _debounce = Timer(AppLimits.searchDebounce, () {
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;
    final filter = ref.watch(searchFilterProvider);
    final results = _query.isEmpty
        ? null
        : ref.watch(globalSearchProvider(_query)).value;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pesquisa',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xs),
              const Text('Usuários, projetos e materiais em um só lugar.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xl),
              AppSearchField(
                controller: _ctrl,
                hint: 'Buscar usuários, projetos, materiais…',
                onChanged: _onChanged,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Filtros por categoria (§33).
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final f in SearchFilter.values)
                    _FilterChip(
                      label: f.label,
                      selected: filter == f,
                      onTap: () => ref
                          .read(searchFilterProvider.notifier)
                          .state = f,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              if (_query.isEmpty)
                const EmptyState(
                  icon: Icons.search,
                  title: 'O que você procura?',
                  subtitle:
                      'Digite um nome, título de projeto ou assunto de material.',
                )
              else if (results == null)
                const Center(child: CircularProgressIndicator())
              else
                SearchResultsList(results: results, filter: filter),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.pillRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.pastelLavanda.withValues(alpha: 0.18)
              : AppColors.surface2,
          borderRadius: AppRadii.pillRadius,
          border: Border.all(
            color: selected ? AppColors.pastelLavanda : AppColors.borderSoft,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color:
                  selected ? AppColors.pastelLavanda : AppColors.textSecondary,
            )),
      ),
    );
  }
}

/// Lista agrupada de resultados — reutilizada pelo preview da topbar
/// (§31) e pela página completa (§33). Cada resultado é clicável e
/// leva ao destino certo (§30).
class SearchResultsList extends ConsumerWidget {
  const SearchResultsList({
    super.key,
    required this.results,
    this.filter = SearchFilter.todos,
    this.preview = false,
    this.onNavigate,
  });

  final GlobalSearchResults results;

  /// Chamado antes de navegar (a topbar usa para fechar o dropdown).
  final VoidCallback? onNavigate;

  /// Na página completa, limita pelas abas. No preview da topbar,
  /// mostra até [AppLimits.searchPreviewPerCategory] por categoria.
  final SearchFilter filter;
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Nenhum resultado',
        subtitle: 'Tente outro termo ou confira a ortografia.',
      );
    }

    final limit =
        preview ? AppLimits.searchPreviewPerCategory : 1 << 30;
    final showUsers =
        filter == SearchFilter.todos || filter == SearchFilter.usuarios;
    final showProjects =
        filter == SearchFilter.todos || filter == SearchFilter.projetos;
    final showMaterials =
        filter == SearchFilter.todos || filter == SearchFilter.materiais;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showUsers && results.users.isNotEmpty) ...[
          const _CategoryHeader('Usuários'),
          for (final u in results.users.take(limit))
            _UserResultTile(user: u, onNavigate: onNavigate),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (showProjects && results.projects.isNotEmpty) ...[
          const _CategoryHeader('Projetos'),
          for (final p in results.projects.take(limit))
            _ProjectResultTile(project: p, onNavigate: onNavigate),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (showMaterials && results.materials.isNotEmpty) ...[
          const _CategoryHeader('Materiais'),
          for (final m in results.materials.take(limit))
            _MaterialResultTile(post: m, onNavigate: onNavigate),
        ],
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary)),
    );
  }
}

class _UserResultTile extends ConsumerWidget {
  const _UserResultTile({required this.user, this.onNavigate});

  final VoidCallback? onNavigate;

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankFuture = ref.watch(profileRepositoryProvider).rankOf(user.id);
    return InkWell(
      onTap: () {
        onNavigate?.call();
        context.go('/perfil/${user.username}');
      },
      borderRadius: AppRadii.controlRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            FutureBuilder<RankTier>(
              future: rankFuture,
              builder: (context, snapshot) => RankAvatar(
                tier: snapshot.data ?? RankTier.bronze,
                url: user.avatarUrl,
                name: user.name,
                size: 36,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<RankTier>(
                    future: rankFuture,
                    builder: (context, snapshot) => UserDisplayName(
                      name: user.name,
                      rank: snapshot.data ?? RankTier.bronze,
                      isDeveloper: user.isDeveloper,
                    ),
                  ),
                  Text('@${user.username}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectResultTile extends StatelessWidget {
  const _ProjectResultTile({required this.project, this.onNavigate});

  final VoidCallback? onNavigate;

  final Project project;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onNavigate?.call();
        context.go('/projetos/${project.id}');
      },
      borderRadius: AppRadii.controlRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.pastelVerde.withValues(alpha: 0.14),
                borderRadius: AppRadii.controlRadius,
              ),
              child: const Icon(Icons.rocket_launch_outlined,
                  size: 18, color: AppColors.pastelVerde),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(project.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialResultTile extends StatelessWidget {
  const _MaterialResultTile({required this.post, this.onNavigate});

  final VoidCallback? onNavigate;

  final MaterialPost post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onNavigate?.call();
        context.go('/materiais/${post.id}');
      },
      borderRadius: AppRadii.controlRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.pastelAzulClaro.withValues(alpha: 0.14),
                borderRadius: AppRadii.controlRadius,
              ),
              child: const Icon(Icons.menu_book_outlined,
                  size: 18, color: AppColors.pastelAzulClaro),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(post.subject,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
