import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/connected_playback/PlaybackControlCubit.dart';
import '../../../app/connectivity/OfflineCubit.dart';
import '../../../app/di/service_locator.dart';
import '../../../app/downloads/DownloadsCubit.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../design/design.dart';
import '../../../domain/connected_playback/remote_command_kind.dart';
import '../../../domain/media/media.dart';
import '../../../domain/playback/PlaybackQueue.dart';
import '../../../domain/playback/QueueEntry.dart';
import '../../music/presentation/widgets/downloaded_marker.dart';
import '../../music/presentation/widgets/MediaArtwork.dart';
import '../../music/presentation/widgets/media_formatting.dart';

/// Up next: reorder, remove, or jump straight to any entry — or, while
/// this device is controlling another one (v0.5.6), that device's queue,
/// read-only apart from jumping to an entry (the one queue-editing
/// capability this build ever advertises remotely; see
/// `SupportedRemoteCommands`).
///
/// A child route of Now Playing, so leaving it returns to the player
/// rather than to wherever the queue was opened from.
class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackControlCubit, PlaybackControlState>(
      bloc: getIt<PlaybackControlCubit>(),
      builder: (context, control) {
        if (control.isControlling) return _RemoteQueuePage(control: control);
        return BlocBuilder<PlaybackCubit, PlaybackUiState>(
          builder: (context, state) {
            final cubit = context.read<PlaybackCubit>();
            final entries = state.queue.entries;
            return AppScaffold(
              padded: false,
              title: 'Queue',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  tooltip: 'Clear queue',
                  onPressed: entries.isEmpty
                      ? null
                      : () => _confirmClear(context, cubit),
                ),
              ],
              body: QueueEditor(
                queue: state.queue,
                onJumpTo: cubit.playAt,
                onReorder: cubit.reorderPlayOrder,
                onRemove: cubit.removeAt,
              ),
            );
          },
        );
      },
    );
  }
}

class _RemoteQueuePage extends StatelessWidget {
  const _RemoteQueuePage({required this.control});

  final PlaybackControlState control;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padded: false,
      title: 'Queue · ${control.device!.displayName}',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: QueueEditor(
        queue: control.queue,
        onJumpTo: control.commandAvailable(RemoteCommandKind.jumpToQueueEntry)
            ? (index) => getIt<PlaybackControlCubit>().jumpToQueueEntry(index)
            : null,
      ),
    );
  }
}

/// Reusable queue list for the full route and the Now Playing overlay,
/// bound to a plain [PlaybackQueue] and a small set of callbacks rather
/// than a concrete cubit (v0.5.6) — what lets the same widget show either
/// `PlaybackCubit`'s own queue with full editing or another device's
/// read-mostly projection, and what makes "disable or omit unsupported
/// controls consistently" as simple as leaving a callback `null`.
///
/// Rows are listed in **play order**, not in the queue's own order
/// (v0.4.1). Under shuffle the two differ, and showing the canonical
/// order meant the list called "up next" was not what came next — the one
/// thing a queue screen exists to answer. Every row therefore carries
/// both positions: `playPosition` is where it sits on screen and what a
/// drag moves, `entriesIndex` is what [onJumpTo]/[onRemove] name it by.
class QueueEditor extends StatelessWidget {
  const QueueEditor({
    super.key,
    required this.queue,
    required this.onJumpTo,
    this.onReorder,
    this.onRemove,
  });

  final PlaybackQueue queue;

  /// Jumps to the entry at this **entries** index when the target
  /// advertises `RemoteCommandKind.jumpToQueueEntry`; otherwise rows are
  /// visibly non-interactive.
  final ValueChanged<int>? onJumpTo;

  /// Reorders by **play-order** position, matching
  /// `ReorderableListView`'s own convention — `null` hides every row's
  /// drag handle and disables reordering (no target ever advertises
  /// incremental remote queue editing; see `SupportedRemoteCommands`).
  final void Function(int oldPosition, int newPosition)? onReorder;

  /// Removes the entry at this entries index — `null` hides the row's
  /// remove action, for the same reason [onReorder] can be.
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (queue.entries.isEmpty) {
      return const EmptyStateView(
        title: 'The queue is empty',
        message: 'Play something and it will show up here.',
        icon: Icons.queue_music_rounded,
      );
    }

    final order = queue.playOrder;
    final currentPlayPosition = queue.currentPlayPosition;
    final reorder = onReorder;

    Widget rowAt(int playPosition) {
      final entriesIndex = order[playPosition];
      return _QueueRow(
        // Keyed by position rather than by the entry: the same track can
        // legitimately sit in a queue twice, and two identical
        // `ValueKey`s make a reorder move the wrong row.
        key: ValueKey('queue-$playPosition-$entriesIndex'),
        index: playPosition,
        entry: queue.entries[entriesIndex],
        isCurrent: playPosition == currentPlayPosition,
        draggable: reorder != null,
        onTap: onJumpTo == null ? null : () => onJumpTo!(entriesIndex),
        onRemove: onRemove == null ? null : () => onRemove!(entriesIndex),
      );
    }

    return Column(
      children: [
        _QueueRuntimeHeader(queue: queue),
        Expanded(
          child: reorder == null
              ? ListView.builder(
                  itemCount: order.length + (queue.isAtEndOfPlayOrder ? 1 : 0),
                  itemBuilder: (context, index) => index < order.length
                      ? rowAt(index)
                      : const _EndOfQueueNote(),
                )
              : ReorderableListView.builder(
                  itemCount: order.length,
                  onReorderItem: reorder,
                  buildDefaultDragHandles: false,
                  footer: queue.isAtEndOfPlayOrder
                      ? const _EndOfQueueNote()
                      : null,
                  itemBuilder: (context, playPosition) => rowAt(playPosition),
                ),
        ),
      ],
    );
  }
}

/// Says that nothing follows the last row, rather than leaving a listener
/// to find out when the music stops (v0.4.1). Absent whenever repeat will
/// wrap the queue, since then there *is* something after it.
class _EndOfQueueNote extends StatelessWidget {
  const _EndOfQueueNote();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.md,
        t.spacing.sm,
        t.spacing.md,
        t.spacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all_rounded, size: 16, color: t.colors.textSecondary),
          SizedBox(width: t.spacing.xs),
          Text(
            'End of queue',
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required super.key,
    required this.index,
    required this.entry,
    required this.isCurrent,
    required this.draggable,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final QueueEntry entry;
  final bool isCurrent;
  final bool draggable;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final downloaded = context.select<DownloadsCubit, bool>(
      (downloads) => downloads.state.isDownloaded(entry.id),
    );
    final offline = context.select<OfflineCubit, bool>(
      (cubit) => cubit.state.isOffline,
    );
    // Marked, not hidden: an entry that streamed fine but has no file is
    // still in the queue, it just cannot play until the server is back
    // (v0.3.6, the same rule `TrackRow` follows for a library list).
    final notPlayableOffline = offline && !downloaded;
    final unavailable =
        entry.availability == MediaAvailability.remoteUnavailable ||
        notPlayableOffline;

    // Why it failed, and what to do about it (v0.4.1). A row that failed
    // while online stays tappable: trying again is the action, and the
    // attempt re-resolves the address, which is what recovers a track
    // whose download was deleted underneath it. Offline with no file is
    // the one case where there is genuinely nothing to try.
    final failureMessage = entry.failureMessage;
    final showFailure = failureMessage != null && !notPlayableOffline;
    final subtitle = showFailure
        ? '$failureMessage Tap to try again.'
        : notPlayableOffline
        ? 'Not available offline'
        : entry.artist;

    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.xxs,
      ),
      child: SizedBox(
        height: 64,
        child: InkWell(
          onTap: notPlayableOffline ? null : onTap,
          borderRadius: t.radii.smBorder,
          child: Row(
            children: [
              // Reordering starts from this handle rather than anywhere
              // on the row, so a tap still plays the entry (v0.1.6).
              // Absent entirely when this queue cannot be reordered
              // (another device's projection, v0.5.6).
              if (draggable)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: EdgeInsets.only(right: t.spacing.xs),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: t.colors.textSecondary,
                    ),
                  ),
                ),
              MediaArtwork(image: entry.image, kind: MediaKind.track, size: 48),
              SizedBox(width: t.spacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.bodyLarge.copyWith(
                        color: isCurrent
                            ? t.colors.accent
                            : unavailable
                            ? t.colors.textSecondary
                            : t.colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: showFailure ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.typography.caption.copyWith(
                          color: showFailure
                              ? t.colors.danger
                              : t.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (downloaded) ...[
                SizedBox(width: t.spacing.xs),
                const DownloadedMarker.inline(size: 16),
              ],
              if (entry.duration != null) ...[
                SizedBox(width: t.spacing.sm),
                Text(
                  formatDuration(entry.duration!),
                  style: t.typography.caption.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ],
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 20,
                  color: t.colors.textSecondary,
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "6 songs · 24 min left" (v0.1.6): the current entry plus everything
/// still to come, using each track's full length rather than a live
/// countdown from the playback position — stable to read, not something
/// that ticks down every second.
class _QueueRuntimeHeader extends StatelessWidget {
  const _QueueRuntimeHeader({required this.queue});

  final PlaybackQueue queue;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final current = queue.currentEntry;
    final remaining = [?current, ...queue.upNext];
    if (remaining.isEmpty) return const SizedBox.shrink();

    Duration? total;
    for (final entry in remaining) {
      final duration = entry.duration;
      if (duration == null) continue;
      total = (total ?? Duration.zero) + duration;
    }
    if (total == null) return const SizedBox.shrink();

    final songCount = remaining.length == 1
        ? '1 song'
        : '${remaining.length} songs';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.md,
        t.spacing.sm,
        t.spacing.md,
        t.spacing.xs,
      ),
      child: Text(
        '$songCount · ${formatRunningTime(total)} left',
        style: t.typography.caption.copyWith(color: t.colors.textSecondary),
      ),
    );
  }
}

/// Confirms before dropping every entry (v0.1.6) — an accidental tap on
/// the old icon-only clear action could not be undone.
Future<void> _confirmClear(BuildContext context, PlaybackCubit cubit) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear queue?'),
      content: const Text('Do you want to remove all items from the queue?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Remove all'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) cubit.clear();
}
