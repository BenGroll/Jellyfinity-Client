import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../design/design.dart';
import '../../../domain/media/media.dart';
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
          body: entries.isEmpty
              ? const EmptyStateView(
                  title: 'The queue is empty',
                  message: 'Play something and it will show up here.',
                  icon: Icons.queue_music_rounded,
                )
              : ReorderableListView.builder(
                  itemCount: entries.length,
                  onReorderItem: cubit.reorder,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _QueueRow(
                      key: ValueKey(entry),
                      entry: entry,
                      isCurrent: index == state.queue.currentIndex,
                      onTap: () => cubit.playAt(index),
                      onRemove: () => cubit.removeAt(index),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required super.key,
    required this.entry,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
  });

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
