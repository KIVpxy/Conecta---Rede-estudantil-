import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../data/models/models.dart';
import 'rank.dart';
import 'rank_frame.dart';

/// Avatar com fallback de iniciais e cor determinística pelo nome.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = 40,
  });

  final String? url;
  final String name;
  final double size;

  static const _palette = [
    Color(0xFF7C3AED),
    Color(0xFF3FC1D8),
    Color(0xFF2FBF8F),
    Color(0xFFE3B341),
    Color(0xFFB08D57),
    Color(0xFFC084FC),
    Color(0xFFE5534B),
  ];

  Color _colorFor(String name) =>
      _palette[name.hashCode.abs() % _palette.length];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: _colorFor(name).withValues(alpha: 0.25),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: _colorFor(name),
        ),
      ),
    );

    if (url == null || url!.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: url!,
      imageBuilder: (_, provider) => CircleAvatar(
        radius: size / 2,
        backgroundImage: provider,
      ),
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// Nome do usuário com cor de Elo alto (§17–§18) e selo [DEV] (§41).
/// ÚNICO lugar onde a regra de cor por rank existe — não replicar.
class UserDisplayName extends StatelessWidget {
  const UserDisplayName({
    super.key,
    required this.name,
    required this.rank,
    this.isDeveloper = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.showDevSeal = true,
  });

  final String name;
  final RankTier rank;
  final bool isDeveloper;
  final double fontSize;
  final FontWeight fontWeight;

  /// Selo [DEV] junto ao nome de Developers (pequeno e elegante, §41).
  final bool showDevSeal;

  @override
  Widget build(BuildContext context) {
    // Bronze/Ouro → cor normal. Esmeralda/Diamante/Sublime → cor suave.
    final color = rankNameColor(rank) ?? AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: fontWeight,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ),
        if (isDeveloper && showDevSeal) ...[
          const SizedBox(width: 6),
          const DevSeal(),
        ],
      ],
    );
  }
}

/// Selo [DEV] — pequeno, elegante, pastel (§41).
/// Não substitui o rank nem determina a cor do nome.
class DevSeal extends StatelessWidget {
  const DevSeal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.devSeal.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.devSeal.withValues(alpha: 0.55)),
      ),
      child: const Text(
        'DEV',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.devSeal,
        ),
      ),
    );
  }
}

/// Linha de usuário: avatar, nome, @username, rank e trailing opcional.
class UserRow extends StatelessWidget {
  const UserRow({
    super.key,
    required this.user,
    this.rank,
    this.trailing,
    this.onTap,
    this.subtitle,
  });

  final UserProfile user;
  final RankTier? rank;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.controlRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            rank != null
                ? RankAvatar(
                    tier: rank!,
                    name: user.name,
                    url: user.avatarUrl,
                    size: 36,
                  )
                : AppAvatar(url: user.avatarUrl, name: user.name, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserDisplayName(
                    name: user.name,
                    rank: rank ?? RankTier.bronze,
                    isDeveloper: user.isDeveloper,
                  ),
                  Text(
                    subtitle ?? '@${user.username}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (rank != null) ...[
              const SizedBox(width: AppSpacing.sm),
              RankBadge(tier: rank!, mode: RankBadgeMode.compact),
            ],
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Avatares sobrepostos de colaboradores: "Kevin + Pedro + Ana + 2".
class CollaboratorAvatarGroup extends StatelessWidget {
  const CollaboratorAvatarGroup({
    super.key,
    required this.users,
    this.maxVisible = 4,
    this.avatarSize = 26,
    this.onTap,
  });

  final List<UserProfile> users;
  final int maxVisible;
  final double avatarSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    final visible = users.take(maxVisible).toList();
    final extra = users.length - visible.length;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.pillRadius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: avatarSize +
                (visible.length - 1) * (avatarSize * 0.62) +
                (extra > 0 ? avatarSize * 0.62 : 0),
            height: avatarSize,
            child: Stack(
              children: [
                for (var i = 0; i < visible.length; i++)
                  Positioned(
                    left: i * avatarSize * 0.62,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.surface1, width: 2),
                      ),
                      child: AppAvatar(
                        url: visible[i].avatarUrl,
                        name: visible[i].name,
                        size: avatarSize,
                      ),
                    ),
                  ),
                if (extra > 0)
                  Positioned(
                    left: visible.length * avatarSize * 0.62,
                    child: CircleAvatar(
                      radius: avatarSize / 2,
                      backgroundColor: AppColors.surface3,
                      child: Text('+$extra',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
