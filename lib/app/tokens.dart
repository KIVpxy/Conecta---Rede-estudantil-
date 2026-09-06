import 'package:flutter/material.dart';

import '../data/models/models.dart';

/// Design tokens do Conecta (dark mode).
/// Fonte única de verdade para cores, raios, espaçamentos e tipografia.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg = Color(0xFF0D1117);
  static const Color bgAlt = Color(0xFF101418);

  // Surfaces
  static const Color surface1 = Color(0xFF151A20);
  static const Color surface2 = Color(0xFF191F26);
  static const Color surface3 = Color(0xFF202730);

  // Borders (suaves — contraste agradável sem peso visual)
  static const Color border = Color(0xFF262E36);
  static const Color borderSoft = Color(0xFF20272E);

  // Texto
  static const Color textPrimary = Color(0xFFF0F3F7);
  static const Color textSecondary = Color(0xFF93A0AE);

  // Accents — lavanda pastel (pedido do usuário: botões em cores pastéis).
  // Como o acento é claro, textos/ícones SOBRE ele usam [onAccent] (grafite
  // escuro) para manter contraste — nunca branco sobre pastel.
  static const Color accent = Color(0xFFB79CFC); // lavanda pastel
  static const Color accentSoft = Color(0xFFD6C7FE); // lavanda bem clara
  static const Color accentMuted = Color(0xFF9C83E8); // lavanda um pouco mais fechada
  static const Color onAccent = Color(0xFF2F2A44); // grafite-violeta escuro
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFC9B6FE), Color(0xFFA98CFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Feedback
  static const Color success = Color(0xFF2FBF8F);
  static const Color danger = Color(0xFFE5534B);

  // Ranks
  static const Color rankBronze = Color(0xFFB08D57);
  static const Color rankOuro = Color(0xFFE3B341);
  static const Color rankEsmeralda = Color(0xFF2FBF8F);
  static const Color rankDiamante = Color(0xFF3FC1D8);
  static const Color rankSublime = Color(0xFFF5D98B);
  static const Color rankSublimeVioleta = Color(0xFF8B5CF6);
  static const LinearGradient rankSublimeGradient = LinearGradient(
    colors: [Color(0xFFF5D98B), Color(0xFFFAFAFA), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ------------------------------------------------------------------
  // Paleta pastel (§12–§13) — centralizada aqui; NÃO espalhar valores
  // de cor por widgets. Sem neon, glow, alta saturação ou cyberpunk.
  // ------------------------------------------------------------------
  static const Color pastelBege = Color(0xFFD8CBB8);
  static const Color pastelCreme = Color(0xFFEDE6D6);
  static const Color pastelAzulClaro = Color(0xFFA9C3DB);
  static const Color pastelVerde = Color(0xFFB5D3BF);
  static const Color pastelRoxoClaro = Color(0xFFC4B2E0);
  static const Color pastelLavanda = Color(0xFFB79CFC);
  static const Color pastelGrafite = Color(0xFF4A5560);
  static const Color pastelNeutro = Color(0xFF9AA5AF);

  // Cores de nome por Elo alto (§17–§18). Apenas Esmeralda, Diamante e
  // Sublime recebem cor; Bronze/Ouro usam a cor normal de texto.
  // Sem neon — tons suaves e elegantes. Usar via UserDisplayName.
  static const Color nameEsmeralda = Color(0xFF7FD4A8); // verde-esmeralda suave
  static const Color nameDiamante = Color(0xFF9FD4E3); // azul-gelo elegante
  static const Color nameSublime = Color(0xFFC9B8F0); // lavanda/violeta suave

  /// Selo [DEV] (§41): pequeno, elegante, pastel. Não substitui o rank.
  static const Color devSeal = pastelAzulClaro;

  /// Detalhes de comunicados escolares (§39): categoria → cor pastel.
  static Color announcementColor(AnnouncementCategory c) => switch (c) {
        AnnouncementCategory.aviso => pastelBege,
        AnnouncementCategory.evento => pastelRoxoClaro,
        AnnouncementCategory.oportunidade => pastelVerde,
        AnnouncementCategory.prova => pastelAzulClaro,
        AnnouncementCategory.olimpiada => rankOuro,
        AnnouncementCategory.geral => pastelNeutro,
      };
}

/// Paleta editorial dos cards de projeto do tipo Texto (SPEC §39).
/// Tons suaves e dessaturados, pensados para combinar com o tema escuro.
class TextCardPalette {
  TextCardPalette._();

  static const Color marrom = Color(0xFF8C6D5C); // terroso/café suave
  static const Color azul = Color(0xFF5E7FA0); // azul levemente dessaturado
  static const Color vinho = Color(0xFF92505F); // vinho elegante
  static const Color amarelo = Color(0xFFB3924A); // mostarda suave

  static const List<Color> all = [marrom, azul, vinho, amarelo];

  /// Cor de um tom editorial (enum do modelo → cor da paleta).
  static Color of(TextCardTone tone) => switch (tone) {
        TextCardTone.marrom => marrom,
        TextCardTone.azul => azul,
        TextCardTone.vinho => vinho,
        TextCardTone.amarelo => amarelo,
      };

  static String labelOf(Color c) => switch (c.toARGB32()) {
        0xFF8C6D5C => 'Marrom',
        0xFF5E7FA0 => 'Azul',
        0xFF92505F => 'Vinho',
        0xFFB3924A => 'Amarelo',
        _ => 'Personalizada',
      };
}

class AppRadii {
  AppRadii._();

  static const double card = 16;
  static const double control = 12; // botões e inputs
  static const double pill = 999;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius controlRadius =
      BorderRadius.all(Radius.circular(control));
  static const BorderRadius pillRadius =
      BorderRadius.all(Radius.circular(pill));
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppBreakpoints {
  AppBreakpoints._();

  static const double tablet = 768;
  static const double desktop = 1200;

  static bool isMobile(double w) => w < tablet;
  static bool isTablet(double w) => w >= tablet && w < desktop;
  static bool isDesktop(double w) => w >= desktop;
}
