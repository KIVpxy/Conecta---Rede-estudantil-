import '../../data/models/models.dart';
import '../widgets/rank_frame.dart';

/// Regras de progressão (centralizadas).
///
/// - XP total: acumulativo, nunca é removido.
/// - Nível: cada nível custa 200 XP (independente de rank).
/// - Rank: por limiar de XP total (ver [rankConfigs]):
///   Bronze 0–499 · Ouro 500–1299 · Esmeralda 1300–2199 ·
///   Diamante 2200–3199 · Sublime 3200+.
///   A barra de progresso é por rank: reinicia a cada promoção,
///   enquanto o XP total continua acumulando para sempre.
class LevelMath {
  LevelMath._();

  static const int xpPerLevel = 200;

  /// XP concedido a quem REALIZA uma avaliação válida (primeira avaliação
  /// daquele usuário naquele projeto — editar não concede de novo).
  static const int xpPerEvaluation = 15;

  static int levelFor(int xp) => xp ~/ xpPerLevel + 1;

  static int xpInCurrentLevel(int xp) => xp % xpPerLevel;

  static int xpToNextLevel(int xp) => xpPerLevel - xpInCurrentLevel(xp);

  static double levelProgress(int xp) => xpInCurrentLevel(xp) / xpPerLevel;

  /// XP ganho por um projeto dado sua avaliação média (1–10).
  static int xpForRatingAvg(double avg) {
    if (avg >= 9) return 200;
    if (avg >= 6) return 50;
    return 30;
  }

  // ---------- Rank por limiar de XP ----------

  static const List<RankTier> _ordered = [
    RankTier.bronze,
    RankTier.ouro,
    RankTier.esmeralda,
    RankTier.diamante,
    RankTier.sublime,
  ];

  /// Rank de um usuário dado seu XP total acumulado.
  static RankTier rankForXp(int xpTotal) {
    var tier = RankTier.bronze;
    for (final t in _ordered) {
      if (xpTotal >= rankConfigs[t]!.xpStart) tier = t;
    }
    return tier;
  }

  /// XP já percorrido dentro do rank atual.
  static int xpIntoRank(int xpTotal) =>
      xpTotal - rankConfigs[rankForXp(xpTotal)]!.xpStart;

  /// XP necessário dentro do rank atual para avançar.
  static int xpRequiredInRank(int xpTotal) =>
      rankConfigs[rankForXp(xpTotal)]!.xpRequired;

  /// Progresso (0..1) dentro do rank atual.
  static double rankProgress(int xpTotal) {
    final required = xpRequiredInRank(xpTotal);
    if (required <= 0) return 1;
    return (xpIntoRank(xpTotal) / required).clamp(0.0, 1.0);
  }

  /// Próximo rank, ou null se já está no máximo (Sublime).
  static RankTier? nextRank(RankTier tier) {
    final i = _ordered.indexOf(tier);
    return i < _ordered.length - 1 ? _ordered[i + 1] : null;
  }
}
