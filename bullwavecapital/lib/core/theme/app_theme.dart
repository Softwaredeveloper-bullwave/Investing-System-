import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'typography.dart';
import 'app_theme_extension.dart';
import '../constants/dimensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => _buildTheme(AppThemeExtension.dark);

  static ThemeData get lightTheme => _buildTheme(AppThemeExtension.light);

  static ThemeData _buildTheme(AppThemeExtension colors) {
    final isDark = colors == AppThemeExtension.dark;

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.accentOrange,
      onSecondary: colors.onPrimary,
      error: colors.negative,
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      textTheme: AppTypography.forBrightness(colors),
      fontFamily: GoogleFonts.inter().fontFamily,
      extensions: [colors],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.sectionTitle(colors),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.primaryDark,
        textColor: colors.textPrimary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 13,
          color: colors.textSecondary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return TextStyle(color: colors.textMuted, fontSize: 12);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? colors.primary : Colors.black,
          foregroundColor: isDark ? colors.onPrimary : Colors.white,
          minimumSize: const Size(0, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(0, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: BorderSide(
            color: isDark ? colors.border : colors.textPrimary.withValues(alpha: 0.15),
            width: 1,
          ),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMd,
          vertical: AppDimensions.paddingMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colors.negative),
        ),
        hintStyle: TextStyle(color: colors.textMuted),
        labelStyle: TextStyle(color: colors.textSecondary),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colors.onPrimary),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceSecondary,
        selectedColor: colors.primary.withValues(alpha: 0.22),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surface,
        contentTextStyle: GoogleFonts.inter(color: colors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: colors.primary.withValues(alpha: 0.08),
    );
  }
}
