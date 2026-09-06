import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/limits.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'messages_page.dart';

final _conversationProvider =
    FutureProvider.family<Conversation?, String>((ref, id) async {
  final list = await ref.watch(messagingRepositoryProvider).conversations();
  for (final c in list) {
    if (c.id == id) return c;
  }
  return null;
});

final _messagesProvider =
    FutureProvider.family<List<Message>, String>((ref, id) {
  return ref.watch(messagingRepositoryProvider).messages(id);
});

/// Conversa direta entre dois usuários (SPEC §31–34).
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationPage> createState() =>
      _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Marca como lida ao abrir.
    Future.microtask(() => ref
        .read(messagingRepositoryProvider)
        .markRead(widget.conversationId));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationAsync =
        ref.watch(_conversationProvider(widget.conversationId));
    final me = ref.watch(currentUserProvider).value;
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;

    return conversationAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (conversation) {
        if (conversation == null || me == null) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'Conversa não encontrada',
            action: AppButton(
              label: 'Voltar para Mensagens',
              onPressed: () => context.go('/mensagens'),
            ),
          );
        }
        final isGroup = conversation.isGroup;
        // Em grupos, `other` não é exibido (cabeçalho mostra o grupo).
        final other = conversation.other(me.id);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                // Header da conversa (direta ou grupo)
                Container(
                  padding: EdgeInsets.all(padding),
                  decoration: const BoxDecoration(
                    color: AppColors.bgAlt,
                    border:
                        Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 20),
                        color: AppColors.textSecondary,
                        onPressed: () => context.go('/mensagens'),
                      ),
                      if (isGroup)
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.pastelRoxoClaro
                                    .withValues(alpha: 0.16),
                                borderRadius: AppRadii.controlRadius,
                                image: (conversation.imageUrl != null &&
                                        conversation.imageUrl!
                                            .startsWith('http'))
                                    ? DecorationImage(
                                        image: NetworkImage(
                                            conversation.imageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: conversation.imageUrl == null
                                  ? const Icon(Icons.group_outlined,
                                      size: 18,
                                      color: AppColors.pastelRoxoClaro)
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(conversation.name ?? 'Grupo',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text(
                                    '${conversation.participants.length} membros',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: () =>
                              context.go('/perfil/${other.username}'),
                          borderRadius: AppRadii.controlRadius,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: other.avatarUrl != null
                                    ? NetworkImage(other.avatarUrl!)
                                    : null,
                                child: other.avatarUrl == null
                                    ? Text(other.name.characters.first)
                                    : null,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(other.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  Text('@${other.username}',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Mensagens
                Expanded(
                  child: ref
                      .watch(_messagesProvider(widget.conversationId))
                      .when(
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Erro: $e')),
                        data: (messages) {
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) {
                            if (_scroll.hasClients) {
                              _scroll.jumpTo(
                                  _scroll.position.maxScrollExtent);
                            }
                          });
                          return ListView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.all(padding),
                            itemCount: messages.length,
                            itemBuilder: (context, i) {
                              final msg = messages[i];
                              final isMine = msg.senderId == me.id;
                              // Em grupos, mostra quem enviou (§26).
                              String? senderName;
                              if (conversation.isGroup && !isMine) {
                                for (final p in conversation.participants) {
                                  if (p.id == msg.senderId) {
                                    senderName = p.name.split(' ').first;
                                    break;
                                  }
                                }
                              }
                              return _MessageBubble(
                                message: msg,
                                isMine: isMine,
                                senderName: senderName,
                              );
                            },
                          );
                        },
                      ),
                ),
                // Campo de envio
                Container(
                  padding: EdgeInsets.all(padding),
                  decoration: const BoxDecoration(
                    color: AppColors.bgAlt,
                    border:
                        Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLength: AppLimits.messageMaxLength,
                            minLines: 1,
                            maxLines: 4,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Escreva uma mensagem...',
                              isDense: true,
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AppButton(
                          label: 'Enviar',
                          icon: Icons.send,
                          loading: _sending,
                          onPressed:
                              _controller.text.trim().isEmpty
                                  ? null
                                  : _send,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(messagingRepositoryProvider)
          .sendMessage(widget.conversationId, _controller.text.trim());
      _controller.clear();
      ref.invalidate(_messagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
  });

  final Message message;
  final bool isMine;

  /// Nome do remetente (apenas em grupos, nas mensagens dos outros).
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isMine
              ? AppColors.accentMuted.withValues(alpha: 0.5)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: isMine
              ? null
              : Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (senderName != null) ...[
              Text(senderName!,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pastelLavanda)),
              const SizedBox(height: 2),
            ],
            Text(message.content,
                style: const TextStyle(fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 4),
            Text(
              Fmt.relativeTime(message.createdAt),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
