import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Elevation expressed as ready-to-use shadow sets rather than a Material
/// `elevation:` number, so the same depth reads consistently whether it is
/// applied to a [Container], a custom sheet, or the now-playing bar.
class AppElevation extends Equatable {
  const AppElevation({
    required this.none,
    required this.low,
    required this.medium,
    required this.high,
  });

  final List<BoxShadow> none;

  /// Resting cards, list rows that need separation from the background.
  final List<BoxShadow> low;

  /// Menus, bottom sheets.
  final List<BoxShadow> medium;

  /// Dialogs, the player surface over content.
  final List<BoxShadow> high;

  static AppElevation standard({required Color shadowColor}) {
    return AppElevation(
      none: const [],
      low: [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      medium: [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.16),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
      high: [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.22),
          blurRadius: 36,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static List<BoxShadow> _lerp(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) => BoxShadow.lerpList(a, b, t) ?? const [];

  static AppElevation lerp(AppElevation a, AppElevation b, double t) {
    return AppElevation(
      none: _lerp(a.none, b.none, t),
      low: _lerp(a.low, b.low, t),
      medium: _lerp(a.medium, b.medium, t),
      high: _lerp(a.high, b.high, t),
    );
  }

  @override
  List<Object?> get props => [none, low, medium, high];
}
