import 'package:flutter/material.dart';

import '../../app/tokens.dart';

enum AppButtonVariant { primary, secondary, ghost }

/// Botão padrão do app.
/// primary = gradiente violeta→magenta (ações de criação/CTA principal).
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hover = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );

    Widget child = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: content,
    );

    switch (widget.variant) {
      case AppButtonVariant.primary:
        final disabled = !_enabled;
        child = AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: disabled ? 0.5 : (_hover ? 0.92 : 1),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: AppRadii.controlRadius,
            ),
            child: DefaultTextStyle(
              style: const TextStyle(color: AppColors.onAccent),
              child: IconTheme(
                data: const IconThemeData(color: AppColors.onAccent),
                child: child,
              ),
            ),
          ),
        );
        break;
      case AppButtonVariant.secondary:
        child = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _hover ? AppColors.surface3 : AppColors.surface2,
            borderRadius: AppRadii.controlRadius,
            border: Border.all(
              color: _hover
                  ? AppColors.textSecondary.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
                color: _enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary),
            child: IconTheme(
              data: IconThemeData(
                  color: _enabled
                      ? AppColors.textPrimary
                      : AppColors.textSecondary),
              child: child,
            ),
          ),
        );
        break;
      case AppButtonVariant.ghost:
        child = DefaultTextStyle(
          style: const TextStyle(color: AppColors.accentSoft),
          child: IconTheme(
            data: const IconThemeData(color: AppColors.accentSoft),
            child: child,
          ),
        );
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.controlRadius,
        child: InkWell(
          onTap: _enabled ? widget.onPressed : null,
          borderRadius: AppRadii.controlRadius,
          child: child,
        ),
      ),
    );
  }
}
