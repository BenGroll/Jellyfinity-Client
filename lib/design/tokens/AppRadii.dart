import 'dart:ui' show lerpDouble;

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Corner-radius scale. Cards, sheets, buttons, artwork, and inputs each
/// pick a named step so rounding stays uniform and is later themeable in
/// one place (see `OUTLOOK.md` §10).
class AppRadii extends Equatable {
  const AppRadii({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.pill,
  });

  static const AppRadii standard = AppRadii(
    sm: 6,
    md: 10,
    lg: 16,
    xl: 24,
    pill: 999,
  );

  final double sm;
  final double md;
  final double lg;
  final double xl;

  /// Fully rounded ends, for chips and toggle pills.
  final double pill;

  Radius get smRadius => Radius.circular(sm);
  Radius get mdRadius => Radius.circular(md);
  Radius get lgRadius => Radius.circular(lg);

  BorderRadius get smBorder => BorderRadius.all(smRadius);
  BorderRadius get mdBorder => BorderRadius.all(mdRadius);
  BorderRadius get lgBorder => BorderRadius.all(lgRadius);

  static AppRadii lerp(AppRadii a, AppRadii b, double t) {
    double d(double x, double y) => lerpDouble(x, y, t)!;
    return AppRadii(
      sm: d(a.sm, b.sm),
      md: d(a.md, b.md),
      lg: d(a.lg, b.lg),
      xl: d(a.xl, b.xl),
      pill: d(a.pill, b.pill),
    );
  }

  @override
  List<Object?> get props => [sm, md, lg, xl, pill];
}
