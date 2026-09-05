import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../domain/downloads/downloads.dart';

/// A small "kept on this device" mark for an album, artist or playlist
/// (v0.2.3) — shown on library tiles and rows, and on the detail headers,
/// so a downloaded collection is recognisable at a glance without opening
/// it.
///
/// Two shapes:
///
/// - [DownloadedMarker.badge] — a filled circle sized to sit in the corner
///   of a piece of artwork, in a [Stack].
/// - [DownloadedMarker.inline] — a bare icon to drop into a row's trailing
///   slot or beside a title.
class DownloadedMarker extends StatelessWidget {
  const DownloadedMarker._({required this.badge, this.size});

  /// A filled circle for the corner of a grid tile's artwork.
  const DownloadedMarker.badge({double size = 20})
    : this._(badge: true, size: size);

  /// A bare icon for a row's trailing slot or a header title.
  const DownloadedMarker.inline({double size = 18})
    : this._(badge: false, size: size);

  final bool badge;
  final double? size;

  /// Whether [status] warrants a marker at all: at least one track of the
  /// collection is actually on the device. A collection only queued or
  /// still downloading shows nothing yet — the marker means "you can play
  /// this offline", not "you asked for it".
  static bool warranted(CollectionDownloadStatus status) =>
      status.completed > 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = Icon(
      Icons.download_done_rounded,
      size: badge ? (size! * 0.62) : size,
      color: badge ? t.colors.onAccent : t.colors.accent,
    );
    if (!badge) return icon;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.colors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: t.colors.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }
}
