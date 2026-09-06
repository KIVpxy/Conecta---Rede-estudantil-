import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Notificações do usuário logado, mais recentes primeiro.
final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(notificationRepositoryProvider).notificationsOf(user.id);
});

/// Contador de não lidas exibido no sino (§17).
final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return 0;
  return ref.watch(notificationRepositoryProvider).unreadCount(user.id);
});

void refreshNotifications(WidgetRef ref) {
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadNotificationsProvider);
}

/// Sino da topbar (rodada 4, §11–§21): badge com a quantidade de não
/// lidas e painel dropdown com as notificações. Clicar em um item marca
/// como lida e abre o destino correspondente (conversa, grupo, projeto…).
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key, this.iconSize = 22});

  final double iconSize;

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final _layerLink = LayerLink();
  final Object _tapRegion = Object();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggle() {
    if (_overlay != null) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    // Largura limitada pela posição do sino na tela: a borda direita do
    // painel acompanha a do sino sem nunca sair da tela no mobile (§39).
    final box = context.findRenderObject() as RenderBox?;
    final bellRight = box == null
        ? MediaQuery.sizeOf(context).width
        : box.localToGlobal(Offset.zero).dx + box.size.width;
    final screenW = MediaQuery.sizeOf(context).width;
    var width = bellRight - AppSpacing.sm;
    if (width > 380) width = 380;
    if (width > screenW - 2 * AppSpacing.sm) {
      width = screenW - 2 * AppSpacing.sm;
    }
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          // Alinha a borda DIREITA do painel com a do sino — não estoura
          // a tela no mobile (§39).
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: TapRegion(
            groupId: _tapRegion,
            child: Material(
              color: Colors.transparent,
              child: _NotificationPanel(onClose: _removeOverlay),
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
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        groupId: _tapRegion,
        onTapOutside: (_) => _removeOverlay(),
        child: IconButton(
          onPressed: _toggle,
          tooltip: 'Notificações',
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(
              unread > 99 ? '99+' : (unread > 9 ? '9+' : '$unread'),
              style: const TextStyle(
                  color: AppColors.onAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.accent,
            child: Icon(Icons.notifications_outlined,
                color: AppColors.textSecondary, size: widget.iconSize),
          ),
        ),
      ),
    );
  }
}

/// Painel dropdown com a lista de notificações (§18–§20).
class _NotificationPanel extends ConsumerWidget {
  const _NotificationPanel({required this.onClose});

  /// Fecha o painel (usado ao clicar em uma notificação, antes de
  /// navegar — o painel não pode ficar aberto sobre a nova página).
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Container(
      constraints: const BoxConstraints(maxHeight: 460),
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
      child: notificationsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Erro: $e',
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        data: (notifications) {
          final hasUnread = notifications.any((n) => !n.isRead);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                    AppSpacing.md, AppSpacing.sm, AppSpacing.xs),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Notificações',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    // §20: opção visível apenas quando há não lidas.
                    if (hasUnread)
                      TextButton(
                        onPressed: () async {
                          final user =
                              await ref.read(currentUserProvider.future);
                          if (user == null) return;
                          await ref
                              .read(notificationRepositoryProvider)
                              .markAllRead(user.id);
                          refreshNotifications(ref);
                        },
                        child: const Text('Marcar todas como lidas',
                            style: TextStyle(
                                color: AppColors.accentSoft, fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Flexible(
                child: notifications.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.xxxl),
                        child: Text('Nenhuma notificação por aqui.',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs),
                        itemCount: notifications.length,
                        itemBuilder: (context, i) => _NotificationTile(
                            notification: notifications[i],
                            onClose: onClose),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Item do painel (§18–§19): avatar do autor, texto, tempo relativo e
/// estado lido/não lido com destaque sutil (fundo + ponto lavanda).
class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.onClose});

  final AppNotification notification;
  final VoidCallback onClose;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    onClose();
    await ref
        .read(notificationRepositoryProvider)
        .markRead(notification.id);
    refreshNotifications(ref);
    if (!context.mounted) return;
    switch (notification.type) {
      case NotificationType.message:
      case NotificationType.groupMessage:
        final refId = notification.referenceId;
        if (refId != null) context.go('/mensagens/$refId');
      case NotificationType.projectRating:
        final refId = notification.referenceId;
        if (refId != null) context.go('/projetos/$refId');
      case NotificationType.groupInvite:
        context.go('/mensagens');
      case NotificationType.schoolAnnouncement:
        context.go('/escola');
      case NotificationType.system:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = !notification.isRead;
    return Material(
      // Não lida: fundo sutilmente diferente; lida: transparente (§19).
      color: unread
          ? AppColors.accent.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActorAvatar(notification: notification),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight:
                            unread ? FontWeight.w600 : FontWeight.w400,
                        color: unread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(Fmt.relativeTime(notification.createdAt),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11.5)),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: AppSpacing.sm),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: CircleAvatar(
                      radius: 4, backgroundColor: AppColors.accent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar do autor da ação; para tipos sem autor (sistema, comunicado)
/// usa um ícone pastel no lugar (§18).
class _ActorAvatar extends ConsumerWidget {
  const _ActorAvatar({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorId = notification.actorUserId;
    if (actorId == null) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          notification.type == NotificationType.schoolAnnouncement
              ? Icons.campaign_outlined
              : Icons.info_outline,
          size: 18,
          color: AppColors.accentSoft,
        ),
      );
    }
    final actor = ref
        .watch(profileRepositoryProvider)
        .getById(actorId);
    return FutureBuilder<UserProfile?>(
      future: actor,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return AppAvatar(
            url: user?.avatarUrl, name: user?.name ?? '?', size: 36);
      },
    );
  }
}
