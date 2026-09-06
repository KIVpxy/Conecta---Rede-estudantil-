import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/level_math.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

final _userProvider =
    FutureProvider.family<UserProfile?, String>((ref, username) {
  return ref.watch(profileRepositoryProvider).getByUsername(username);
});

final _userProjectsProvider =
    FutureProvider.family<List<Project>, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).projectsOf(uid);
});

final _userRankProvider =
    FutureProvider.family<RankTier, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).rankOf(uid);
});

final _userBadgesProvider =
    FutureProvider.family<List<UserBadge>, String>((ref, uid) {
  return ref.watch(badgeRepositoryProvider).badgesOf(uid);
});

final _schoolProvider =
    FutureProvider.family<School?, String?>((ref, schoolId) {
  if (schoolId == null) return null;
  return ref.watch(schoolRepositoryProvider).getById(schoolId);
});

/// Perfil público de usuário (§1): avatar com moldura de rank, nome,
/// rank, bio, badges, escola, redes sociais, contato e ações.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_userProvider(username));
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (user) {
        if (user == null) {
          return EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Usuário não encontrado',
            action: AppButton(
              label: 'Voltar ao início',
              onPressed: () => context.go('/status'),
            ),
          );
        }

        final rank = ref.watch(_userRankProvider(user.id)).value ??
            RankTier.bronze;
        final projects =
            ref.watch(_userProjectsProvider(user.id)).value ?? [];
        final badges =
            ref.watch(_userBadgesProvider(user.id)).value ?? [];
        final school = ref.watch(_schoolProvider(user.schoolId)).value;
        final level = LevelMath.levelFor(user.xpTotal);
        final me = ref.watch(currentUserProvider).value;
        final isMe = me?.id == user.id;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeader(
                    user: user,
                    rank: rank,
                    level: level,
                    school: school,
                    isMe: isMe,
                    onMessage: () => _startConversation(context, ref, user),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _BadgesSection(userName: user.name, badges: badges),
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Projetos de ${user.name.split(' ').first}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.lg),
                  if (projects.isEmpty)
                    const EmptyState(
                      icon: Icons.rocket_launch_outlined,
                      title: 'Nenhum projeto publicado ainda',
                      subtitle: 'Todo criador começa com uma ideia.',
                    )
                  else
                    for (final p in projects)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: ProjectCard(
                          project: p,
                          author: user,
                          authorRank: rank,
                          onTap: () => context.go('/projetos/${p.id}'),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Abre (ou cria, se ainda não existir) a conversa direta com o
  /// usuário — sem duplicar conversas do mesmo par.
  Future<void> _startConversation(
      BuildContext context, WidgetRef ref, UserProfile user) async {
    final conversation = await ref
        .read(messagingRepositoryProvider)
        .getOrCreateConversation(user.id);
    if (context.mounted) {
      context.go('/mensagens/${conversation.id}');
    }
  }
}

/// Cabeçalho do perfil (§1–§5): foto + moldura do rank (a moldura NÃO
/// faz parte da imagem do usuário — §3), nome, rank, bio, escola,
/// redes sociais e contato. Campos vazios não aparecem (§5).
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.rank,
    required this.level,
    required this.school,
    required this.isMe,
    required this.onMessage,
  });

  final UserProfile user;
  final RankTier rank;
  final int level;
  final School? school;
  final bool isMe;
  final VoidCallback onMessage;

  bool get _hasBio => user.bio?.trim().isNotEmpty ?? false;
  bool get _hasInstagram => user.instagram?.trim().isNotEmpty ?? false;
  bool get _hasX => user.xHandle?.trim().isNotEmpty ?? false;
  bool get _hasContact => user.contactNumber?.trim().isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RankAvatar(tier: rank, url: user.avatarUrl, name: user.name, size: 72),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserDisplayName(
                      name: user.name,
                      rank: rank,
                      isDeveloper: user.isDeveloper,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    Text('@${user.username}',
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RankBadge(tier: rank), // modo full (§16)
                        Text('Nível $level',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                        Text('${Fmt.number(user.xpTotal)} XP',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bio multilinha (§4) — quebras de linha preservadas.
          if (_hasBio) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              user.bio!,
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: AppColors.textPrimary),
            ),
          ],

          // Escola, redes sociais e contato (§5) — campos vazios ocultos.
          if (school != null || _hasInstagram || _hasX || _hasContact) ...[
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                if (school != null)
                  _InfoChip(
                    icon: Icons.school_outlined,
                    label: school!.name,
                  ),
                if (_hasInstagram)
                  _InfoChip(
                    icon: Icons.camera_alt_outlined,
                    label: '@${user.instagram}',
                    onTap: () => _openUrl(
                        'https://instagram.com/${user.instagram}'),
                  ),
                if (_hasX)
                  _InfoChip(
                    icon: Icons.close,
                    label: '@${user.xHandle}',
                    onTap: () =>
                        _openUrl('https://x.com/${user.xHandle}'),
                  ),
                if (_hasContact)
                  _InfoChip(
                    icon: Icons.phone_outlined,
                    label: user.contactNumber!,
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              if (isMe)
                AppButton(
                  label: 'Editar perfil',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.edit_outlined,
                  onPressed: () => context.go('/editar-perfil'),
                )
              else
                AppButton(
                  label: 'Mandar mensagem',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.chat_bubble_outline,
                  onPressed: onMessage,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.pastelLavanda),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: onTap == null
          ? Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: content,
            )
          : InkWell(
              onTap: onTap,
              borderRadius: AppRadii.pillRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: content,
              ),
            ),
    );
  }
}

/// Badges do perfil (§6): SOMENTE desbloqueados, em linha horizontal
/// com scroll horizontal dentro da seção (a página rola vertical).
class _BadgesSection extends StatelessWidget {
  const _BadgesSection({required this.userName, required this.badges});

  final String userName;
  final List<UserBadge> badges;

  @override
  Widget build(BuildContext context) {
    final unlocked = badges.where((b) => b.unlocked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Badges de ${userName.split(' ').first}',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.lg),
        if (unlocked.isEmpty)
          const AppCard(
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: AppColors.textSecondary, size: 20),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Este usuário ainda não conquistou badges.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: unlocked.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) => SizedBox(
                width: 132,
                child: BadgeCard(
                  badge: unlocked[i],
                  onTap: () => showBadgeDetail(context, unlocked[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
