import 'package:flutter/material.dart';

import '../tokens/AppColors.dart';
import '../tokens/AppElevation.dart';
import '../tokens/AppMotion.dart';
import '../tokens/AppRadii.dart';
import '../tokens/AppSpacing.dart';
import '../tokens/AppTypography.dart';
import 'AppTokens.dart';
import 'Palette.dart';

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
  static ThemeData dark({bool television = false}) =>
      _build(Brightness.dark, Palette.dark, television: television);

  static ThemeData light({bool television = false}) =>
      _build(Brightness.light, Palette.light, television: television);

  static AppTokens tokensFor(Brightness brightness) =>
      _tokens(brightness == Brightness.dark ? Palette.dark : Palette.light);

  static AppTokens _tokens(AppColors colors, {bool television = false}) {
    return AppTokens(
      colors: colors,
      spacing: television ? AppSpacing.television : AppSpacing.standard,
      radii: AppRadii.standard,
      typography: television
          ? AppTypography.television
          : AppTypography.standard,
      elevation: AppElevation.standard(shadowColor: const Color(0xFF000000)),
      motion: AppMotion.standard,
    );
  }

  static ThemeData _build(
    Brightness brightness,
    AppColors colors, {
    required bool television,
  }) {
    final tokens = _tokens(colors, television: television);
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
      focusColor: colors.accent.withValues(alpha: television ? .38 : .20),
      hoverColor: colors.accent.withValues(alpha: .12),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: television
          ? VisualDensity.comfortable
          : VisualDensity.standard,
      iconButtonTheme: television
          ? IconButtonThemeData(
              style: IconButton.styleFrom(
                minimumSize: const Size.square(56),
                iconSize: 28,
              ),
            )
          : null,
      listTileTheme: television
          ? const ListTileThemeData(
              minVerticalPadding: 16,
              contentPadding: EdgeInsets.symmetric(horizontal: 22),
            )
          : null,
      extensions: [tokens],
    );
  }
}
