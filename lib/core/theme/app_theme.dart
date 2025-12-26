import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tenant/tenant.dart';

class AppThemeData {
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  AppThemeData({
    required this.lightTheme,
    required this.darkTheme,
  });

  static AppThemeData fromBranding(TenantBranding? branding) {
    final primaryColor = branding?.primaryColor != null
        ? _parseColor(branding!.primaryColor!)
        : Colors.blue;

    final secondaryColor = branding?.secondaryColor != null
        ? _parseColor(branding!.secondaryColor!)
        : Colors.blueAccent;

    final accentColor = branding?.accentColor != null
        ? _parseColor(branding!.accentColor!)
        : Colors.amber;

    final textTheme = branding?.fontFamily != null
        ? _getTextThemeForFont(branding!.fontFamily!)
        : null;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
    );

    final lightTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: colorScheme.copyWith(
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );

    return AppThemeData(
      lightTheme: lightTheme,
      darkTheme: darkTheme,
    );
  }

  static Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (e) {
      // Invalid color format
    }
    return Colors.blue;
  }

  static TextTheme? _getTextThemeForFont(String fontFamily) {
    try {
      // Map font names to GoogleFonts methods
      switch (fontFamily.toLowerCase()) {
        case 'roboto':
          return GoogleFonts.robotoTextTheme();
        case 'lato':
          return GoogleFonts.latoTextTheme();
        case 'opensans':
        case 'open sans':
          return GoogleFonts.openSansTextTheme();
        case 'montserrat':
          return GoogleFonts.montserratTextTheme();
        case 'poppins':
          return GoogleFonts.poppinsTextTheme();
        default:
          // Try to use the font name directly, fallback to Roboto if it fails
          try {
            return GoogleFonts.getTextTheme(fontFamily);
          } catch (e) {
            return GoogleFonts.robotoTextTheme();
          }
      }
    } catch (e) {
      return null;
    }
  }
}

final themeProvider = StateProvider<AppThemeData>((ref) {
  return AppThemeData.fromBranding(null);
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
