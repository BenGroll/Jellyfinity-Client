import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Visual weight of an [AppButton].
enum AppButtonVariant {
  /// Filled with the accent colour. One primary action per view.
  primary,

  /// Outlined / low-emphasis. Secondary actions, "Retry", "Cancel".
  secondary,

  /// No fill or border. Inline, tertiary actions.
  ghost,
}

/// The standard button for the app.
///
/// Exists so every tappable action shares the same press feedback (a small
/// scale + opacity dip on `easeOut`, honoring reduce-motion), sizing, and
/// disabled treatment, rather than each feature styling `ElevatedButton`
/// differently. A `null` [onPressed] renders the disabled state.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Stretch to the full available width.
  final bool expand;

  bool get _enabled => onPressed != null;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colors = t.colors;
    final enabled = widget._enabled;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final (bg, fg, border) = switch (widget.variant) {
      AppButtonVariant.primary => (colors.accent, colors.onAccent, null),
      AppButtonVariant.secondary => (
        Colors.transparent,
        colors.textPrimary,
        colors.border,
      ),
      AppButtonVariant.ghost => (Colors.transparent, colors.accent, null),
    };

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: 18,
            color: enabled ? fg : colors.textDisabled,
          ),
          SizedBox(width: t.spacing.xs),
        ],
        Text(
          widget.label,
          style: t.typography.label.copyWith(
            color: enabled ? fg : colors.textDisabled,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed && !reduceMotion ? 0.97 : 1,
          duration: t.motion.fast,
          curve: t.motion.emphasizedCurve,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.85 : 1,
            duration: t.motion.fast,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: t.spacing.md,
                vertical: t.spacing.sm,
              ),
              decoration: BoxDecoration(
                color: enabled ? bg : colors.surfaceSunken,
                borderRadius: t.radii.mdBorder,
                border: border == null
                    ? null
                    : Border.all(color: enabled ? border : colors.border),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
