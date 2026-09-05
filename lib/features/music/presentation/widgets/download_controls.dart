import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/downloads/DownloadsCubit.dart';
import '../../../../design/design.dart';
import '../../../../domain/downloads/downloads.dart';
import '../../../../domain/media/Album.dart';
import '../../../../domain/media/artist.dart';
import '../../../../domain/media/Playlist.dart';
import '../../../../domain/media/Track.dart';

/// The download affordance on one track row (v0.2.0).
///
/// One control that both *shows* the state and *is* the action for it,
/// rather than an icon plus a menu entry that can disagree with it. Every
/// state `DownloadState` can reach has a distinct look and a sensible
/// tap:
///
/// | state       | looks like            | tap does        |
/// |-------------|-----------------------|-----------------|
/// | not asked   | outline download icon | download        |
/// | queued      | indeterminate ring    | stop            |
/// | downloading | ring at its progress  | stop            |
/// | paused      | ring plus resume mark | resume          |
/// | completed   | filled accent check   | remove (asks)   |
/// | failed      | danger warning icon   | try again       |
///
/// A failure's reason is in the tooltip and, on tap-and-hold, in the
/// sheet — `CONTEXT.md`'s "never leave users guessing" applied to the
/// smallest control on the screen.
class TrackDownloadButton extends StatelessWidget {
  const TrackDownloadButton({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.watch<DownloadsCubit>().state;
    final downloads = context.read<DownloadsCubit>();
    final record = catalog[track.id];

    if (!catalog.isLoaded) {
      // Nothing is known yet. An empty box of the right size keeps the
      // row from reflowing when the records arrive a frame later.
      return const SizedBox(width: _size, height: _size);
    }

    final state = record?.state;
    return switch (state) {
      null => _IconAction(
        icon: Icons.download_outlined,
        tooltip: 'Download',
        color: t.colors.textSecondary,
        onPressed: () => downloads.downloadTrack(track),
      ),
      DownloadState.queued || DownloadState.downloading => _ProgressAction(
        progress: record!.progress,
        tooltip: state == DownloadState.queued
            ? 'Waiting to download — tap to stop'
            : 'Downloading — tap to stop',
        onPressed: () => downloads.pause(track.id),
      ),
      DownloadState.paused => _ProgressAction(
        progress: record!.progress,
        icon: Icons.play_arrow_rounded,
        tooltip: 'Stopped — tap to resume',
        onPressed: () => downloads.retry(track.id),
      ),
      DownloadState.waitingForNetwork => _IconAction(
        icon: Icons.wifi_rounded,
        tooltip: 'Waiting for Wi-Fi',
        color: t.colors.textSecondary,
        onPressed: () => confirmRemoveDownload(
          context,
          title: 'Stop waiting for "${track.name}"?',
          message:
              'It downloads on its own once you are on Wi-Fi. Removing it '
              'cancels the request. The song stays on your server.',
          confirmLabel: 'Cancel download',
          onConfirm: () => downloads.removeTrack(track.id),
        ),
      ),
      DownloadState.completed => _IconAction(
        icon: Icons.check_circle_rounded,
        tooltip: 'Downloaded — tap to remove',
        color: t.colors.accent,
        onPressed: () => confirmRemoveDownload(
          context,
          title: 'Remove "${track.name}"?',
          message:
              'The file is deleted from this device. The song stays on '
              'your server.',
          onConfirm: () => downloads.removeTrack(track.id),
        ),
      ),
      DownloadState.failed => _IconAction(
        icon: Icons.error_outline_rounded,
        tooltip: record!.failureReason?.message ?? 'Download failed',
        color: t.colors.danger,
        onPressed: () => downloads.retry(track.id),
        onLongPress: () => confirmRemoveDownload(
          context,
          title: 'Give up on "${track.name}"?',
          message: record.failureReason?.message ?? 'The download failed.',
          confirmLabel: 'Give up',
          onConfirm: () => downloads.removeTrack(track.id),
        ),
      ),
    };
  }

  static const double _size = 40;
}

/// The download affordance on an album header (v0.2.0).
///
/// The album-wide counterpart to [TrackDownloadButton]: it reflects the
/// aggregate of every track the album asked for, and opens a menu when
/// there is more than one thing to do with it (retry the failures,
/// remove the lot).
class AlbumDownloadButton extends StatelessWidget {
  const AlbumDownloadButton({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.watch<DownloadsCubit>().state;
    final downloads = context.read<DownloadsCubit>();
    final status = catalog.statusFor(DownloadOwner.album(album.id));

    if (!catalog.isLoaded) {
      return const SizedBox(width: 40, height: 40);
    }

    if (status.isEmpty) {
      return _IconAction(
        icon: Icons.download_outlined,
        tooltip: 'Download album',
        color: t.colors.textPrimary,
        onPressed: () => _download(context, downloads),
      );
    }

    if (status.isActive) {
      return _ProgressAction(
        progress: status.progress,
        tooltip: 'Downloading album — tap for options',
        onPressed: () => _openMenu(context, downloads, status),
      );
    }

    return _IconAction(
      icon: status.needsAttention
          ? Icons.error_outline_rounded
          : Icons.check_circle_rounded,
      tooltip: status.needsAttention
          ? '${status.completed} of ${status.total} downloaded'
          : 'Album downloaded',
      color: status.needsAttention ? t.colors.danger : t.colors.accent,
      onPressed: () => _openMenu(context, downloads, status),
    );
  }

  Future<void> _download(BuildContext context, DownloadsCubit downloads) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await downloads.downloadAlbum(album);
    if (result.failureOrNull case final failure?) {
      // The album's track list could not be read, so there is nothing to
      // queue. Saying so beats a download button that silently does
      // nothing.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not download "${album.name}". '
            '${failure.message}',
          ),
        ),
      );
    }
  }

  void _openMenu(
    BuildContext context,
    DownloadsCubit downloads,
    CollectionDownloadStatus status,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(describeCollectionDownload(status)),
              dense: true,
            ),
            if (status.needsAttention)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Try the rest again'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  downloads.retryAll(DownloadOwner.album(album.id));
                },
              ),
            if (!status.isComplete && !status.isActive)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download the missing tracks'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _download(context, downloads);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Remove download'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                confirmRemoveDownload(
                  context,
                  title: 'Remove "${album.name}"?',
                  message:
                      'Frees up ${status.completed} downloaded '
                      '${status.completed == 1 ? 'track' : 'tracks'} on this '
                      'device. Songs you downloaded on their own are kept, '
                      'and nothing changes on your server.',
                  onConfirm: () => downloads.removeAlbum(album.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The download affordance on a playlist header (v0.2.1).
///
/// The playlist counterpart to [AlbumDownloadButton]. It differs in two
/// ways that matter: "is it downloaded" is answered by whether a
/// membership snapshot exists, not by whether any track is (an empty or
/// all-unavailable playlist is still downloaded), and its menu offers a
/// "Check for changes" action — the user-requested reconcile
/// `ROADMAP.md` v0.2.1 asks for, which queues tracks added on the server
/// and drops the claim on ones removed.
class PlaylistDownloadButton extends StatelessWidget {
  const PlaylistDownloadButton({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.watch<DownloadsCubit>().state;
    final downloads = context.read<DownloadsCubit>();
    final status = catalog.statusFor(DownloadOwner.playlist(playlist.id));
    final isDownloaded = catalog.isPlaylistDownloaded(playlist.id);

    if (!catalog.isLoaded) {
      return const SizedBox(width: 40, height: 40);
    }

    if (!isDownloaded) {
      return _IconAction(
        icon: Icons.download_outlined,
        tooltip: 'Download playlist',
        color: t.colors.textPrimary,
        onPressed: () => _download(context, downloads),
      );
    }

    if (status.isActive) {
      return _ProgressAction(
        progress: status.progress,
        tooltip: 'Downloading playlist — tap for options',
        onPressed: () => _openMenu(context, downloads, status),
      );
    }

    return _IconAction(
      icon: status.needsAttention
          ? Icons.error_outline_rounded
          : Icons.check_circle_rounded,
      tooltip: status.needsAttention
          ? '${status.completed} of ${status.total} downloaded'
          : 'Playlist downloaded',
      color: status.needsAttention ? t.colors.danger : t.colors.accent,
      onPressed: () => _openMenu(context, downloads, status),
    );
  }

  Future<void> _download(BuildContext context, DownloadsCubit downloads) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await downloads.downloadPlaylist(playlist);
    if (result.failureOrNull case final failure?) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not download "${playlist.name}". ${failure.message}',
          ),
        ),
      );
    }
  }

  Future<void> _checkForChanges(
    BuildContext context,
    DownloadsCubit downloads,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final change = await downloads.reconcilePlaylist(playlist.id);
    messenger.showSnackBar(
      SnackBar(content: Text(describePlaylistDownloadChange(change))),
    );
  }

  void _openMenu(
    BuildContext context,
    DownloadsCubit downloads,
    CollectionDownloadStatus status,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(describeCollectionDownload(status)),
              dense: true,
            ),
            if (status.needsAttention)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Try the rest again'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  downloads.retryAll(DownloadOwner.playlist(playlist.id));
                },
              ),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Check for changes'),
              subtitle: const Text(
                'Download tracks added to this playlist, drop ones removed',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _checkForChanges(context, downloads);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Remove download'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                confirmRemoveDownload(
                  context,
                  title: 'Remove "${playlist.name}"?',
                  message:
                      'Frees up ${status.completed} downloaded '
                      '${status.completed == 1 ? 'track' : 'tracks'} on this '
                      'device. Songs you downloaded on their own, or that '
                      'another downloaded playlist keeps, stay — and nothing '
                      'changes on your server.',
                  onConfirm: () => downloads.removePlaylist(playlist.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The download affordance on an artist header (v0.2.2).
///
/// The artist-wide counterpart to [AlbumDownloadButton]. It differs in
/// one way that matters: an artist can be a very large collection, so the
/// first download asks for confirmation, naming how many tracks it is
/// about to queue. Everything else — the aggregate state, the menu of
/// retry/download-missing/remove — mirrors the album control.
class ArtistDownloadButton extends StatelessWidget {
  const ArtistDownloadButton({
    super.key,
    required this.artist,
    this.trackCount,
  });

  final Artist artist;

  /// The artist's song count, when the stats row has loaded it — used to
  /// tell the user what a download will cost before they commit.
  final int? trackCount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.watch<DownloadsCubit>().state;
    final downloads = context.read<DownloadsCubit>();
    final status = catalog.statusFor(DownloadOwner.artist(artist.id));

    if (!catalog.isLoaded) {
      return const SizedBox(width: 40, height: 40);
    }

    if (status.isEmpty) {
      return _IconAction(
        icon: Icons.download_outlined,
        tooltip: 'Download every song by this artist',
        color: t.colors.textPrimary,
        onPressed: () => _confirmAndDownload(context, downloads),
      );
    }

    if (status.isActive) {
      return _ProgressAction(
        progress: status.progress,
        tooltip: 'Downloading — tap for options',
        onPressed: () => _openMenu(context, downloads, status),
      );
    }

    return _IconAction(
      icon: status.needsAttention
          ? Icons.error_outline_rounded
          : Icons.check_circle_rounded,
      tooltip: status.needsAttention
          ? '${status.completed} of ${status.total} downloaded'
          : 'Artist downloaded',
      color: status.needsAttention ? t.colors.danger : t.colors.accent,
      onPressed: () => _openMenu(context, downloads, status),
    );
  }

  Future<void> _confirmAndDownload(
    BuildContext context,
    DownloadsCubit downloads,
  ) async {
    final count = trackCount;
    final scope = count == null
        ? 'every song by ${artist.name}'
        : '$count ${count == 1 ? 'song' : 'songs'} by ${artist.name}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Download ${artist.name}?'),
        content: Text(
          'This keeps $scope on this device. It downloads at your chosen '
          'download quality, one track at a time, and you can stop it from '
          'the Downloads screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;
    await _download(context, downloads);
  }

  Future<void> _download(BuildContext context, DownloadsCubit downloads) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await downloads.downloadArtist(artist);
    if (result.failureOrNull case final failure?) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not download "${artist.name}". ${failure.message}',
          ),
        ),
      );
    }
  }

  void _openMenu(
    BuildContext context,
    DownloadsCubit downloads,
    CollectionDownloadStatus status,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(describeCollectionDownload(status)),
              dense: true,
            ),
            if (status.needsAttention)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Try the rest again'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  downloads.retryAll(DownloadOwner.artist(artist.id));
                },
              ),
            if (!status.isComplete && !status.isActive)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download the missing tracks'),
                subtitle: const Text(
                  'Also picks up anything released since you downloaded',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _download(context, downloads);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Remove download'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                confirmRemoveDownload(
                  context,
                  title: 'Remove "${artist.name}"?',
                  message:
                      'Frees up ${status.completed} downloaded '
                      '${status.completed == 1 ? 'track' : 'tracks'} on this '
                      'device. Songs you downloaded on their own, or that a '
                      'downloaded album or playlist keeps, stay — and nothing '
                      'changes on your server.',
                  onConfirm: () => downloads.removeArtist(artist.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One line describing what a playlist reconcile changed (v0.2.1).
String describePlaylistDownloadChange(PlaylistDownloadChange change) {
  if (change.isEmpty) return 'This playlist download is up to date';
  final parts = <String>[];
  if (change.added > 0) {
    parts.add(
      '${change.added} new ${change.added == 1 ? 'track' : 'tracks'} '
      'downloading',
    );
  }
  if (change.removed > 0) {
    final kept = change.removedButKept > 0
        ? ' (${change.removedButKept} kept for another download)'
        : '';
    parts.add('${change.removed} removed from the playlist$kept');
  }
  return parts.join(' · ');
}

/// The line an album header shows under its facts while any of it is
/// downloaded — the honest summary `ROADMAP.md` asks for, which names
/// failures instead of averaging them away.
class CollectionDownloadSummary extends StatelessWidget {
  const CollectionDownloadSummary({super.key, required this.status});

  final CollectionDownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (status.isEmpty) return const SizedBox.shrink();

    final needsAttention = status.needsAttention;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          needsAttention
              ? Icons.error_outline_rounded
              : status.isComplete
              ? Icons.download_done_rounded
              : Icons.downloading_rounded,
          size: 14,
          color: needsAttention ? t.colors.danger : t.colors.textSecondary,
        ),
        SizedBox(width: t.spacing.xxs),
        Flexible(
          child: Text(
            describeCollectionDownload(status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.typography.caption.copyWith(
              color: needsAttention ? t.colors.danger : t.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// A downloaded-size figure for the Downloads screen (v0.2.2). Rounded,
/// not false-precise: "1.2 GB", "340 MB", "12 MB", "800 KB", or "—" for
/// nothing.
String formatDownloadSize(int bytes) {
  if (bytes <= 0) return '—';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  if (bytes >= mb) return '${(bytes / mb).round()} MB';
  if (bytes >= kb) return '${(bytes / kb).round()} KB';
  return '$bytes B';
}

/// One line describing where a collection's downloads stand.
String describeCollectionDownload(CollectionDownloadStatus status) {
  if (status.isEmpty) return 'Not downloaded';
  final parts = <String>[];
  if (status.isComplete) {
    parts.add('Downloaded');
  } else {
    parts.add('${status.completed} of ${status.total} downloaded');
  }
  if (status.pending > 0) parts.add('${status.pending} to go');
  if (status.waitingForNetwork > 0) {
    parts.add('${status.waitingForNetwork} waiting for Wi-Fi');
  }
  if (status.paused > 0) parts.add('${status.paused} stopped');
  if (status.failed > 0) {
    parts.add('${status.failed} failed');
  }
  return parts.join(' · ');
}

/// Asks before deleting anything from the device.
///
/// Removal is the one download action that destroys work, so it always
/// says what goes and — because this is the fear the action provokes —
/// that the server's copy is untouched.
Future<void> confirmRemoveDownload(
  BuildContext context, {
  required String title,
  required String message,
  required VoidCallback onConfirm,
  String confirmLabel = 'Remove',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (confirmed ?? false) onConfirm();
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.onLongPress,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      icon: Icon(icon),
      iconSize: 20,
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
    );
    if (onLongPress == null) return button;
    return GestureDetector(onLongPress: onLongPress, child: button);
  }
}

/// A tappable progress ring. [progress] is `null` while the total size is
/// unknown, which spins rather than claiming a percentage nobody has
/// measured.
class _ProgressAction extends StatelessWidget {
  const _ProgressAction({
    required this.progress,
    required this.tooltip,
    required this.onPressed,
    this.icon = Icons.stop_rounded,
  });

  final double? progress;
  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                  color: t.colors.accent,
                  backgroundColor: t.colors.border,
                ),
              ),
              Icon(icon, size: 12, color: t.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
