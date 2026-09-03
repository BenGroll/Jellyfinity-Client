import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// A token-styled text field for the auth screens.
///
/// Local to the auth feature for now (ADR-0001: extract to `lib/design`
/// only once a second feature needs a text input). It consumes only
/// design tokens so it will move cleanly if that happens.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.typography.label.copyWith(color: t.colors.textSecondary),
        ),
        SizedBox(height: t.spacing.xxs),
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: t.typography.bodyLarge.copyWith(color: t.colors.textPrimary),
          cursorColor: t.colors.accent,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: t.typography.bodyLarge.copyWith(
              color: t.colors.textDisabled,
            ),
            filled: true,
            fillColor: t.colors.surfaceSunken,
            contentPadding: EdgeInsets.symmetric(
              horizontal: t.spacing.md,
              vertical: t.spacing.sm,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: t.radii.mdBorder,
              borderSide: BorderSide(color: t.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: t.radii.mdBorder,
              borderSide: BorderSide(color: t.colors.accent, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: t.radii.mdBorder,
              borderSide: BorderSide(color: t.colors.border),
            ),
          ),
        ),
      ],
    );
  }
}
