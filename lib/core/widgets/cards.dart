import 'package:flutter/material.dart';

import '../../app/tokens.dart';

/// Card base: surface1, borda fina, raio 16.
///
/// No desktop/web, o hover expande o card levemente (escala 1,02) com uma
/// sombra suave — animação de 200ms que não altera o layout nem empurra
/// outros elementos (Transform não afeta o fluxo). Em telas touch o
/// MouseRegion nunca dispara e o card funciona normalmente.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.hoverEffect = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  /// Ativa a animação de expansão no hover (padrão: ativa).
  final bool hoverEffect;

  static const _duration = Duration(milliseconds: 200);
  static const _curve = Curves.easeOutCubic;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final hovered = _hover && widget.hoverEffect;
    final bg = widget.color ??
        (hovered && interactive ? AppColors.surface2 : AppColors.surface1);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: hovered ? 1.02 : 1.0,
        duration: AppCard._duration,
        curve: AppCard._curve,
        child: AnimatedContainer(
          duration: AppCard._duration,
          curve: AppCard._curve,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(
              color: hovered
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.07),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: AppRadii.cardRadius,
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card compacto de estatística da dashboard (SPEC §7).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.accentSoft),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Labels longos quebram em até 3 linhas organizadas (ex.:
          // "RESPOSTAS CORRETAS / EM MATERIAIS") — nunca estouram o card
          // nem são escondidos (rodada 6, correção de overflow).
          Text(
            label.toUpperCase(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vazio com ação opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!,
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
