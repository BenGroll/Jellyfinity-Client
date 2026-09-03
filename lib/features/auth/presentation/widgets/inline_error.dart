import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// A compact, in-context error line for the auth forms — an icon plus the
/// failure's message, in the danger colour.
///
/// `PHILOSOPHY.md` §2: communicate errors locally instead of replacing
/// the whole screen. The message text comes from a `Failure`, which per
/// ADR-0004 never contains sensitive data.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: t.colors.danger),
        SizedBox(width: t.spacing.xs),
        Expanded(
          child: Text(
            message,
            style: t.typography.bodyMedium.copyWith(color: t.colors.danger),
          ),
        ),
      ],
    );
  }
}
