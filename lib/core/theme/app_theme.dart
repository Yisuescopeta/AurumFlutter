import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../design_system/app_tokens.dart';

class AppTheme {
  static const Color navyBlue = AppTokens.navy800;
  static const Color gold = AppTokens.gold500;
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = AppTokens.slate600;
  static const Color lightGrey = AppTokens.cream050;
  static const Color error = AppTokens.error;
  static const Color success = AppTokens.success;

  static ThemeData get lightTheme {
    final base = ThemeData(useMaterial3: true);
    final playfair = GoogleFonts.playfairDisplayTextTheme(base.textTheme);
    final inter = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: navyBlue,
        primary: navyBlue,
        secondary: gold,
        surface: Colors.white,
        error: error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppTokens.cream050,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: navyBlue,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: navyBlue),
        titleTextStyle: playfair.titleLarge?.copyWith(
          color: navyBlue,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
      ),
      textTheme: inter.copyWith(
        displayLarge: playfair.displayLarge?.copyWith(
          color: navyBlue,
          fontWeight: FontWeight.w700,
          fontSize: 40,
        ),
        displayMedium: playfair.displayMedium?.copyWith(
          color: navyBlue,
          fontWeight: FontWeight.w700,
          fontSize: 34,
        ),
        headlineMedium: playfair.headlineMedium?.copyWith(
          color: navyBlue,
          fontWeight: FontWeight.w700,
          fontSize: 26,
        ),
        titleLarge: playfair.titleLarge?.copyWith(
          color: navyBlue,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        bodyLarge: inter.bodyLarge?.copyWith(color: AppTokens.navy700, height: 1.45),
        bodyMedium: inter.bodyMedium?.copyWith(color: AppTokens.slate600, height: 1.4),
        labelLarge: inter.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: gold.withOpacity(0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => inter.labelSmall?.copyWith(
            color: states.contains(MaterialState.selected) ? navyBlue : AppTokens.slate600,
            fontWeight: states.contains(MaterialState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppTokens.slate100),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: navyBlue,
        side: const BorderSide(color: AppTokens.slate300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        labelStyle: inter.labelMedium?.copyWith(color: navyBlue),
        secondaryLabelStyle: inter.labelMedium?.copyWith(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          textStyle: inter.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navyBlue,
          side: const BorderSide(color: AppTokens.slate300),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          textStyle: inter.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navyBlue,
          textStyle: inter.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: inter.bodyMedium?.copyWith(color: AppTokens.slate600.withOpacity(0.9)),
        labelStyle: inter.bodyMedium?.copyWith(color: AppTokens.slate600),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: AppTokens.slate100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: AppTokens.slate100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: navyBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: error, width: 1.4),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.slate100,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navyBlue,
        contentTextStyle: inter.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        iconColor: navyBlue,
        titleTextStyle: inter.titleMedium?.copyWith(
          color: navyBlue,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: inter.bodyMedium?.copyWith(color: AppTokens.slate600),
      ),
    );
  }
}
