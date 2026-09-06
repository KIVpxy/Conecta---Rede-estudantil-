import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../data/models/models.dart';

/// Seletor de cor do card editorial de projetos do tipo Texto (SPEC §39).
///
/// Centraliza a paleta (TextCardPalette) e mostra as opções como
/// amostras circulares rotuladas: [ Marrom ] [ Azul ] [ Vinho ] [ Amarelo ].
class ColorSelector extends StatelessWidget {
  const ColorSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TextCardTone selected;
  final ValueChanged<TextCardTone> onChanged;

  static const _tones = TextCardTone.values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final tone in _tones)
          _ToneOption(
            tone: tone,
            selected: tone == selected,
            onTap: () => onChanged(tone),
          ),
      ],
    );
  }
}

class _ToneOption extends StatelessWidget {
  const _ToneOption({
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final TextCardTone tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = TextCardPalette.of(tone);
    final label = TextCardPalette.labelOf(color);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.controlRadius,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preview ao vivo do card editorial de texto, usado na criação (SPEC §39)
/// e reutilizado pelo feed (ver ProjectCard).
class TextCardPreview extends StatelessWidget {
  const TextCardPreview({
    super.key,
    required this.tone,
    required this.title,
    this.excerpt,
    this.compact = false,
  });

  final TextCardTone tone;
  final String title;
  final String? excerpt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = TextCardPalette.of(tone);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: AppRadii.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.format_quote,
              size: 20, color: Colors.white70),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title.isEmpty ? 'Título do seu texto' : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if ((excerpt ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              excerpt!,
              maxLines: compact ? 3 : 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
