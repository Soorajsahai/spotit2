import 'package:flutter/material.dart';

class AppColors {
  // Frozen Lake Palette
  // Base palette colors
  static const Color frozenSlate = Color(0xFF6D8196); // #6D8196 - Slate gray
  static const Color frozenIcyBlue = Color(0xFFADD8E6); // #ADD8E6 - Icy blue
  static const Color frozenSnow = Color(0xFFFFFAFA); // #FFFAFA - Snow white
  static const Color frozenNavy = Color(0xFF000080); // #000080 - Deep navy

  // Backwards-compatible aliases (used across the app)
  static const Color skyBlue = frozenIcyBlue;
  static const Color aquaBlue = frozenNavy;
  static const Color freshGreen = frozenSlate;
  static const Color mintGreen = frozenSnow;
  
  // Derived colors for UI elements
  static const Color charcoal = frozenSlate;          // Text color, mapped to slate gray
  static const Color lightGray = Color(0xFFE5E9F2);   // Soft neutral background
  static const Color white = Colors.white;            // Pure white
  static const Color shadowColor = Color(0x1A000000); // Shadow color
  
  // Primary colors based on Frozen Lake palette
  static const Color primary = frozenNavy;            // Main primary color
  static const Color primaryLight = frozenIcyBlue;    // Light variant
  static const Color accent = frozenSlate;            // Accent color
  static const Color accentLight = frozenIcyBlue;     // Light accent variant
  static const Color background = frozenSnow;         // App background

  // Dark mode colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  
  // Helper methods for theme-aware colors
  static Color getGrey(BuildContext context, int shade) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      // Dark mode grey mapping
      switch (shade) {
        case 50: return const Color(0xFF2C2C2C);
        case 100: return const Color(0xFF3C3C3C);
        case 200: return const Color(0xFF4A4A4A);
        case 300: return const Color(0xFF5A5A5A);
        case 400: return const Color(0xFF6A6A6A);
        case 500: return const Color(0xFF9E9E9E);
        case 600: return const Color(0xFFBDBDBD);
        case 700: return const Color(0xFFE0E0E0);
        case 800: return const Color(0xFFEEEEEE);
        case 900: return const Color(0xFFF5F5F5);
        default: return Colors.grey;
      }
    } else {
      // Light mode - use standard greys
      return Colors.grey[shade] ?? Colors.grey;
    }
  }
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    useMaterial3: true,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.aquaBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.aquaBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.skyBlue, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.skyBlue, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.aquaBlue, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: AppColors.shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      color: AppColors.white,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.charcoal,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: AppColors.charcoal,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      bodyLarge: TextStyle(
        color: AppColors.charcoal,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        color: AppColors.charcoal,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
  
  // Helper method for card shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];
  
  // Helper method for elevated shadows
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 30,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
  ];

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.primary,
    useMaterial3: true,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.aquaBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: const Color(0xFF5A5A5A), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: const Color(0xFF5A5A5A), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: const BorderSide(color: AppColors.aquaBlue, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: TextStyle(color: const Color(0xFF9E9E9E)),
      labelStyle: TextStyle(color: const Color(0xFFBDBDBD)),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      color: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      bodyLarge: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        color: Color(0xFFE0E0E0),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: Color(0xFFBDBDBD),
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),

    dividerColor: const Color(0xFF4A4A4A),
    colorScheme: ColorScheme.dark(
      primary: AppColors.aquaBlue,
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
      onSurfaceVariant: Color(0xFFE0E0E0),
      onPrimary: Colors.white,
      onSecondary: Color(0xFFE0E0E0),
      outline: Color(0xFF5A5A5A),
      outlineVariant: Color(0xFF4A4A4A),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.darkSurface,
    ),
  );
}
