import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette aligned with bolman_web_dashboard (tailwind `bolman.*`).
class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const deepPurple = Color(0xFF5146E5);
  static const accent = Color(0xFFB8B0FF);
  static const softAccent = Color(0xFFECEBFF);

  static const lightBg = Color(0xFFF8FAFC);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF1F5F9);
  static const lightTint = Color(0xFFECEBFF);
  static const borderLight = Color(0xFFE2E8F0);
  static const borderLightSoft = Color(0xFFE7E8F2);

  static const darkBg = Color(0xFF12131A);
  static const darkCard = Color(0xFF1B1D27);
  static const surfaceDark = Color(0xFF232634);
  static const borderDark = Color(0xFF2B3040);

  static const onDark = Color(0xFFE2E8F0);
  static const onLight = Color(0xFF0F172A);
  static const mutedDark = Color(0xFF94A3B8);
  static const mutedLight = Color(0xFF64748B);

  static const success = Color(0xFF0284C7);
  static const warning = Color(0xFFEAB308);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);

  static const seatAvailable = Color(0xFFECEBFF);
  static const seatAvailableText = Color(0xFF5146E5);
  static const seatReserved = Color(0xFFFEE2E2);
  static const seatReservedText = Color(0xFFDC2626);
  static const seatLocked = Color(0xFFFEF3C7);
  static const seatLockedText = Color(0xFFD97706);
  static const seatInactive = Color(0xFFCBD5E1);

  static const shimmerBaseDark = surfaceDark;
  static const shimmerHighlightDark = borderDark;
  static const shimmerBaseLight = Color(0xFFE5E7EB);
  static const shimmerHighlightLight = Color(0xFFF3F4F6);
}

class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppRadius {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 28.0;
  static const pill = 100.0;
}

class AppShadows {
  static List<BoxShadow> subtle(Color color) => [
        BoxShadow(color: color.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0, 4)),
      ];

  static List<BoxShadow> medium(Color color) => [
        BoxShadow(color: color.withValues(alpha: .10), blurRadius: 18, offset: const Offset(0, 8)),
      ];

  static List<BoxShadow> elevated(Color color) => [
        BoxShadow(color: color.withValues(alpha: .16), blurRadius: 26, offset: const Offset(0, 12)),
      ];
}

class AppGradients {
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.deepPurple],
  );

  static const offer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.deepPurple, AppColors.primary],
  );

  static const wallet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.deepPurple, AppColors.primary],
  );
}

class AppTheme {
  static ThemeData forLocale(String locale, Brightness brightness) {
    final base = _baseTheme(brightness);
    final textTheme = locale == 'ar'
        ? GoogleFonts.tajawalTextTheme(base.textTheme)
        : GoogleFonts.interTextTheme(base.textTheme);
    final enhancedText = textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, fontSize: 24),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 20),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 17),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 15),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: textTheme.bodySmall?.copyWith(fontSize: 12),
      labelSmall: textTheme.labelSmall?.copyWith(fontSize: 11),
    );
    return base.copyWith(
      textTheme: enhancedText,
      primaryTextTheme: enhancedText,
      appBarTheme: base.appBarTheme.copyWith(titleTextStyle: enhancedText.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
    );
  }

  static ThemeData get light => forLocale('ar', Brightness.light);
  static ThemeData get dark => forLocale('ar', Brightness.dark);

  static ColorScheme _colorScheme(Brightness b) {
    final dark = b == Brightness.dark;
    return ColorScheme(
      brightness: b,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: dark ? AppColors.primary.withValues(alpha: .18) : AppColors.lightTint,
      onPrimaryContainer: dark ? const Color(0xFFE0DEFF) : AppColors.deepPurple,
      secondary: AppColors.accent,
      onSecondary: AppColors.deepPurple,
      secondaryContainer: dark ? AppColors.accent.withValues(alpha: .14) : AppColors.softAccent,
      onSecondaryContainer: AppColors.deepPurple,
      tertiary: AppColors.deepPurple,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: dark ? AppColors.darkBg : AppColors.lightBg,
      onSurface: dark ? AppColors.onDark : AppColors.onLight,
      onSurfaceVariant: dark ? AppColors.mutedDark : AppColors.mutedLight,
      outline: dark ? AppColors.borderDark : AppColors.borderLight,
      outlineVariant: dark ? AppColors.surfaceDark : AppColors.borderLight,
      surfaceContainerHighest: dark ? AppColors.surfaceDark : AppColors.lightSurface,
    );
  }

  static ThemeData _baseTheme(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = _colorScheme(b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: scheme.outline,
      cardTheme: CardThemeData(
        color: dark ? AppColors.darkCard : AppColors.lightCard,
        elevation: 0,
        shadowColor: AppColors.primary.withValues(alpha: .10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.primary.withValues(alpha: .12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.darkCard : AppColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: dark ? AppColors.borderDark : AppColors.borderLightSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: dark ? AppColors.borderDark : AppColors.borderLightSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}
