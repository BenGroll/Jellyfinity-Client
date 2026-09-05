import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../design/design.dart';
import '../../../domain/media/media.dart';
import '../../../domain/playback/PlaybackQueue.dart';
import '../../../domain/playback/QueueEntry.dart';
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
          body: entries.isEmpty
              ? const EmptyStateView(
                  title: 'The queue is empty',
                  message: 'Play something and it will show up here.',
                  icon: Icons.queue_music_rounded,
                )
              : Column(
                  children: [
                    _QueueRuntimeHeader(queue: state.queue),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: entries.length,
                        onReorderItem: cubit.reorder,
                        // Only the handle icon starts a drag (v0.1.6);
                        // the rest of the row keeps its normal tap-to-play.
                        buildDefaultDragHandles: false,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return _QueueRow(
                            key: ValueKey(entry),
                            index: index,
                            entry: entry,
                            isCurrent: index == state.queue.currentIndex,
                            onTap: () => cubit.playAt(index),
                            onRemove: () => cubit.removeAt(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
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
    final unavailable =
        entry.availability == MediaAvailability.remoteUnavailable;

    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.xxs,
      ),
      child: SizedBox(
        height: 64,
        child: InkWell(
          onTap: unavailable ? null : onTap,
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
                    if (entry.artist != null)
                      Text(
                        entry.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.typography.caption.copyWith(
                          color: t.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
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
