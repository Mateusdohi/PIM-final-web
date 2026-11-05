import 'package:flutter/material.dart';

import 'team_theme.dart';

/// Paleta do app web (redesign.css): fundo claro, menu azul-marinho e verde de destaque.
class AppColors {
  AppColors._();
  static const bgMain = Color(0xFFF4F6F9);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgInput = Color(0xFFFFFFFF);
  static const bgItem = Color(0xFFF3F5F8);
  static const border = Color(0xFFD5DBE4);
  static const borderSoft = Color(0xFFE3E8EF);
  static const muted = Color(0xFF5B6573);
  static const text = Color(0xFF14213D);
  static const navy = Color(0xFF0F1F3A);
  static const brand = Color(0xFF16803F);
  static const brandDark = Color(0xFF116A34);
  static const brandLight = Color(0xFF3ECF7A);
  static const neonCyan = brand;
  static const danger = Color(0xFFB42318);
  static const warning = Color(0xFFE0A800);
}

class AppTheme {
  AppTheme._();

  /// Tema claro (mesma identidade do app web). O verde de destaque é fixo, como no web;
  /// as cores do time continuam na tela de boas-vindas ([TeamTheme]).
  static ThemeData forTeam(String? slug, {bool highContrast = false}) {
    TeamTheme.of(slug); // mantém a assinatura; o time só muda a tela de boas-vindas
    final base = _build(highContrast);
    return base;
  }

  static ThemeData _build(bool highContrast) {
    final scheme = ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.navy,
      surface: AppColors.bgCard,
      onSurface: highContrast ? Colors.black : AppColors.text,
      error: AppColors.danger,
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: highContrast ? Colors.black : AppColors.border, width: highContrast ? 1.5 : 1),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: highContrast ? Colors.white : AppColors.bgMain,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy, foregroundColor: Colors.white, elevation: 0, centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder, enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.brand, width: 1.5)),
        errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.danger)),
        hintStyle: TextStyle(color: highContrast ? const Color(0xFF3A3F47) : const Color(0xFF8A94A3)),
        labelStyle: TextStyle(color: highContrast ? Colors.black : AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.brand, width: 1.5),
          foregroundColor: AppColors.brand,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.brand)),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.brand,
        checkmarkColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.text),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: AppColors.text,
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xB3FFFFFF),
        indicatorColor: AppColors.brandLight,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
      cardTheme: CardThemeData(color: AppColors.bgCard, elevation: 0),
      dividerColor: AppColors.borderSoft,
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
