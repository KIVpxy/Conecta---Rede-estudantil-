import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Parâmetros de filtro do feed de Materiais.
class MaterialsFilter {
  const MaterialsFilter({
    this.subject = 'Todos',
    this.kind,
    this.query = '',
  });

  final String subject;
  final MaterialPostKind? kind;
  final String query;

  MaterialsFilter copyWith({
    String? subject,
    MaterialPostKind? kind,
    bool clearKind = false,
    String? query,
  }) =>
      MaterialsFilter(
        subject: subject ?? this.subject,
        kind: clearKind ? null : (kind ?? this.kind),
        query: query ?? this.query,
      );
}

final materialsFilterProvider =
    StateProvider<MaterialsFilter>((ref) => const MaterialsFilter());

final materialsPostsProvider =
    FutureProvider<List<MaterialPost>>((ref) {
  final f = ref.watch(materialsFilterProvider);
  return ref.watch(materialRepositoryProvider).listPosts(
        subject: f.subject,
        kind: f.kind,
        query: f.query,
      );
});

const materialSubjects = [
  'Todos',
  'Matemática',
  'Física',
  'Biologia',
  'Química',
  'História',
  'Literatura',
  'Programação',
];

/// Aba Materiais (SPEC §3–10): postagens da comunidade — materiais,
/// perguntas e pedidos — cada uma com suas respostas.
class MaterialsPage extends ConsumerWidget {
  const MaterialsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = AppBreakpoints.isMobile(width);
    final filter = ref.watch(materialsFilterProvider);
    final postsAsync = ref.watch(materialsPostsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xxxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Materiais',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w700)),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                            'Materiais, perguntas e pedidos da comunidade — com respostas.',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  AppButton(
                    label: 'Nova postagem',
                    icon: Icons.add,
                    onPressed: () => context.go('/materiais/novo'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AppSearchField(
                  hint: 'Buscar postagens...',
                  onChanged: (v) => ref
                      .read(materialsFilterProvider.notifier)
                      .state = filter.copyWith(query: v),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in materialSubjects)
                      Padding(
                        padding:
                            const EdgeInsets.only(right: AppSpacing.sm),
                        child: AppFilterChip(
                          label: s,
                          selected: filter.subject == s,
                          onTap: () => ref
                              .read(materialsFilterProvider.notifier)
                              .state = filter.copyWith(subject: s),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppFilterChip(
                        label: 'Todos os tipos',
                        selected: filter.kind == null,
                        onTap: () => ref
                            .read(materialsFilterProvider.notifier)
                            .state = filter.copyWith(clearKind: true),
                      ),
                    ),
                    for (final k in MaterialPostKind.values)
                      Padding(
                        padding:
                            const EdgeInsets.only(right: AppSpacing.sm),
                        child: AppFilterChip(
                          label: k.label,
                          selected: filter.kind == k,
                          onTap: () => ref
                              .read(materialsFilterProvider.notifier)
                              .state = filter.copyWith(kind: k),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              postsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (posts) {
                  if (posts.isEmpty) {
                    return const EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'Nenhuma postagem encontrada',
                      subtitle:
                          'Seja o primeiro a compartilhar um material ou fazer uma pergunta.',
                    );
                  }
                  return Column(
                    children: [
                      for (final p in posts)
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.lg),
                          child: _PostCard(
                            post: p,
                            onTap: () =>
                                context.go('/materiais/${p.id}'),
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

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});

  final MaterialPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final author = post.author;

    return AppCard(
      onTap: onTap,
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
                    Text('✅', style: TextStyle(fontSize: 13)),
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
          const SizedBox(height: AppSpacing.md),
          Text(post.title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            post.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'por ${author?.name ?? 'Estudante'} • ${Fmt.relativeTime(post.createdAt)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              const Icon(Icons.chat_bubble_outline,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text('${post.answerCount} respostas',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
