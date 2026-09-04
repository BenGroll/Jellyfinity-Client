import 'package:flutter/material.dart';

import '../tokens/AppColors.dart';
import '../tokens/AppMotion.dart';
import '../tokens/AppRadii.dart';
import '../tokens/AppSpacing.dart';
import '../tokens/AppTypography.dart';
import 'AppTokens.dart';

/// Ergonomic access to the design tokens from any widget.
///
/// Usage:
/// ```dart
/// final t = context.tokens;
/// Container(color: t.colors.surface, padding: EdgeInsets.all(t.spacing.md));
/// ```
///
/// `context.colors` / `context.spacing` / ... are shorthands for the groups
/// that get read most.
extension AppThemeContext on BuildContext {
  AppTokens get tokens {
    final tokens = Theme.of(this).extension<AppTokens>();
    assert(
      tokens != null,
      'No AppTokens found on the ambient Theme. Wrap the app in a ThemeData '
      'built by AppTheme.light()/dark().',
    );
    return tokens!;
  }

  AppColors get colors => tokens.colors;
  AppSpacing get spacing => tokens.spacing;
  AppRadii get radii => tokens.radii;
  AppTypography get type => tokens.typography;
  AppMotion get motion => tokens.motion;
}
