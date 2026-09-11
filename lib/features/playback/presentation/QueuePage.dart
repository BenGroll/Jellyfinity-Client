import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/connectivity/OfflineCubit.dart';
import '../../../app/downloads/DownloadsCubit.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../design/design.dart';
import '../../../domain/media/media.dart';
import '../../../domain/playback/PlaybackQueue.dart';
import '../../../domain/playback/QueueEntry.dart';
import '../../music/presentation/widgets/downloaded_marker.dart';
import '../../music/presentation/widgets/MediaArtwork.dart';
import '../../music/presentation/widgets/media_formatting.dart';

/// Up next: reorder, remove, or jump straight to any entry.
///
/// A child route of Now Playing, so leaving it returns to the player
/// rather than to wherever the queue was opened from.
class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
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
          body: QueueEditor(state: state, cubit: cubit),
        );
      },
    );
  }
}

/// Reusable queue list for the full route and the Now Playing overlay.
///
/// Rows are listed in **play order**, not in the queue's own order
/// (v0.4.1). Under shuffle the two differ, and showing the canonical
/// order meant the list called "up next" was not what came next — the one
/// thing a queue screen exists to answer. Every row therefore carries
/// both positions: `playPosition` is where it sits on screen and what a
/// drag moves, `entriesIndex` is what `PlaybackCubit` names it by.
class QueueEditor extends StatelessWidget {
  const QueueEditor({super.key, required this.state, required this.cubit});

  final PlaybackUiState state;
  final PlaybackCubit cubit;

  @override
  Widget build(BuildContext context) {
    final queue = state.queue;
    if (queue.entries.isEmpty) {
      return const EmptyStateView(
        title: 'The queue is empty',
        message: 'Play something and it will show up here.',
        icon: Icons.queue_music_rounded,
      );
    }

    final order = queue.playOrder;
    final currentPlayPosition = queue.currentPlayPosition;

    return Column(
      children: [
        _QueueRuntimeHeader(queue: queue),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: order.length,
            onReorderItem: cubit.reorderPlayOrder,
            buildDefaultDragHandles: false,
            footer: queue.isAtEndOfPlayOrder
                ? const _EndOfQueueNote()
                : null,
            itemBuilder: (context, playPosition) {
              final entriesIndex = order[playPosition];
              final entry = queue.entries[entriesIndex];
              return _QueueRow(
                // Keyed by position rather than by the entry: the same
                // track can legitimately sit in a queue twice, and two
                // identical `ValueKey`s make a reorder move the wrong row.
                key: ValueKey('queue-$playPosition-$entriesIndex'),
                index: playPosition,
                entry: entry,
                isCurrent: playPosition == currentPlayPosition,
                onTap: () => cubit.playAt(entriesIndex),
                onRemove: () => cubit.removeAt(entriesIndex),
              );
            },
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
          Icon(
            Icons.done_all_rounded,
            size: 16,
            color: t.colors.textSecondary,
          ),
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
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final QueueEntry entry;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

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
