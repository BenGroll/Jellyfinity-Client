import 'package:equatable/equatable.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show lerpDuration;

/// Animation timing tokens.
///
/// Transitions, skeleton shimmer, expand/collapse, and page changes pull
/// their durations and curves from here so motion feels like one system
/// and can be globally slowed, sped up, or reduced later.
class AppMotion extends Equatable {
  const AppMotion({
    required this.fast,
    required this.medium,
    required this.slow,
    required this.standardCurve,
    required this.emphasizedCurve,
  });

  static const AppMotion standard = AppMotion(
    fast: Duration(milliseconds: 120),
    medium: Duration(milliseconds: 240),
    slow: Duration(milliseconds: 400),
    standardCurve: Curves.easeInOut,
    emphasizedCurve: Curves.easeOutCubic,
  );

  /// Small, immediate feedback: pressed states, ripples, tiny fades.
  final Duration fast;

  /// The default for most UI transitions.
  final Duration medium;

  /// Larger surfaces entering/leaving: sheets, the player.
  final Duration slow;

  final Curve standardCurve;
  final Curve emphasizedCurve;

  static AppMotion lerp(AppMotion a, AppMotion b, double t) {
    // Curves don't interpolate; snap to the target half-way through.
    return AppMotion(
      fast: lerpDuration(a.fast, b.fast, t),
      medium: lerpDuration(a.medium, b.medium, t),
      slow: lerpDuration(a.slow, b.slow, t),
      standardCurve: t < 0.5 ? a.standardCurve : b.standardCurve,
      emphasizedCurve: t < 0.5 ? a.emphasizedCurve : b.emphasizedCurve,
    );
  }

  @override
  List<Object?> get props => [
    fast,
    medium,
    slow,
    standardCurve,
    emphasizedCurve,
  ];
}
