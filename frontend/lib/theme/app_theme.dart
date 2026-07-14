import 'package:flutter/material.dart';

import 'app_tokens.dart';

ThemeData buildAppTheme() {
  const brandColor = Color(0xFFEF5B3F);
  const backgroundColor = Color(0xFFFFF9F4);
  const inkColor = Color(0xFF1E1C1A);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: Brightness.light,
    primary: brandColor,
    surface: backgroundColor,
  );
  final textTheme = ThemeData.light().textTheme.apply(
    bodyColor: inkColor,
    displayColor: inkColor,
    fontFamily: 'Hiragino Kaku Gothic ProN',
    fontFamilyFallback: const [
      'Hiragino Sans',
      'Yu Gothic',
      'YuGothic',
      'Meiryo',
      'Noto Sans CJK JP',
      'Noto Sans JP',
      'sans-serif',
    ],
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: backgroundColor,
    textTheme: textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        fontSize: 54,
        fontWeight: FontWeight.w800,
        height: 1.16,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.18,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.65),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.55),
      bodySmall: textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: inkColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: AppSpacing.small,
      toolbarHeight: AppSizes.toolbarHeight,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        color: inkColor,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size.fromHeight(AppSizes.primaryButtonHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppSpacing.xLarge,
            vertical: AppSpacing.medium,
          ),
        ),
        textStyle: WidgetStatePropertyAll(
          textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.onPrimary.withValues(alpha: 0.16);
          }
          if (states.contains(WidgetState.hovered)) {
            return colorScheme.onPrimary.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.focused)) {
            return colorScheme.onPrimary.withValues(alpha: 0.12);
          }
          return null;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.secondaryButtonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.medium,
        ),
        foregroundColor: inkColor,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppSizes.touchTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.primary,
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.regular,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.medium,
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.fixed,
      backgroundColor: inkColor,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
    ),
    focusColor: brandColor.withValues(alpha: 0.12),
    hoverColor: brandColor.withValues(alpha: 0.06),
  );
}
