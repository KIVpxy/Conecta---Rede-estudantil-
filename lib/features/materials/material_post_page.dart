import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/services/permission_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/limits.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'materials_page.dart';

final _postProvider =
    FutureProvider.family<MaterialPost?, String>((ref, id) {
  return ref.watch(materialRepositoryProvider).getPost(id);
});

final _answersProvider =
    FutureProvider.family<List<MaterialAnswer>, String>((ref, id) {
  return ref.watch(materialRepositoryProvider).answersOf(id);
});

final _rankOfProvider =
    FutureProvider.family<RankTier, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).rankOf(userId);
});

/// Postagem de Materiais com suas respostas (SPEC §5–9).
/// A melhor resposta é selecionada exclusivamente pela moderação
/// (permissão validada também na camada de dados).
class MaterialPostPage extends ConsumerWidget {
  const MaterialPostPage({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(_postProvider(postId));
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;

    return postAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (post) {
        if (post == null) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'Postagem não encontrada',
            action: AppButton(
              label: 'Voltar para Materiais',
              onPressed: () => context.go('/materiais'),
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostHeader(post: post),
                  const SizedBox(height: AppSpacing.xxl),
                  _AnswersSection(post: post),
                  const SizedBox(height: AppSpacing.xl),
                  _AnswerForm(post: post),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PostHeader extends ConsumerWidget {
  const _PostHeader({required this.post});

  final MaterialPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = post.author;
    final rank = author == null
        ? RankTier.bronze
        : ref.watch(_rankOfProvider(author.id)).value ?? RankTier.bronze;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppTag(label: post.kind.label),
              const SizedBox(width: AppSpacing.sm),
              AppTag(label: post.subject),
              const Spacer(),
              if (post.hasAcceptedAnswer)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('✅', style: TextStyle(fontSize: 14)),
                    SizedBox(width: AppSpacing.xs),
                    Text('Respondida',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(post.title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: AppSpacing.lg),
          if (author != null)
            InkWell(
              onTap: () => context.go('/perfil/${author.username}'),
              borderRadius: AppRadii.controlRadius,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RankAvatar(
                      tier: rank,
                      url: author.avatarUrl,
                      name: author.name,
                      size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                          '@${author.username} • ${Fmt.relativeTime(post.createdAt)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(post.content,
              style: const TextStyle(
                  fontSize: 14.5, height: 1.6,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _AnswersSection extends ConsumerWidget {
  const _AnswersSection({required this.post});

  final MaterialPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answersAsync = ref.watch(_answersProvider(post.id));
    final me = ref.watch(currentUserProvider).value;
    // §35: apenas Developers marcam/trocam/removem a melhor resposta.
    final canModerate = PermissionService.canMarkAcceptedAnswer(me);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Respostas (${post.answerCount})',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.lg),
        answersAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erro: $e'),
          data: (answers) {
            if (answers.isEmpty) {
              return const AppCard(
                child: Text(
                    'Nenhuma resposta ainda — ajude um colega!',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }
            return Column(
              children: [
                for (final a in answers)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _AnswerEntry(
                      answer: a,
                      canModerate: canModerate,
                      onSelectBest: canModerate
                          ? () => _selectBest(context, ref, a)
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _selectBest(
      BuildContext context, WidgetRef ref, MaterialAnswer answer) async {
    await ref
        .read(materialRepositoryProvider)
        .selectBestAnswer(post.id, answer.id);
    ref.invalidate(_postProvider(post.id));
    ref.invalidate(_answersProvider(post.id));
    ref.invalidate(materialsPostsProvider);
    if (context.mounted) {
      AppToast.show(context, 'Melhor resposta selecionada.');
    }
  }
}

class _AnswerEntry extends ConsumerWidget {
  const _AnswerEntry({
    required this.answer,
    required this.canModerate,
    this.onSelectBest,
  });

  final MaterialAnswer answer;
  final bool canModerate;
  final VoidCallback? onSelectBest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(_rankOfProvider(answer.authorId)).value ??
        RankTier.bronze;
    final username = answer.author?.username;

    return MaterialAnswerCard(
      answer: answer,
      authorRank: rank,
      canModerate: canModerate,
      onSelectBest: onSelectBest,
      onTapAuthor: username == null
          ? null
          : () => context.go('/perfil/$username'),
    );
  }
}

class _AnswerForm extends ConsumerStatefulWidget {
  const _AnswerForm({required this.post});

  final MaterialPost post;

  @override
  ConsumerState<_AnswerForm> createState() => _AnswerFormState();
}

class _AnswerFormState extends ConsumerState<_AnswerForm> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sua resposta',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _controller,
            hint: 'Escreva uma resposta clara e completa...',
            maxLines: 5,
            maxLength: AppLimits.materialAnswerMaxLength,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Responder',
              icon: Icons.send,
              loading: _sending,
              onPressed:
                  _controller.text.trim().isEmpty ? null : _send,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(materialRepositoryProvider)
          .answer(widget.post.id, _controller.text.trim());
      _controller.clear();
      ref.invalidate(_postProvider(widget.post.id));
      ref.invalidate(_answersProvider(widget.post.id));
      if (mounted) {
        AppToast.show(context, 'Resposta publicada!');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
