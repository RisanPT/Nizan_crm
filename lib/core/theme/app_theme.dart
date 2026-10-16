import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'crm_theme.dart';

class AppTheme {
  // Palette aligned to the approved HRMS design file (HRMS_Design.html):
  // warm "ground" page background, white card surfaces, warm hairline borders,
  // warm muted text and the brand maroon + gold. This gives the layered,
  // warm look of the design instead of a flat pure-white UI.
  static const _backgroundColor = Color(0xFFF5F3EF); // --ground
  static const _foregroundColor = Color(0xFF601A29); // --maroon (brand)
  static const _inkColor = Color(0xFF1C1A19); // --ink (headings/body)
  static const _borderColor = Color(0xFFECE6DE); // --line
  static const _inputColor = Color(0xFFFBFAF7);
  static const _primaryColor = Color(0xFF601A29); // --maroon
  static const _secondaryColor = Color(0xFFF2EDE4);
  static const _accentColor = Color(0xFFC9A66B); // --gold
  static const _surfaceColor = Color(0xFFFFFFFF); // --surface
  static const _textPrimaryColor = _inkColor;
  static const _textSecondaryColor = Color(0xFF8C837B); // --muted
  static const _successColor = Color(0xFF2E7D4F); // --good
  static const _warningColor = Color(0xFFA9781B); // --warn
  static const _destructiveColor = Color(0xFFB23B3B); // --bad
  static const _sidebarColor = Color(0xFF320D15); // --sidebar
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
        onSecondary: _inkColor,
        onSurface: _inkColor,
        error: _destructiveColor,
        onError: _surfaceColor,
      ),
      // Body in Inter, headings in Plus Jakarta Sans (the design's display
      // face) for the HRMS typographic character.
      textTheme: GoogleFonts.interTextTheme()
          .apply(bodyColor: _textPrimaryColor, displayColor: _textPrimaryColor)
          .copyWith(
            displayLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: _inkColor),
            displayMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: _inkColor),
            displaySmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _inkColor),
            headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _inkColor),
            headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _inkColor),
            headlineSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _inkColor),
            titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _inkColor),
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        elevation: 3,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: _primaryColor.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _primaryColor : _textSecondaryColor,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? _primaryColor : _textSecondaryColor,
          );
        }),
      ),
    );
  }
}