import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/downloads/DownloadsCubit.dart';
import '../../../../design/design.dart';
import '../../../../domain/downloads/downloads.dart';
import '../../../../domain/media/Album.dart';
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
