import 'package:flutter/material.dart';

import '../../../../core/result/partial.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import 'MediaArtwork.dart';
import 'media_formatting.dart';

/// The height a music row occupies, fixed so a list of 130k songs can be
/// scrolled without measuring anything.
const double musicRowHeight = 64;

/// Explains the `markUnavailable` flag every row takes.
///
/// An item that cannot be used is normally dimmed and made
/// non-interactive — the missing track in an otherwise fine album. But a
/// list served from the saved copy has *every* item unavailable, and
/// dimming all of it would read as a broken screen rather than an offline
/// one. Those screens pass `markUnavailable: false` and put a
/// `SavedCopyNotice` above the list instead.
abstract final class MusicRowStyle {
  /// Whether an unavailable item should be marked in place. The default
  /// every row takes; screens showing the saved copy pass `false`.
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
    this.markUnavailable = MusicRowStyle.markUnavailable,
  });

  final Artist artist;
  final VoidCallback? onTap;

  /// See [MusicRowStyle.markUnavailable].
  final bool markUnavailable;

  @override
  Widget build(BuildContext context) {
    return _MusicRow(
      onTap: onTap,
      availability: artist.availability,
      markUnavailable: markUnavailable,
      leading: MediaArtwork(
        image: artist.image,
        kind: MediaKind.artist,
        size: rowArtworkSize,
        shape: ArtworkShape.circle,
      ),
      title: artist.name,
    );
  }
}

/// One album in a list (as opposed to [AlbumTile] in a grid).
class AlbumRow extends StatelessWidget {
  const AlbumRow({
    super.key,
    required this.album,
    this.onTap,
    this.markUnavailable = MusicRowStyle.markUnavailable,
  });

  final Album album;
  final VoidCallback? onTap;

  /// See [MusicRowStyle.markUnavailable].
  final bool markUnavailable;

  @override
  Widget build(BuildContext context) {
    return _MusicRow(
      onTap: onTap,
      availability: album.availability,
      markUnavailable: markUnavailable,
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
    this.markUnavailable = MusicRowStyle.markUnavailable,
    this.onPlayNext,
    this.onAddToQueue,
  });

  final Track track;
  final VoidCallback? onTap;
  final bool showArtwork;

  /// See [MusicRowStyle.markUnavailable].
  final bool markUnavailable;

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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final duration = track.duration;
    final showMenu = onPlayNext != null || onAddToQueue != null;

    return _MusicRow(
      onTap: onTap,
      availability: track.availability,
      markUnavailable: markUnavailable,
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
      trailing: (duration == null && !showMenu)
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
                if (showMenu)
                  _TrackOverflowButton(
                    onPlayNext: onPlayNext,
                    onAddToQueue: onAddToQueue,
                  ),
              ],
            ),
    );
  }
}

/// The "..." menu a [TrackRow] shows when it has somewhere to send Play
/// Next / Add to Queue — a small bottom sheet rather than a `PopupMenu`,
/// so it reads the same as a system share sheet instead of a desktop-style
/// dropdown.
class _TrackOverflowButton extends StatelessWidget {
  const _TrackOverflowButton({this.onPlayNext, this.onAddToQueue});

  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;

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

  void _openMenu(BuildContext context) {
    final playNext = onPlayNext;
    final addToQueue = onAddToQueue;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (playNext != null)
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded),
                title: const Text('Play Next'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  playNext();
                },
              ),
            if (addToQueue != null)
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Add to Queue'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  addToQueue();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// One playlist.
class PlaylistRow extends StatelessWidget {
  const PlaylistRow({
    super.key,
    required this.playlist,
    this.onTap,
    this.markUnavailable = MusicRowStyle.markUnavailable,
  });

  final Playlist playlist;
  final VoidCallback? onTap;

  /// See [MusicRowStyle.markUnavailable].
  final bool markUnavailable;

  @override
  Widget build(BuildContext context) {
    return _MusicRow(
      onTap: onTap,
      availability: playlist.availability,
      markUnavailable: markUnavailable,
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
  });

  final Album album;
  final VoidCallback? onTap;

  /// See [MusicRowStyle.markUnavailable].
  final bool markUnavailable;

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
              child: LayoutBuilder(
                builder: (context, constraints) => MediaArtwork(
                  image: album.image,
                  kind: MediaKind.album,
                  size: constraints.maxWidth,
                ),
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
    required this.markUnavailable,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final MediaAvailability availability;

  /// See [MusicRowStyle.markUnavailable].
  final bool markUnavailable;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unavailable = availability == MediaAvailability.remoteUnavailable;

    return UnavailableContent(
      // Dim only what is individually unusable. A whole list read from
      // the saved copy says so with a notice above it instead — dimming
      // every row would make the screen look broken rather than offline.
      isUnavailable: false,
      child: SizedBox(
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
              if (trailing != null) ...[
                SizedBox(width: t.spacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
