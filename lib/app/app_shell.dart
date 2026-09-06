import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/limits.dart';
import '../core/widgets/rank_frame.dart';
import '../core/widgets/widgets.dart';
import '../data/providers.dart';
import '../features/notifications/notification_bell.dart';
import '../features/search/search_page.dart';
import 'auth_state.dart';
import 'tokens.dart';

/// Navegação global do app.
/// Desktop: sidebar persistente + topbar.
/// Tablet: sidebar compacta + topbar.
/// Mobile: topbar fina + bottom navigation com botão "Criar" central.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// Itens da navegação principal (sidebar desktop/tablet).
  static const _items = [
    _NavItem('Status', Icons.insights_outlined, '/status'),
    _NavItem('Projetos', Icons.rocket_launch_outlined, '/projetos'),
    _NavItem('Escola', Icons.school_outlined, '/escola'),
    _NavItem('Materiais', Icons.menu_book_outlined, '/materiais'),
    _NavItem('Mensagens', Icons.chat_bubble_outline, '/mensagens'),
    _NavItem('Biblioteca', Icons.bookmark_border, '/biblioteca'),
    _NavItem('Ranking', Icons.emoji_events_outlined, '/ranking'),
    _NavItem('Perfil', Icons.person_outline, '/perfil/kevinoliveira'),
  ];

  /// Itens da bottom bar mobile (Ranking e Perfil ficam no menu do avatar
  /// da topbar mobile, para não lotar a barra com o botão Criar central).
  static const _mobileItems = [
    _NavItem('Status', Icons.insights_outlined, '/status'),
    _NavItem('Projetos', Icons.rocket_launch_outlined, '/projetos'),
    _NavItem('Escola', Icons.school_outlined, '/escola'),
    _NavItem('Materiais', Icons.menu_book_outlined, '/materiais'),
  ];

  int _indexOf(String location) {
    if (location.startsWith('/projetos')) return 1;
    if (location.startsWith('/escola')) return 2;
    if (location.startsWith('/materiais')) return 3;
    if (location.startsWith('/mensagens')) return 4;
    if (location.startsWith('/biblioteca')) return 5;
    if (location.startsWith('/ranking')) return 6;
    if (location.startsWith('/perfil')) return 7;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final location = GoRouterState.of(context).uri.path;
    final index = _indexOf(location);

    if (AppBreakpoints.isMobile(width)) {
      return _MobileShell(index: index, child: child);
    }
    final compact = AppBreakpoints.isTablet(width);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          _Sidebar(compact: compact, index: index),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: Column(
              children: [
                const _TopBar(),
                const Divider(height: 1, color: AppColors.border),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

/// Identidade do app no cabeçalho (rodada 4, §22–§24): SOMENTE o texto
/// "Conecta" em Montserrat — sem ícone/logo gráfico antes do nome.
class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Na rail compacta não cabe texto: mantém apenas o espaçamento.
    if (compact) return const SizedBox(width: 32, height: 32);
    return const Text(
      'Conecta',
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.compact, required this.index});

  final bool compact;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 72 : 232,
      color: AppColors.bgAlt,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _Brand(compact: compact),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < AppShell._items.length; i++)
              _SidebarTile(
                item: AppShell._items[i],
                selected: i == index,
                compact: compact,
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                compact ? 'v0.1' : 'Crie. Compartilhe. Evolua.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends ConsumerWidget {
  const _SidebarTile(
      {required this.item, required this.selected, required this.compact});

  final _NavItem item;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color =
        selected ? AppColors.textPrimary : AppColors.textSecondary;
    // O perfil é do usuário LOGADO — nunca uma rota fixa de outra pessoa.
    var route = item.route;
    if (route.startsWith('/perfil')) {
      final me = ref.watch(currentUserProvider).value;
      if (me != null) route = '/perfil/${me.username}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Material(
        color: selected ? AppColors.surface3 : Colors.transparent,
        borderRadius: AppRadii.controlRadius,
        child: InkWell(
          borderRadius: AppRadii.controlRadius,
          onTap: () => context.go(route),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(item.icon, size: 20, color: color),
                if (!compact) ...[
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Text(item.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar do usuário logado com a moldura do rank dele.
class _CurrentUserAvatar extends ConsumerWidget {
  const _CurrentUserAvatar({this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final rank = ref.watch(currentUserRankProvider).value;
    if (user == null || rank == null) {
      return CircleAvatar(radius: size / 2, child: const Text('…'));
    }
    return RankAvatar(
        tier: rank, name: user.name, url: user.avatarUrl, size: size);
  }
}

/// Menu do avatar (perfil, ranking, sair) — usado na topbar.
class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.child, this.showRanking = false});

  final Widget child;

  /// No mobile a bottom bar não tem Ranking, então ele entra no menu.
  final bool showRanking;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    // Logout DE VERDADE: encerra a sessão no backend (Supabase) e
    // limpa o estado local. Só navegar para /login mantinha a sessão
    // viva e o router jogava o usuário de volta para dentro.
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // Mesmo sem rede, o logout local precisa acontecer.
    }
    // O redirect do router joga para /login assim que o estado muda.
    ref.read(authStateProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    return PopupMenuButton<String>(
      tooltip: 'Perfil',
      onSelected: (value) {
        if (value == 'perfil' && me != null) {
          context.go('/perfil/${me.username}');
        }
        if (value == 'biblioteca') context.go('/biblioteca');
        if (value == 'mensagens') context.go('/mensagens');
        if (value == 'ranking') context.go('/ranking');
        if (value == 'sair') _signOut(context, ref);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'perfil', child: Text('Meu perfil')),
        // A bottom bar mobile não tem Biblioteca (nem Ranking/Mensagens),
        // então elas entram aqui no menu do avatar (§28).
        if (showRanking) ...[
          const PopupMenuItem(
              value: 'biblioteca', child: Text('Biblioteca')),
          const PopupMenuItem(
              value: 'mensagens', child: Text('Mensagens')),
          const PopupMenuItem(value: 'ranking', child: Text('Ranking')),
        ],
        const PopupMenuItem(value: 'sair', child: Text('Sair')),
      ],
      child: child,
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    return Container(
      height: 60,
      color: AppColors.bgAlt,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 420, child: _GlobalSearchField()),
            ),
          ),
          // (dropdown da pesquisa é construído dentro do próprio campo)
          const NotificationBell(),
          const SizedBox(width: AppSpacing.sm),
          _CreateButton(
            onTap: () => context.go('/projetos/novo'),
          ),
          const SizedBox(width: AppSpacing.md),
          _UserMenu(
            child: Row(
              children: [
                _CurrentUserAvatar(size: 30),
                SizedBox(width: AppSpacing.sm),
                Text('@${me?.username ?? '…'}',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                Icon(Icons.keyboard_arrow_down,
                    size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pesquisa global da topbar (§27–§32): busca dinâmica em usuários,
/// projetos e materiais com debounce e preview agrupado por categoria.
class _GlobalSearchField extends ConsumerStatefulWidget {
  const _GlobalSearchField();

  @override
  ConsumerState<_GlobalSearchField> createState() =>
      _GlobalSearchFieldState();
}

class _GlobalSearchFieldState extends ConsumerState<_GlobalSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _layerLink = LayerLink();
  final Object _searchTapRegion = Object();
  OverlayEntry? _overlay;
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Debounce entre 250–400ms (§32), centralizado em AppLimits.
    _debounce = Timer(AppLimits.searchDebounce, () {
      setState(() => _query = value.trim());
      if (_query.isEmpty) {
        _removeOverlay();
      } else {
        _showOverlay();
      }
    });
  }

  void _goToFullSearch() {
    _removeOverlay();
    context.go('/pesquisa?q=${Uri.encodeQueryComponent(_query)}');
  }

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 420,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 46),
          child: TapRegion(
            groupId: _searchTapRegion,
            child: Material(
              color: Colors.transparent,
              child: _buildPreview(context),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        groupId: _searchTapRegion,
        onTapOutside: (_) => _removeOverlay(),
        child: SizedBox(
          height: 38,
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            onChanged: _onChanged,
            onSubmitted: (_) => _goToFullSearch(),
            decoration: InputDecoration(
              hintText: 'Buscar usuários, projetos, materiais...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final resultsAsync = ref.watch(globalSearchProvider(_query));
    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: resultsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('Erro na busca.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        data: (results) {
          if (results.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Nenhum resultado.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview: até 5 por categoria (§31).
                SearchResultsList(
                    results: results,
                    preview: true,
                    onNavigate: _removeOverlay),
                const Divider(height: AppSpacing.lg),
                InkWell(
                  onTap: _goToFullSearch,
                  borderRadius: AppRadii.controlRadius,
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 16,
                            color: AppColors.pastelLavanda),
                        SizedBox(width: AppSpacing.sm),
                        Text('Ver todos os resultados',
                            style: TextStyle(
                                color: AppColors.pastelLavanda,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: AppRadii.controlRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.controlRadius,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: AppRadii.controlRadius,
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
          child: const Row(
            children: [
              Icon(Icons.add, size: 18, color: AppColors.onAccent),
              SizedBox(width: AppSpacing.xs),
              Text('Criar',
                  style: TextStyle(
                      color: AppColors.onAccent, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final items = AppShell._mobileItems;
    // Índices da bottom bar: 0 Status, 1 Projetos, 2 Escola, 3 Materiais.
    final bottomIndex = index > 3 ? -1 : index;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgAlt,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: AppSpacing.lg,
        title: const _Brand(compact: false),
        actions: [
          const NotificationBell(),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: _UserMenu(
              showRanking: true,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: _CurrentUserAvatar(size: 28),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(top: false, child: child),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/projetos/novo'),
        elevation: 0,
        shape: const CircleBorder(),
        child: Ink(
          decoration: const BoxDecoration(
            gradient: AppColors.accentGradient,
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.add, color: AppColors.onAccent),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.bgAlt,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _MobileTab(
                item: items[0],
                selected: bottomIndex == 0,
                onTap: () => context.go(items[0].route)),
            _MobileTab(
                item: items[1],
                selected: bottomIndex == 1,
                onTap: () => context.go(items[1].route)),
            const SizedBox(width: 48), // espaço do botão Criar
            _MobileTab(
                item: items[2],
                selected: bottomIndex == 2,
                onTap: () => context.go(items[2].route)),
            _MobileTab(
                item: items[3],
                selected: bottomIndex == 3,
                onTap: () => context.go(items[3].route)),
          ],
        ),
      ),
    );
  }
}

class _MobileTab extends StatelessWidget {
  const _MobileTab(
      {required this.item, required this.selected, required this.onTap});

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.accentSoft : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.controlRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 22, color: color),
            Text(item.label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
