import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// The two colour palettes Jellyfinity ships with.
///
/// These are the only place raw colour literals are allowed. Everything
/// else in the app goes through [AppColors] roles. Values lean dark and
/// low-chroma with a single warm accent, matching the "premium streaming
/// app, not a home-server admin panel" intent in `PHILOSOPHY.md`.
abstract final class Palette {
  static const Color _accent = Color(0xFF7C6BF2);

  static const AppColors dark = AppColors(
    background: Color(0xFF0E0E12),
    surface: Color(0xFF17171E),
    surfaceElevated: Color(0xFF20202A),
    surfaceSunken: Color(0xFF101015),
    overlay: Color(0xCC000000),
    border: Color(0xFF2C2C38),
    accent: _accent,
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFF3F3F7),
    textSecondary: Color(0xFFA6A6B4),
    textDisabled: Color(0xFF5C5C6B),
    onSurface: Color(0xFFD8D8E0),
    success: Color(0xFF4FB477),
    warning: Color(0xFFE0A23C),
    danger: Color(0xFFE5544B),
    skeletonBase: Color(0xFF20202A),
    skeletonHighlight: Color(0xFF2E2E3B),
  );

  static const AppColors light = AppColors(
    background: Color(0xFFF6F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFECECF0),
    overlay: Color(0x66000000),
    border: Color(0xFFDDDDE3),
    accent: _accent,
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1B1B22),
    textSecondary: Color(0xFF5B5B68),
    textDisabled: Color(0xFFAEAEBA),
    onSurface: Color(0xFF2A2A33),
    success: Color(0xFF2F9E5E),
    warning: Color(0xFFB9791F),
    danger: Color(0xFFCC3A31),
    skeletonBase: Color(0xFFE4E4EA),
    skeletonHighlight: Color(0xFFF1F1F5),
  );
}
