import 'package:flutter/material.dart';

import '../tokens/AppColors.dart';
import '../tokens/AppElevation.dart';
import '../tokens/AppMotion.dart';
import '../tokens/AppRadii.dart';
import '../tokens/AppSpacing.dart';
import '../tokens/AppTypography.dart';

/// The full set of Jellyfinity design tokens, carried on [ThemeData] as a
/// [ThemeExtension].
///
/// Feature widgets never read [ThemeData] colours or text styles directly;
/// they read `context.tokens` (see `theme_context.dart`) and pull the
/// semantic role they need. Light and dark are two [AppTokens] instances
/// built by `AppTheme`; a future user-customization layer produces more of
/// them without any widget changing.
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.colors,
    required this.spacing,
    required this.radii,
    required this.typography,
    required this.elevation,
    required this.motion,
  });

  final AppColors colors;
  final AppSpacing spacing;
  final AppRadii radii;
  final AppTypography typography;
  final AppElevation elevation;
  final AppMotion motion;

  @override
  AppTokens copyWith({
    AppColors? colors,
    AppSpacing? spacing,
    AppRadii? radii,
    AppTypography? typography,
    AppElevation? elevation,
    AppMotion? motion,
  }) {
    return AppTokens(
      colors: colors ?? this.colors,
      spacing: spacing ?? this.spacing,
      radii: radii ?? this.radii,
      typography: typography ?? this.typography,
      elevation: elevation ?? this.elevation,
      motion: motion ?? this.motion,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      colors: AppColors.lerp(colors, other.colors, t),
      spacing: AppSpacing.lerp(spacing, other.spacing, t),
      radii: AppRadii.lerp(radii, other.radii, t),
      typography: AppTypography.lerp(typography, other.typography, t),
      elevation: AppElevation.lerp(elevation, other.elevation, t),
      motion: AppMotion.lerp(motion, other.motion, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppTokens &&
          other.colors == colors &&
          other.spacing == spacing &&
          other.radii == radii &&
          other.typography == typography &&
          other.elevation == elevation &&
          other.motion == motion;

  @override
  int get hashCode =>
      Object.hash(colors, spacing, radii, typography, elevation, motion);
}
