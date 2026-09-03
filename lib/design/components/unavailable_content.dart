import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Wraps content that exists but cannot currently be used — e.g. a track
/// that is in the album but missing from the server, per the "show the 11
/// usable tracks, mark the 12th" rule in `CONTEXT.md`.
///
/// When [isUnavailable] is true the child is dimmed and pointer events are
/// blocked; an optional [reason] can be surfaced by the caller (e.g. in a
/// trailing [UnavailableBadge]). When false the child renders untouched, so
/// this can wrap list items unconditionally.
class UnavailableContent extends StatelessWidget {
  const UnavailableContent({
    super.key,
    required this.isUnavailable,
    required this.child,
    this.reason,
  });

  final bool isUnavailable;
  final String? reason;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isUnavailable) return child;

    return Semantics(
      enabled: false,
      hint: reason,
      child: IgnorePointer(child: Opacity(opacity: 0.45, child: child)),
    );
  }
}

/// A small "Unavailable" (or custom-labelled) pill, for the trailing edge
/// of a row whose content is wrapped in [UnavailableContent].
class UnavailableBadge extends StatelessWidget {
  const UnavailableBadge({super.key, this.label = 'Unavailable'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.xs,
        vertical: t.spacing.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: t.colors.surfaceSunken,
        borderRadius: BorderRadius.all(Radius.circular(t.radii.pill)),
        border: Border.all(color: t.colors.border),
      ),
      child: Text(
        label,
        style: t.typography.caption.copyWith(color: t.colors.textDisabled),
      ),
    );
  }
}
