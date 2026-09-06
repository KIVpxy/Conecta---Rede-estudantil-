import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../data/models/models.dart';
import 'rank_frame.dart';

/// Cor principal de cada rank (fonte única: [rankConfigs]).
Color rankColor(RankTier tier) => rankConfig(tier).primary;

/// Cor do NOME do usuário por rank (§17–§18): apenas Esmeralda, Diamante
/// e Sublime coloridos; Bronze e Ouro usam a cor normal de texto.
/// Centralizado aqui — usar via [UserDisplayName], nunca replicar a
/// regra nas páginas.
Color? rankNameColor(RankTier tier) => switch (tier) {
      RankTier.esmeralda => AppColors.nameEsmeralda,
      RankTier.diamante => AppColors.nameDiamante,
      RankTier.sublime => AppColors.nameSublime,
      _ => null,
    };

/// Modos de exibição do selo de rank (§16).
enum RankBadgeMode {
  /// Compacto: cards, comentários, mensagens e pesquisa.
  compact,

  /// Completo: perfil, Status e página de Rank — mais presença.
  full,
}

/// Chip com a identidade do rank (§15–§16).
/// Presença por modo, fundo suave na cor do rank, Montserrat Bold.
class RankBadge extends StatelessWidget {
  const RankBadge({
    super.key,
    required this.tier,
    this.mode = RankBadgeMode.full,
  });

  final RankTier tier;
  final RankBadgeMode mode;

  @override
  Widget build(BuildContext context) {
    final color = rankColor(tier);
    final compact = mode == RankBadgeMode.compact;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.lg,
          vertical: compact ? AppSpacing.xs : AppSpacing.sm),
      decoration: BoxDecoration(
        // Fundo suave na cor do rank — sem glow/neon.
        color: color.withValues(alpha: compact ? 0.14 : 0.18),
        borderRadius: AppRadii.pillRadius,
        border: Border.all(
          color: color.withValues(alpha: compact ? 0.5 : 0.65),
          width: compact ? 1 : 1.3,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RankEmblem(tier: tier, size: compact ? 12 : 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            tier.labelUpper,
            style: TextStyle(
              fontSize: compact ? 9 : 12,
              fontWeight: compact ? FontWeight.w700 : FontWeight.w800,
              letterSpacing: compact ? 0.8 : 1.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Emblema geométrico do rank (CustomPainter).
/// Família gráfica evolutiva:
/// Bronze = hexágono simples · Ouro = hexágono detalhado ·
/// Esmeralda = losango facetado · Diamante = cristal refinado ·
/// Sublime = estrela/sol simétrico (raro, elegante).
class RankEmblem extends StatelessWidget {
  const RankEmblem({super.key, required this.tier, this.size = 40});

  final RankTier tier;

  /// Tamanhos oficiais: 64, 40, 24.
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RankEmblemPainter(tier),
    );
  }
}

class _RankEmblemPainter extends CustomPainter {
  _RankEmblemPainter(this.tier);

  final RankTier tier;

  Path _polygon(Offset center, double radius, int sides,
      {double rotation = -math.pi / 2}) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = rotation + (2 * math.pi * i / sides);
      final p = center +
          Offset(radius * math.cos(angle), radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final color = rankColor(tier);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.09);

    switch (tier) {
      case RankTier.bronze:
        fill.color = color.withValues(alpha: 0.25);
        stroke.color = color;
        final hex = _polygon(center, r * 0.85, 6);
        canvas.drawPath(hex, fill);
        canvas.drawPath(hex, stroke);
        break;
      case RankTier.ouro:
        fill.color = color.withValues(alpha: 0.22);
        stroke.color = color;
        final outer = _polygon(center, r * 0.85, 6);
        canvas.drawPath(outer, fill);
        canvas.drawPath(outer, stroke);
        final inner = _polygon(center, r * 0.5, 6);
        canvas.drawPath(inner, stroke..strokeWidth = math.max(1.0, r * 0.06));
        canvas.drawCircle(center, r * 0.12, Paint()..color = color);
        break;
      case RankTier.esmeralda:
        final paint = Paint()
          ..shader = LinearGradient(
            colors: [color, color.withValues(alpha: 0.55)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Offset.zero & size);
        final gem = Path()
          ..moveTo(center.dx, center.dy - r * 0.9)
          ..lineTo(center.dx + r * 0.7, center.dy)
          ..lineTo(center.dx, center.dy + r * 0.9)
          ..lineTo(center.dx - r * 0.7, center.dy)
          ..close();
        canvas.drawPath(gem, paint);
        canvas.drawPath(
            gem,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, r * 0.06)
              ..color = Colors.white.withValues(alpha: 0.35));
        canvas.drawLine(
            center + Offset(-r * 0.7, 0),
            center + Offset(r * 0.7, 0),
            Paint()
              ..strokeWidth = math.max(1.0, r * 0.05)
              ..color = Colors.white.withValues(alpha: 0.3));
        break;
      case RankTier.diamante:
        final paint = Paint()
          ..shader = LinearGradient(
            colors: [color, const Color(0xFFBEE9F2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Offset.zero & size);
        final top = _polygon(center + Offset(0, -r * 0.35), r * 0.55, 3,
            rotation: -math.pi / 2);
        final bottom = _polygon(center + Offset(0, r * 0.45), r * 0.55, 3,
            rotation: math.pi / 2);
        canvas.drawPath(top, paint);
        canvas.drawPath(
            bottom,
            Paint()
              ..color = color.withValues(alpha: 0.7));
        canvas.drawPath(
            top,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, r * 0.05)
              ..color = Colors.white.withValues(alpha: 0.4));
        break;
      case RankTier.sublime:
        final paint = Paint()
          ..shader = AppColors.rankSublimeGradient
              .createShader(Offset.zero & size);
        // Estrela/sol de 8 pontas, simétrica.
        final star = Path();
        const points = 8;
        for (var i = 0; i < points * 2; i++) {
          final radius = i.isEven ? r * 0.92 : r * 0.42;
          final angle = -math.pi / 2 + (math.pi * i / points);
          final p = center +
              Offset(radius * math.cos(angle), radius * math.sin(angle));
          if (i == 0) {
            star.moveTo(p.dx, p.dy);
          } else {
            star.lineTo(p.dx, p.dy);
          }
        }
        star.close();
        canvas.drawPath(star, paint);
        canvas.drawCircle(center, r * 0.2,
            Paint()..color = Colors.white.withValues(alpha: 0.9));
        break;
    }
  }

  @override
  bool shouldRepaint(_RankEmblemPainter oldDelegate) =>
      oldDelegate.tier != tier;
}
