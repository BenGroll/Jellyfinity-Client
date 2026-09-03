import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_tokens.dart';
import 'palette.dart';

/// Builds the [ThemeData] Jellyfinity hands to `MaterialApp`.
///
/// Two jobs:
/// 1. attach an [AppTokens] extension — the app's real styling source, read
///    everywhere via `context.tokens`;
/// 2. derive a matching Material [ColorScheme]/[TextTheme] from the same
///    palette, so the Material widgets we do use (text fields, switches,
///    the bottom nav, dialogs) stay visually consistent with our tokens
///    instead of falling back to Material defaults.
abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark, Palette.dark);

  static ThemeData light() => _build(Brightness.light, Palette.light);

  static AppTokens tokensFor(Brightness brightness) =>
      _tokens(brightness == Brightness.dark ? Palette.dark : Palette.light);

  static AppTokens _tokens(AppColors colors) {
    return AppTokens(
      colors: colors,
      spacing: AppSpacing.standard,
      radii: AppRadii.standard,
      typography: AppTypography.standard,
      elevation: AppElevation.standard(shadowColor: const Color(0xFF000000)),
      motion: AppMotion.standard,
    );
  }

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final tokens = _tokens(colors);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          surface: colors.surface,
          onSurface: colors.onSurface,
          primary: colors.accent,
          onPrimary: colors.onAccent,
          error: colors.danger,
        );

    final t = tokens.typography;
    final textTheme = TextTheme(
      displayLarge: t.displayLarge,
      headlineLarge: t.headlineLarge,
      titleLarge: t.titleLarge,
      titleMedium: t.titleMedium,
      bodyLarge: t.bodyLarge,
      bodyMedium: t.bodyMedium,
      labelLarge: t.label,
      bodySmall: t.caption,
    ).apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      dividerColor: colors.border,
      splashFactory: InkSparkle.splashFactory,
      extensions: [tokens],
    );
  }
}
