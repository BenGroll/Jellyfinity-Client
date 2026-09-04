import 'dart:ui' show lerpDouble;

import 'package:equatable/equatable.dart';

/// The spacing scale. Every gap, pad, and inset in the app is one of these
/// steps, so vertical rhythm stays consistent across features.
///
/// The scale is roughly geometric (4 / 8 / 12 / 16 / 24 / 32 / 48) rather
/// than a raw multiplier, so call sites read as intent (`gaps.md`) instead
/// of arithmetic (`spacing * 2`).
class AppSpacing extends Equatable {
  const AppSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  static const AppSpacing standard = AppSpacing(
    xxs: 4,
    xs: 8,
    sm: 12,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
  );

  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  static AppSpacing lerp(AppSpacing a, AppSpacing b, double t) {
    double d(double x, double y) => lerpDouble(x, y, t)!;
    return AppSpacing(
      xxs: d(a.xxs, b.xxs),
      xs: d(a.xs, b.xs),
      sm: d(a.sm, b.sm),
      md: d(a.md, b.md),
      lg: d(a.lg, b.lg),
      xl: d(a.xl, b.xl),
      xxl: d(a.xxl, b.xxl),
    );
  }

  @override
  List<Object?> get props => [xxs, xs, sm, md, lg, xl, xxl];
}
