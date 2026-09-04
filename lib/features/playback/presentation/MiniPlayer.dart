import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';
import '../../../domain/media/media.dart';
import '../../music/presentation/widgets/MediaArtwork.dart';

/// The persistent bar in [AppShell] above the bottom navigation — a
/// glance at what's playing and play/pause, from any tab. Renders
/// nothing when the queue is empty, so a user who has never played
/// anything sees no trace of a player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackUiState>(
      builder: (context, state) {
        final entry = state.currentEntry;
        if (entry == null) return const SizedBox.shrink();

        final t = context.tokens;
        final cubit = context.read<PlaybackCubit>();
        final duration = state.duration;
        final progress = (duration != null && duration > Duration.zero)
            ? (state.position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              )
            : 0.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: t.colors.surface,
            border: Border(top: BorderSide(color: t.colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(t.colors.accent),
                ),
              ),
              InkWell(
                onTap: () => context.pushNamed(RouteNames.nowPlaying),
                child: SizedBox(
                  height: height - 2,
                  child: Row(
                    children: [
                      SizedBox(width: t.spacing.sm),
                      MediaArtwork(
                        image: entry.image,
                        kind: MediaKind.track,
                        size: 40,
                      ),
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
                              style: t.typography.bodyMedium.copyWith(
                                color: t.colors.textPrimary,
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
                      IconButton(
                        icon: Icon(
                          state.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        color: t.colors.textPrimary,
                        onPressed: cubit.togglePlayPause,
                      ),
                      SizedBox(width: t.spacing.xxs),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
