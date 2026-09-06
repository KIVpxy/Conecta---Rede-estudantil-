import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Lista de conversas diretas e grupos + convites pendentes (§20–§26).
final conversationsProvider =
    FutureProvider<List<Conversation>>((ref) {
  return ref.watch(messagingRepositoryProvider).conversations();
});

final pendingInvitesProvider = FutureProvider<List<GroupInvite>>((ref) {
  return ref.watch(messagingRepositoryProvider).myPendingInvites();
});

class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;
    final conversationsAsync = ref.watch(conversationsProvider);
    final invitesAsync = ref.watch(pendingInvitesProvider);
    final me = ref.watch(currentUserProvider).value;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Mensagens',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                  AppButton(
                    label: 'Criar grupo',
                    icon: Icons.group_add_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go('/mensagens/novo-grupo'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                  'Converse diretamente com qualquer estudante ou em grupo.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),

              // ---- Convites de grupo pendentes (§24) ----
              invitesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (invites) {
                  if (invites.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Convites de grupo',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.md),
                      for (final invite in invites)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _InviteCard(invite: invite),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  );
                },
              ),

              conversationsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (conversations) {
                  if (conversations.isEmpty || me == null) {
                    return const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'Nenhuma conversa ainda',
                      subtitle:
                          'Visite o perfil de um estudante e toque em "Mandar mensagem".',
                    );
                  }
                  return Column(
                    children: [
                      for (final c in conversations)
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.md),
                          child: _ConversationTile(
                            conversation: c,
                            myId: me.id,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de convite de grupo (§24): só o convidado pode aceitar.
/// Ignorar não adiciona ao grupo nem notifica o grupo.
class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite});

  final GroupInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(messagingRepositoryProvider);

    return FutureBuilder<({Conversation group, UserProfile inviter})>(
      future: repo.inviteContext(invite),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final group = data.group;
        final inviter = data.inviter;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.pastelRoxoClaro.withValues(alpha: 0.16),
                      borderRadius: AppRadii.controlRadius,
                    ),
                    child: const Icon(Icons.group_outlined,
                        color: AppColors.pastelRoxoClaro, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Você foi convidado para entrar no grupo: ${group.name ?? 'Grupo'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Convidado por: ${inviter.name.split(' ').first}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  AppButton(
                    label: 'Entrar no grupo',
                    icon: Icons.check,
                    onPressed: () => _accept(context, ref),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Ignorar',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => _ignore(context, ref),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final group =
        await ref.read(messagingRepositoryProvider).acceptInvite(invite.id);
    ref.invalidate(pendingInvitesProvider);
    ref.invalidate(conversationsProvider);
    if (context.mounted) {
      context.go('/mensagens/${group.id}');
    }
  }

  Future<void> _ignore(BuildContext context, WidgetRef ref) async {
    await ref.read(messagingRepositoryProvider).ignoreInvite(invite.id);
    ref.invalidate(pendingInvitesProvider);
    if (context.mounted) {
      AppToast.show(context, 'Convite ignorado.');
    }
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation, required this.myId});

  final Conversation conversation;
  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGroup = conversation.isGroup;
    // Em grupos, `other` não é exibido (cabeçalho mostra nome/membros).
    final other = conversation.other(myId);
    final rankAsync = isGroup
        ? null
        : ref.watch(profileRepositoryProvider).rankOf(other.id);

    return AppCard(
      onTap: () => context.go('/mensagens/${conversation.id}'),
      child: Row(
        children: [
          if (isGroup)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.pastelRoxoClaro.withValues(alpha: 0.16),
                borderRadius: AppRadii.controlRadius,
              ),
              child: const Icon(Icons.group_outlined,
                  color: AppColors.pastelRoxoClaro, size: 22),
            )
          else
            FutureBuilder<RankTier>(
              future: rankAsync,
              builder: (context, snapshot) => RankAvatar(
                tier: snapshot.data ?? RankTier.bronze,
                url: other.avatarUrl,
                name: other.name,
                size: 44,
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGroup)
                  Row(
                    children: [
                      Flexible(
                        child: Text(conversation.name ?? 'Grupo',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      const SizedBox(width: 6),
                      Text('${conversation.participants.length} membros',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  )
                else
                  Text(other.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  conversation.lastMessage ??
                      (isGroup ? 'Grupo criado.' : 'Comece a conversa...'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (conversation.lastMessageAt != null)
                Text(Fmt.relativeTime(conversation.lastMessageAt!),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              if (conversation.unreadCount > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: const BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Text('${conversation.unreadCount}',
                      style: const TextStyle(
                          color: AppColors.onAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
