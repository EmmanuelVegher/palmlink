import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Theme Palette
  static const Color lightBackground = Color(0xFFF8FAFC); // Clean slate 50
  static const Color lightCard = Color(0xFFFFFFFF);       // Pure white card
  static const Color primaryEmerald = Color(0xFF059669);  // Vibrant medical emerald
  static const Color secondaryCyan = Color(0xFF0891B2);   // Clean medical cyan
  static const Color accentBlue = Color(0xFF2563EB);      // Scanner blue accent
  static const Color amberWarning = Color(0xFFD97706);    // Amber warning
  static const Color errorRed = Color(0xFFDC2626);        // Warning red
  static const Color textDark = Color(0xFF0F172A);        // Deep slate text
  static const Color textMuted = Color(0xFF64748B);       // Secondary text
  static const Color borderLight = Color(0xFFE2E8F0);     // Subtle border line
  static const Color inputFill = Color(0xFFF1F5F9);       // Soft input fill

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryEmerald,
        secondary: secondaryCyan,
        surface: lightCard,
        error: errorRed,
        onPrimary: Colors.white,
        onSurface: textDark,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.light().textTheme.copyWith(
              displayLarge: const TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 28),
              titleLarge: const TextStyle(color: textDark, fontWeight: FontWeight.w600, fontSize: 20),
              bodyLarge: const TextStyle(color: textDark, fontSize: 16),
              bodyMedium: const TextStyle(color: textMuted, fontSize: 14),
            ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightCard,
        elevation: 1,
        shadowColor: Colors.black12,
        centerTitle: true,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryEmerald, width: 2),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryEmerald,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}
