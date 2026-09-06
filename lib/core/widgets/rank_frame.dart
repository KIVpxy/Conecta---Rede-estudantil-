import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../data/models/models.dart';
import 'user.dart';

/// Configuração visual centralizada de cada rank.
///
/// Arquitetura: RankTier → RankConfig → moldura (frame) → RankAvatar.
/// Para adicionar um rank novo basta incluir uma entrada em [rankConfigs]
/// e um caso no painter [_RankFramePainter].
class RankConfig {
  const RankConfig({
    required this.tier,
    required this.primary,
    required this.secondary,
    required this.xpStart,
    required this.xpRequired,
    this.ringGradient,
    this.glow = 0.0,
  });

  final RankTier tier;

  /// Cor principal do rank (anel, brilho, detalhes).
  final Color primary;

  /// Cor secundária para gradientes e detalhes internos.
  final Color secondary;

  /// XP total acumulado a partir do qual este rank começa.
  final int xpStart;

  /// XP necessário DENTRO deste rank para avançar ao próximo.
  /// A barra do rank exibe `(xpTotal - xpStart) / xpRequired`.
  final int xpRequired;

  /// Gradiente do anel (quando definido, tem prioridade sobre [primary]).
  final Gradient? ringGradient;

  /// Intensidade do brilho ao redor da moldura (0 = sem brilho).
  final double glow;
}

/// Mapa central Rank → configuração (visual + requisito de progressão).
///
/// Regras de avanço (SPEC §14):
/// Bronze → 500 · Ouro → +800 · Esmeralda → +900 · Diamante → +1000 ·
/// Sublime → +1200 (rank máximo: a barra continua, sem próximo rank).
const rankConfigs = <RankTier, RankConfig>{
  RankTier.bronze: RankConfig(
    tier: RankTier.bronze,
    primary: AppColors.rankBronze,
    secondary: Color(0xFFD9B98A),
    xpStart: 0,
    xpRequired: 500,
  ),
  RankTier.ouro: RankConfig(
    tier: RankTier.ouro,
    primary: AppColors.rankOuro,
    secondary: Color(0xFFFFF3C4),
    xpStart: 500,
    xpRequired: 800,
    glow: 0.10,
  ),
  RankTier.esmeralda: RankConfig(
    tier: RankTier.esmeralda,
    primary: AppColors.rankEsmeralda,
    secondary: Color(0xFFA9F5D8),
    xpStart: 1300,
    xpRequired: 900,
    glow: 0.12,
  ),
  RankTier.diamante: RankConfig(
    tier: RankTier.diamante,
    primary: AppColors.rankDiamante,
    secondary: Color(0xFFBEE9F2),
    xpStart: 2200,
    xpRequired: 1000,
    glow: 0.16,
  ),
  RankTier.sublime: RankConfig(
    tier: RankTier.sublime,
    primary: AppColors.rankSublime,
    secondary: AppColors.rankSublimeVioleta,
    xpStart: 3200,
    xpRequired: 1200,
    ringGradient: AppColors.rankSublimeGradient,
    glow: 0.22,
  ),
};

/// Retorna a configuração visual de um rank.
RankConfig rankConfig(RankTier tier) => rankConfigs[tier]!;

/// Avatar de usuário envolvido pela moldura do rank dele.
///
/// Componente reutilizável: recebe os dados do avatar + o rank e escolhe
/// automaticamente a moldura correta. Usado em Ranking, Projetos, Status,
/// Perfil e na topbar — qualquer lugar onde um perfil aparece.
class RankAvatar extends StatelessWidget {
  const RankAvatar({
    super.key,
    required this.tier,
    required this.name,
    this.url,
    this.size = 40,
    this.showEmblem = false,
  });

  final RankTier tier;
  final String name;
  final String? url;

  /// Diâmetro do avatar (sem contar a moldura).
  final double size;

  /// Exibe um mini-emblema do rank no canto inferior direito.
  final bool showEmblem;

  /// Espessura do anel da moldura.
  double get _ring => math.max(2.0, size * 0.075);

  @override
  Widget build(BuildContext context) {
    final framePad = _ring + size * 0.05;
    final total = size + framePad * 2;

    return SizedBox(
      width: total,
      height: total,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(total),
            painter: _RankFramePainter(rankConfig(tier), _ring),
          ),
          AppAvatar(url: url, name: name, size: size),
          if (showEmblem)
            Positioned(
              right: 0,
              bottom: 0,
              child: _MiniEmblem(tier: tier, size: math.max(12, size * 0.34)),
            ),
        ],
      ),
    );
  }
}

class _MiniEmblem extends StatelessWidget {
  const _MiniEmblem({required this.tier, required this.size});

  final RankTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.bg, width: 1.5),
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: CustomPaint(painter: _EmblemPainter(tier)),
    );
  }
}

/// Mini-emblema simplificado por rank (círculo com símbolo).
class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.tier);

  final RankTier tier;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final cfg = rankConfig(tier);
    final paint = Paint()..color = cfg.primary;

    switch (tier) {
      case RankTier.bronze || RankTier.ouro:
        canvas.drawCircle(c, r * 0.7, paint);
      case RankTier.esmeralda:
        final gem = Path()
          ..moveTo(c.dx, c.dy - r * 0.85)
          ..lineTo(c.dx + r * 0.65, c.dy)
          ..lineTo(c.dx, c.dy + r * 0.85)
          ..lineTo(c.dx - r * 0.65, c.dy)
          ..close();
        canvas.drawPath(gem, paint);
      case RankTier.diamante:
        final d = Path()
          ..moveTo(c.dx, c.dy - r * 0.85)
          ..lineTo(c.dx + r * 0.8, c.dy - r * 0.1)
          ..lineTo(c.dx, c.dy + r * 0.85)
          ..lineTo(c.dx - r * 0.8, c.dy - r * 0.1)
          ..close();
        canvas.drawPath(d, paint);
      case RankTier.sublime:
        final star = Path();
        for (var i = 0; i < 16; i++) {
          final radius = i.isEven ? r * 0.9 : r * 0.42;
          final a = -math.pi / 2 + (math.pi * i / 8);
          final p = c + Offset(radius * math.cos(a), radius * math.sin(a));
          i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        star.close();
        canvas.drawPath(star, paint);
    }
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.tier != tier;
}

/// Pinta a moldura circular do rank ao redor do avatar.
class _RankFramePainter extends CustomPainter {
  _RankFramePainter(this.config, this.ringWidth);

  final RankConfig config;
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - ringWidth / 2;

    // Brilho suave (glow) para ranks altos.
    if (config.glow > 0) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth * 2.2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, ringWidth * 1.6)
          ..color = config.primary.withValues(alpha: config.glow),
      );
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    if (config.ringGradient != null) {
      ring.shader = config.ringGradient!.createShader(Offset.zero & size);
    } else {
      ring.color = config.primary;
    }

    switch (config.tier) {
      case RankTier.bronze:
        // Anel simples e sóbrio.
        canvas.drawCircle(c, r, ring);
        break;

      case RankTier.ouro:
        // Anel duplo: externo grosso + interno fino, com 4 pinos.
        canvas.drawCircle(c, r, ring);
        canvas.drawCircle(
          c,
          r - ringWidth * 1.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, ringWidth * 0.35)
            ..color = config.secondary.withValues(alpha: 0.8),
        );
        _dots(canvas, c, r, 4, ringWidth * 0.42, config.secondary);
        break;

      case RankTier.esmeralda:
        // Anel com 4 gemas losangulares nas diagonais.
        canvas.drawCircle(c, r, ring);
        for (var i = 0; i < 4; i++) {
          final a = math.pi / 4 + i * math.pi / 2;
          final p = c + Offset(r * math.cos(a), r * math.sin(a));
          final s = ringWidth * 0.85;
          final gem = Path()
            ..moveTo(p.dx, p.dy - s)
            ..lineTo(p.dx + s * 0.7, p.dy)
            ..lineTo(p.dx, p.dy + s)
            ..lineTo(p.dx - s * 0.7, p.dy)
            ..close();
          canvas.drawPath(gem, Paint()..color = config.secondary);
        }
        break;

      case RankTier.diamante:
        // Anel em gradiente frio com 4 brilhos (ticks) cardeais.
        ring.shader = LinearGradient(
          colors: [config.primary, config.secondary, config.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size);
        canvas.drawCircle(c, r, ring);
        final tick = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = math.max(1.2, ringWidth * 0.4)
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2;
          final p1 = c + Offset((r - ringWidth) * math.cos(a), (r - ringWidth) * math.sin(a));
          final p2 = c + Offset((r + ringWidth) * math.cos(a), (r + ringWidth) * math.sin(a));
          canvas.drawLine(p1, p2, tick);
        }
        break;

      case RankTier.sublime:
        // Anel em gradiente dourado-violeta com 8 raios de estrela.
        canvas.drawCircle(c, r, ring);
        final ray = Paint()
          ..color = config.primary
          ..strokeWidth = math.max(1.2, ringWidth * 0.4)
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = -math.pi / 2 + i * math.pi / 4;
          final p1 = c + Offset((r + ringWidth * 0.6) * math.cos(a), (r + ringWidth * 0.6) * math.sin(a));
          final p2 = c + Offset((r + ringWidth * 1.5) * math.cos(a), (r + ringWidth * 1.5) * math.sin(a));
          canvas.drawLine(p1, p2, ray);
        }
        _dots(canvas, c, r, 8, ringWidth * 0.3,
            Colors.white.withValues(alpha: 0.85),
            angleOffset: math.pi / 8);
        break;
    }
  }

  void _dots(Canvas canvas, Offset c, double r, int count, double radius,
      Color color,
      {double angleOffset = 0}) {
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      final a = angleOffset + i * 2 * math.pi / count;
      canvas.drawCircle(
          c + Offset(r * math.cos(a), r * math.sin(a)), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RankFramePainter old) =>
      old.config.tier != config.tier || old.ringWidth != ringWidth;
}
