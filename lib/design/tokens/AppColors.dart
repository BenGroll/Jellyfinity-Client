import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Semantic colour roles for Jellyfinity.
///
/// Widgets reference roles (`surface`, `textSecondary`, `accent`, ...), never
/// raw hex values or [Colors] constants. This is the seam the later theme
/// customization work (see `OUTLOOK.md` §10) plugs into: swapping a palette
/// means constructing a different [AppColors], not touching feature widgets.
class AppColors extends Equatable {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSunken,
    required this.overlay,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.onSurface,
    required this.success,
    required this.warning,
    required this.danger,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  /// The furthest-back surface: the app scaffold background.
  final Color background;

  /// The default resting surface for cards, sheets, list rows.
  final Color surface;

  /// A surface that sits visually above [surface] (menus, dialogs, the
  /// eventual now-playing bar).
  final Color surfaceElevated;

  /// A surface that reads as recessed (input fields, track-progress track).
  final Color surfaceSunken;

  /// Scrim colour for modal barriers and image-overlay gradients.
  final Color overlay;

  /// Hairline dividers and outlines.
  final Color border;

  /// The primary brand / interactive accent.
  final Color accent;

  /// Content drawn on top of [accent].
  final Color onAccent;

  /// Primary body and heading text.
  final Color textPrimary;

  /// Supporting text: subtitles, metadata, captions.
  final Color textSecondary;

  /// Text and icons for unavailable / disabled content.
  final Color textDisabled;

  /// Default icon / text colour on [surface] when not a text role above.
  final Color onSurface;

  final Color success;
  final Color warning;
  final Color danger;

  /// Base and shimmer-highlight colours for loading skeletons.
  final Color skeletonBase;
  final Color skeletonHighlight;

  static AppColors lerp(AppColors a, AppColors b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return AppColors(
      background: c(a.background, b.background),
      surface: c(a.surface, b.surface),
      surfaceElevated: c(a.surfaceElevated, b.surfaceElevated),
      surfaceSunken: c(a.surfaceSunken, b.surfaceSunken),
      overlay: c(a.overlay, b.overlay),
      border: c(a.border, b.border),
      accent: c(a.accent, b.accent),
      onAccent: c(a.onAccent, b.onAccent),
      textPrimary: c(a.textPrimary, b.textPrimary),
      textSecondary: c(a.textSecondary, b.textSecondary),
      textDisabled: c(a.textDisabled, b.textDisabled),
      onSurface: c(a.onSurface, b.onSurface),
      success: c(a.success, b.success),
      warning: c(a.warning, b.warning),
      danger: c(a.danger, b.danger),
      skeletonBase: c(a.skeletonBase, b.skeletonBase),
      skeletonHighlight: c(a.skeletonHighlight, b.skeletonHighlight),
    );
  }

  @override
  List<Object?> get props => [
    background,
    surface,
    surfaceElevated,
    surfaceSunken,
    overlay,
    border,
    accent,
    onAccent,
    textPrimary,
    textSecondary,
    textDisabled,
    onSurface,
    success,
    warning,
    danger,
    skeletonBase,
    skeletonHighlight,
  ];
}
