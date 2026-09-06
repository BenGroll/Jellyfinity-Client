import 'package:flutter/material.dart';

import '../../../../core/result/partial.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import 'downloaded_marker.dart';
import 'MediaArtwork.dart';
import 'media_formatting.dart';

/// The height a music row occupies, fixed so a list of 130k songs can be
/// scrolled without measuring anything.
const double musicRowHeight = 64;

/// Explains the `markUnavailable` flag [AlbumTile] takes.
///
/// An item that cannot be used is normally dimmed and made
/// non-interactive — the missing track in an otherwise fine album. But a
/// list served from the saved copy has *every* item unavailable, and
/// dimming all of it would read as a broken screen rather than an offline
/// one. Those screens pass `markUnavailable: false` and put a
/// `SavedCopyNotice` above the grid instead.
///
/// Only a grid tile takes this. The rows — [ArtistRow], [AlbumRow],
/// [TrackRow], [PlaylistRow] — say the same thing in the colour of their
/// title and never dim wholesale, so they accepted the flag and ignored
/// it; it was removed rather than left to imply an effect it never had.
/// [TrackRow.playable] is the separate, live mechanism for a row that
/// genuinely cannot be tapped.
abstract final class MusicRowStyle {
  /// Whether an unavailable item should be marked in place. The default
  /// [AlbumTile] takes; screens showing the saved copy pass `false`.
  static const bool markUnavailable = true;
}

/// The edge length of the artwork in a row.
const double rowArtworkSize = 48;

/// One artist in the artists list.
class ArtistRow extends StatelessWidget {
  const ArtistRow({
    super.key,
    required this.artist,
    this.onTap,
    this.downloaded = false,
  });

  final Artist artist;
  final VoidCallback? onTap;

  /// Whether any of this artist is kept on the device (v0.2.3) — shows a
  /// small marker in the trailing slot.
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    return _MusicRow(
      onTap: onTap,
      availability: artist.availability,
      leading: MediaArtwork(
        image: artist.image,
        kind: MediaKind.artist,
        size: rowArtworkSize,
        shape: ArtworkShape.circle,
      ),
      title: artist.name,
      trailing: downloaded ? const DownloadedMarker.inline() : null,
    );
  }
}

/// One album in a list (as opposed to [AlbumTile] in a grid).
class AlbumRow extends StatelessWidget {
  const AlbumRow({
    super.key,
    required this.album,
    this.onTap,
    this.downloaded = false,
  });

  final Album album;
  final VoidCallback? onTap;

  /// Whether this album is kept on the device (v0.2.3).
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    return _MusicRow(
      onTap: onTap,
      availability: album.availability,
      leading: MediaArtwork(
        image: album.image,
        kind: MediaKind.album,
        size: rowArtworkSize,
      ),
      title: album.name,
      subtitle: joinDetails([
        formatArtists(album.artists),
        album.productionYear?.toString(),
      ]),
      trailing: downloaded ? const DownloadedMarker.inline() : null,
    );
  }
}

/// One song. [trackNumber] replaces the artwork in an album's track list,
/// where every row would otherwise show the same cover.
class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    this.onTap,
    this.showArtwork = true,
    this.position,
    this.playable = true,
    this.onPlayNext,
    this.onAddToQueue,
    this.onRemoveFromPlaylist,
    this.downloadAction,
  });

  final Track track;
  final VoidCallback? onTap;
  final bool showArtwork;

  /// Whether this track can actually be played right now — its file is on
  /// the device, or the server is reachable (v0.2.3). `false` greys the
  /// row out and blocks its tap: offline, a song that was only ever
  /// streamed is on screen but not playable, and saying so in place beats
  /// a tap that does nothing. Callers that cannot play the track pass
  /// `onTap: null` alongside this.
  final bool playable;

  /// The number shown in place of artwork, when this row is part of an
  /// ordered list the user recognises (an album, a playlist).
  final int? position;

  /// Queues [track] right after whatever is currently playing. `null`
  /// hides the overflow menu entirely — a screen with no playback
  /// context (there is none today, but the seam costs nothing) simply
  /// does not pass either callback.
  final VoidCallback? onPlayNext;

  /// Appends [track] to the end of the queue.
  final VoidCallback? onAddToQueue;

  /// Removes this row from the playlist it is being shown in (v0.1.2's
  /// completion). `null` everywhere but a playlist's own page — and there
  /// too when the row came from the saved copy, which carries no entry id
  /// to remove by.
  final VoidCallback? onRemoveFromPlaylist;

  /// The row's download control (v0.2.0), normally a
  /// `TrackDownloadButton`. `null` — the default — leaves the row exactly
  /// as it was, for the same reason [onPlayNext] is optional: a list
  /// shown without download context simply does not offer the action.
  final Widget? downloadAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final duration = track.duration;
    final showMenu =
        onPlayNext != null ||
        onAddToQueue != null ||
        onRemoveFromPlaylist != null;

    return UnavailableContent(
      // Greyed out and non-interactive when it cannot play — the offline
      // "show everything" case (v0.2.3), and the long-standing missing
      // track in an otherwise fine album.
      isUnavailable: !playable,
      reason: 'Not playable right now',
      child: _MusicRow(
        onTap: onTap,
        availability: track.availability,
        leading: showArtwork
            ? MediaArtwork(
                image: track.image,
                kind: MediaKind.track,
                size: rowArtworkSize,
              )
            : SizedBox(
                width: rowArtworkSize,
                child: Center(
                  child: Text(
                    '${position ?? track.trackNumber ?? ''}',
                    style: t.typography.bodyMedium.copyWith(
                      color: t.colors.textSecondary,
                    ),
                  ),
                ),
              ),
        title: track.name,
        subtitle: joinDetails([
          formatArtists(track.artists),
          if (showArtwork) track.albumName,
        ]),
        trailing: (duration == null && !showMenu && downloadAction == null)
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (duration != null)
                    Text(
                      formatDuration(duration),
                      style: t.typography.caption.copyWith(
                        color: t.colors.textSecondary,
                      ),
                    ),
                  ?downloadAction,
                  if (showMenu)
                    _TrackOverflowButton(
                      onPlayNext: onPlayNext,
                      onAddToQueue: onAddToQueue,
                      onRemoveFromPlaylist: onRemoveFromPlaylist,
                    ),
                ],
              ),
      ),
    );
  }
}

/// The "..." menu a [TrackRow] shows when it has somewhere to send Play
/// Next / Add to Queue — a small bottom sheet rather than a `PopupMenu`,
/// so it reads the same as a system share sheet instead of a desktop-style
/// dropdown.
class _TrackOverflowButton extends StatelessWidget {
  const _TrackOverflowButton({
    this.onPlayNext,
    this.onAddToQueue,
    this.onRemoveFromPlaylist,
  });

  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onRemoveFromPlaylist;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      icon: const Icon(Icons.more_vert_rounded),
      iconSize: 20,
      color: t.colors.textSecondary,
      onPressed: () => _openMenu(context),
    );
  }

  void _openMenu(BuildContext context) => showTrackActionsSheet(
    context,
    onPlayNext: onPlayNext,
    onAddToQueue: onAddToQueue,
    onRemoveFromPlaylist: onRemoveFromPlaylist,
  );
}

/// The "Play Next" / "Add to Queue" bottom sheet [TrackRow] opens from its
/// overflow button — extracted so Now Playing's app bar (v0.1.6) can open
/// the exact same menu for the track currently playing, instead of a
/// second, only-slightly-different one.
void showTrackActionsSheet(
  BuildContext context, {
  VoidCallback? onPlayNext,
  VoidCallback? onAddToQueue,
  VoidCallback? onLyrics,
  VoidCallback? onOpenQueue,
  VoidCallback? onRemoveFromPlaylist,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPlayNext != null)
            ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: const Text('Play Next'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPlayNext();
              },
            ),
          if (onAddToQueue != null)
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to Queue'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onAddToQueue();
              },
            ),
          // Lyrics and Queue are screens Now Playing links to, rather than
          // queue-mutating actions like the two above — folded into the
          // same sheet (v0.1.6) so its top app bar keeps only the heart
          // and this one overflow button.
          if (onLyrics != null)
            ListTile(
              leading: const Icon(Icons.lyrics_outlined),
              title: const Text('Lyrics'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onLyrics();
              },
            ),
          if (onOpenQueue != null)
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Queue'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onOpenQueue();
              },
            ),
          // Last, and only on a playlist's own page (v0.1.2's
          // completion): it is the one entry here that changes something
          // on the server rather than the queue.
          if (onRemoveFromPlaylist != null)
            ListTile(
              leading: const Icon(Icons.playlist_remove_rounded),
              title: const Text('Remove from this playlist'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onRemoveFromPlaylist();
              },
            ),
        ],
      ),
    ),
  );
}

/// One playlist.
class PlaylistRow extends StatelessWidget {
  const PlaylistRow({
    super.key,
    required this.playlist,
    this.onTap,
    this.downloaded = false,
  });

  final Playlist playlist;
  final VoidCallback? onTap;

  /// Whether this playlist is kept on the device (v0.2.3).
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    return _MusicRow(
      onTap: onTap,
      availability: playlist.availability,
      leading: MediaArtwork(
        image: playlist.image,
        kind: MediaKind.playlist,
        size: rowArtworkSize,
      ),
      title: playlist.name,
      subtitle: joinDetails([
        formatTrackCount(playlist.itemCount),
        playlist.duration == null
            ? null
            : formatRunningTime(playlist.duration!),
      ]),
      trailing: downloaded ? const DownloadedMarker.inline() : null,
    );
  }
}

/// An entry that arrived but could not be read, holding its place in a
/// list so the numbering the user knows still matches.
class UnavailableRow extends StatelessWidget {
  const UnavailableRow({super.key, required this.item, this.position});

  final UnavailableItem item;
  final int? position;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SizedBox(
      height: musicRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: rowArtworkSize,
            child: Center(
              child: position == null
                  ? Icon(
                      Icons.help_outline_rounded,
                      size: 20,
                      color: t.colors.textDisabled,
                    )
                  : Text(
                      '$position',
                      style: t.typography.bodyMedium.copyWith(
                        color: t.colors.textDisabled,
                      ),
                    ),
            ),
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Text(
              item.reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.bodyMedium.copyWith(
                color: t.colors.textDisabled,
              ),
            ),
          ),
          SizedBox(width: t.spacing.sm),
          const UnavailableBadge(),
        ],
      ),
    );
  }
}

/// One album as a grid tile.
class AlbumTile extends StatelessWidget {
  const AlbumTile({
    super.key,
    required this.album,
    this.onTap,
    this.markUnavailable = MusicRowStyle.markUnavailable,
    this.downloaded = false,
  });

  final Album album;
  final VoidCallback? onTap;

  /// See [MusicRowStyle.markUnavailable].
  final bool markUnavailable;

  /// Whether this album is kept on the device (v0.2.3) — shows a small
  /// badge on the cover.
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final subtitle = joinDetails([
      formatArtists(album.artists),
      album.productionYear?.toString(),
    ]);

    return UnavailableContent(
      isUnavailable:
          markUnavailable &&
          album.availability == MediaAvailability.remoteUnavailable,
      reason: 'Not available right now',
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radii.smBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) => MediaArtwork(
                        image: album.image,
                        kind: MediaKind.album,
                        size: constraints.maxWidth,
                      ),
                    ),
                  ),
                  if (downloaded)
                    Positioned(
                      right: t.spacing.xxs,
                      bottom: t.spacing.xxs,
                      child: const DownloadedMarker.badge(),
                    ),
                ],
              ),
            ),
            SizedBox(height: t.spacing.xs),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.bodyMedium.copyWith(
                color: t.colors.textPrimary,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.caption.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The shape every music row shares: fixed height, artwork or index,
/// title over an optional subtitle, optional trailing, and the dimming
/// that marks something as not currently usable.
class _MusicRow extends StatelessWidget {
  const _MusicRow({
    required this.leading,
    required this.title,
    required this.availability,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final MediaAvailability availability;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unavailable = availability == MediaAvailability.remoteUnavailable;

    // Deliberately not wrapped in `UnavailableContent`: a row states its
    // availability in the colour of its title and, where a whole list
    // came from the saved copy, in a notice above the list. Dimming and
    // disabling every row as well would make an offline screen look
    // broken. A grid of `AlbumTile`s, which has no title colour to lean
    // on, does dim an individually unavailable tile.
    return SizedBox(
      height: musicRowHeight,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radii.smBorder,
        child: Row(
          children: [
            leading,
            SizedBox(width: t.spacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.bodyLarge.copyWith(
                      color: unavailable
                          ? t.colors.textSecondary
                          : t.colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.caption.copyWith(
                        color: t.colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[SizedBox(width: t.spacing.sm), trailing!],
          ],
        ),
      ),
    );
  }
}
