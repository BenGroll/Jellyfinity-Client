import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Named text roles.
///
/// Feature widgets ask for a role (`type.titleLarge`, `type.caption`) rather
/// than building [TextStyle]s inline, so weight, size, and tracking decisions
/// live in one place. Colour is intentionally *not* baked in here — text
/// colour comes from [AppColors] at the call site (or from the widget's
/// default via [DefaultTextStyle]) so the same role works on light and dark
/// surfaces.
class AppTypography extends Equatable {
  const AppTypography({
    required this.displayLarge,
    required this.headlineLarge,
    required this.titleLarge,
    required this.titleMedium,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.label,
    required this.caption,
  });

  /// Large, screen-defining text (e.g. an artist name on a detail header).
  final TextStyle displayLarge;

  /// Section headers within a screen.
  final TextStyle headlineLarge;

  /// Primary item titles (an album title in a list row).
  final TextStyle titleLarge;

  /// Secondary titles / emphasised body.
  final TextStyle titleMedium;

  final TextStyle bodyLarge;
  final TextStyle bodyMedium;

  /// Buttons, tab labels, chips.
  final TextStyle label;

  /// Metadata, timestamps, helper text.
  final TextStyle caption;

  /// A neutral, family-agnostic default. A bundled font can replace this
  /// later without call sites changing.
  static const AppTypography standard = AppTypography(
    displayLarge: TextStyle(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineLarge: TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleLarge: TextStyle(
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
    ),
    label: TextStyle(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    caption: TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
    ),
  );

  static AppTypography lerp(AppTypography a, AppTypography b, double t) {
    TextStyle s(TextStyle x, TextStyle y) => TextStyle.lerp(x, y, t)!;
    return AppTypography(
      displayLarge: s(a.displayLarge, b.displayLarge),
      headlineLarge: s(a.headlineLarge, b.headlineLarge),
      titleLarge: s(a.titleLarge, b.titleLarge),
      titleMedium: s(a.titleMedium, b.titleMedium),
      bodyLarge: s(a.bodyLarge, b.bodyLarge),
      bodyMedium: s(a.bodyMedium, b.bodyMedium),
      label: s(a.label, b.label),
      caption: s(a.caption, b.caption),
    );
  }

  @override
  List<Object?> get props => [
    displayLarge,
    headlineLarge,
    titleLarge,
    titleMedium,
    bodyLarge,
    bodyMedium,
    label,
    caption,
  ];
}
