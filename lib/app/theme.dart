import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Tema dark do Conecta.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    // Montserrat global (§14) — hierarquia de pesos:
    //  título principal Bold/ExtraBold · título de card SemiBold/Bold ·
    //  nome de usuário SemiBold · texto comum Regular/Medium ·
    //  nome de rank Bold/ExtraBold (ver RankBadge).
    final montserrat = GoogleFonts.montserratTextTheme(base.textTheme);
    final textTheme = montserrat
        .copyWith(
          headlineLarge: montserrat.headlineLarge
              ?.copyWith(fontWeight: FontWeight.w800),
          headlineMedium: montserrat.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          titleLarge:
              montserrat.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium:
              montserrat.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall:
              montserrat.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge:
              montserrat.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
          bodyMedium:
              montserrat.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
          bodySmall:
              montserrat.bodySmall?.copyWith(fontWeight: FontWeight.w400),
          labelLarge:
              montserrat.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.accentSoft,
        onSecondary: AppColors.onAccent,
        surface: AppColors.surface1,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      dividerColor: AppColors.border,
      cardTheme: CardThemeData(
        color: AppColors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surface3,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.accent),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
