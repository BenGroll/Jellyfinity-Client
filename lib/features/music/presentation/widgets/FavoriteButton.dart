import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// The heart toggle shared by the Artist, Album, and Now Playing screens
/// (v0.1.6).
///
/// Flips immediately on tap rather than waiting for the server to answer
/// — the same optimistic-then-reconcile shape a heart button always has —
/// and reverts if [onChanged] reports the write failed, so a lost
/// connection never leaves the button lying about server state.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onChanged,
    this.unselectedColor,
    this.iconSize,
  });

  final bool isFavorite;

  /// Attempts to set the favorite flag to the given value on the server.
  /// Returns whether it succeeded.
  final Future<bool> Function(bool favorite) onChanged;

  final Color? unselectedColor;
  final double? iconSize;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  late bool _favorite = widget.isFavorite;
  bool _pending = false;

  @override
  void didUpdateWidget(covariant FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh fetch (e.g. pull-to-refresh) is the source of truth whenever
    // there is no optimistic toggle still in flight.
    if (!_pending && widget.isFavorite != oldWidget.isFavorite) {
      _favorite = widget.isFavorite;
    }
  }

  Future<void> _toggle() async {
    final next = !_favorite;
    setState(() {
      _favorite = next;
      _pending = true;
    });
    final succeeded = await widget.onChanged(next);
    if (!mounted) return;
    setState(() {
      _pending = false;
      if (!succeeded) _favorite = !next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      icon: Icon(
        _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      ),
      iconSize: widget.iconSize,
      tooltip: _favorite ? 'Remove from favorites' : 'Add to favorites',
      color: _favorite
          ? t.colors.accent
          : widget.unselectedColor ?? t.colors.textSecondary,
      onPressed: _toggle,
    );
  }
}
