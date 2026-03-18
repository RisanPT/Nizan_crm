import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'crm_theme.dart';

class AppTheme {
  // Main semantic colors derived from screenshots
  static const _primaryColor = Color(0xFF14213D); // Dark blue sidebar
  static const _secondaryColor = Color(0xFFFDE68A); // Gold/yellow accents
  static const _backgroundColor = Color(0xFFF3F4F6); // Light gray background
  static const _surfaceColor = Colors.white;
  static const _textPrimaryColor = Color(0xFF111827);
  static const _textSecondaryColor = Color(0xFF6B7280);
  static const _borderColor = Color(0xFFE5E7EB);
  static const _successColor = Color(0xFF10B981); // Green for Confirmed
  static const _warningColor = Color(0xFFF59E0B); // Amber for Pending

  static final crmThemeExtension = CrmTheme(
    primary: _primaryColor,
    secondary: _secondaryColor,
    background: _backgroundColor,
    surface: _surfaceColor,
    textPrimary: _textPrimaryColor,
    textSecondary: _textSecondaryColor,
    border: _borderColor,
    success: _successColor,
    warning: _warningColor,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        primary: _primaryColor,
        secondary: _secondaryColor,
        surface: _surfaceColor,
        background: _backgroundColor,
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
        color: Colors.grey.shade500,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _borderColor),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: _textSecondaryColor,
        textColor: _textPrimaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
