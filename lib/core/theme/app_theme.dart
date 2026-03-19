import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'crm_theme.dart';

class AppTheme {
  static const _backgroundColor = Color(0xFFFFFFFF);
  static const _foregroundColor = Color(0xFF0B1B3B);
  static const _borderColor = Color(0x14000000);
  static const _inputColor = Color(0xFFF6F7F9);
  static const _primaryColor = Color(0xFF0B1B3B);
  static const _secondaryColor = Color(0xFFF2EDE4);
  static const _accentColor = Color(0xFFC9A66B);
  static const _surfaceColor = Color(0xFFFFFFFF);
  static const _textPrimaryColor = _foregroundColor;
  static const _textSecondaryColor = Color(0xFF7B8694);
  static const _successColor = Color(0xFF0B5B37);
  static const _warningColor = Color(0xFF6A4B00);
  static const _destructiveColor = Color(0xFF7B1B2A);
  static const _sidebarColor = Color(0xFF08142A);
  static const _sidebarForegroundColor = Color(0xFFFFFFFF);

  static final crmThemeExtension = CrmTheme(
    primary: _primaryColor,
    secondary: _secondaryColor,
    accent: _accentColor,
    background: _backgroundColor,
    surface: _surfaceColor,
    input: _inputColor,
    textPrimary: _textPrimaryColor,
    textSecondary: _textSecondaryColor,
    border: _borderColor,
    success: _successColor,
    warning: _warningColor,
    destructive: _destructiveColor,
    sidebar: _sidebarColor,
    sidebarForeground: _sidebarForegroundColor,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: _primaryColor,
        secondary: _secondaryColor,
        surface: _surfaceColor,
        onPrimary: _surfaceColor,
        onSecondary: _foregroundColor,
        onSurface: _foregroundColor,
        error: _destructiveColor,
        onError: _surfaceColor,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: _textPrimaryColor,
        displayColor: _textPrimaryColor,
      ),
      extensions: [crmThemeExtension],
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceColor,
        foregroundColor: _textPrimaryColor,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _textPrimaryColor),
      ),
      cardTheme: CardThemeData(
        color: _surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _borderColor),
        ),
      ),
      dividerColor: _borderColor,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceColor,
        hintStyle: const TextStyle(color: _textSecondaryColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primaryColor,
          foregroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _foregroundColor,
          backgroundColor: _surfaceColor,
          side: const BorderSide(color: _borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _primaryColor),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: _textSecondaryColor,
        textColor: _textPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
