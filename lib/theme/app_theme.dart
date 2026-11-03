import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors (Matching Web Aesthetics)
  static const Color brandLight = Color(0xFF17433B);
  static const Color brandDark = Color(0xFF0B2A24);

  static const Color bgLight = Color(0xFFEEF3F0);
  static const Color bgDark = Color(0xFF0E1714);

  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF18241F);

  static const Color inkLight = Color(0xFF14231F);
  static const Color inkDark = Color(0xFFE9F1ED);

  static const Color mutedLight = Color(0xFF6B7280);
  static const Color mutedDark = Color(0xFF9CA3AF);

  static const Color lineLight = Color(0xFFDDE5E0);
  static const Color lineDark = Color(0xFF273831);

  // Performance / Evaluation Colors
  static const Color posLight = Color(0xFF1F8A5B);
  static const Color posDark = Color(0xFF4CC58C);

  static const Color negLight = Color(0xFFD4533B);
  static const Color negDark = Color(0xFFEF7C66);

  static const Color accent = Color(0xFFF2C230); // Gold / Live period highlight

  // Light Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: brandLight,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: brandLight,
        onPrimary: Colors.white,
        primaryContainer: brandLight,
        onPrimaryContainer: Colors.white,
        secondary: posLight,
        onSecondary: Colors.white,
        secondaryContainer: brandLight,
        onSecondaryContainer: Colors.white,
        tertiary: accent,
        onTertiary: brandDark,
        surface: cardLight,
        onSurface: inkLight,
        error: negLight,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: inkLight,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: inkLight),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lineLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandLight, width: 2),
        ),
        labelStyle: const TextStyle(fontSize: 13, color: mutedLight, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(fontSize: 13, color: mutedLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandLight,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return brandLight;
            }
            return cardLight;
          }),
          foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.white;
            }
            return inkLight;
          }),
          iconColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.white;
            }
            return inkLight;
          }),
          side: MaterialStateProperty.all(const BorderSide(color: lineLight)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardLight,
        selectedColor: brandLight,
        secondarySelectedColor: brandLight,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: inkLight),
        secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
        side: const BorderSide(color: lineLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardLight,
        selectedItemColor: brandLight,
        unselectedItemColor: mutedLight,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Dark Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: brandDark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: brandDark,
        primaryContainer: accent,
        onPrimaryContainer: brandDark,
        secondary: posDark,
        onSecondary: brandDark,
        secondaryContainer: accent,
        onSecondaryContainer: brandDark,
        tertiary: accent,
        onTertiary: brandDark,
        surface: cardDark,
        onSurface: inkDark,
        error: negDark,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: inkDark,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: inkDark),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lineDark, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        labelStyle: const TextStyle(fontSize: 13, color: mutedDark, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(fontSize: 13, color: mutedDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: brandDark,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return accent;
            }
            return cardDark;
          }),
          foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return brandDark;
            }
            return inkDark;
          }),
          iconColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return brandDark;
            }
            return inkDark;
          }),
          side: MaterialStateProperty.all(const BorderSide(color: lineDark)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardDark,
        selectedColor: accent,
        secondarySelectedColor: accent,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: inkDark),
        secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: brandDark),
        side: const BorderSide(color: lineDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: accent,
        unselectedItemColor: mutedDark,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
