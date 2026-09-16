import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/connected_playback/PlaybackControlCubit.dart';
import '../../../app/connectivity/OfflineCubit.dart';
import '../../../app/di/service_locator.dart';
import '../../../app/downloads/DownloadsCubit.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';
import '../../../domain/connected_playback/remote_command_kind.dart';
import '../../../domain/media/media.dart';
import '../../../domain/playback/QueueEntry.dart';
import '../../music/presentation/widgets/ArtworkBackground.dart';
import '../../music/presentation/widgets/downloaded_marker.dart';
import '../../music/presentation/widgets/MediaArtwork.dart';
import 'DevicePickerSheet.dart';

/// The persistent bar in [AppShell] above the bottom navigation — a
/// glance at what's playing and play/pause, from any tab.
///
/// Bound to `PlaybackControlCubit` first (v0.5.6): while this device is
/// controlling another one, this bar shows that device's projection
/// instead of local `PlaybackCubit` state, and never the other way
/// around — the "one presentation contract" the roadmap asks for. Renders
/// nothing when there is nothing to show either way, so a user who has
/// never played anything and is not controlling anything sees no trace of
/// a player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackControlCubit, PlaybackControlState>(
      bloc: getIt<PlaybackControlCubit>(),
      builder: (context, control) {
        if (control.isControlling) {
          return _RemoteMiniPlayer(control: control);
        }
        return BlocBuilder<PlaybackCubit, PlaybackUiState>(
          builder: (context, state) {
            final entry = state.currentEntry;
            if (entry == null) return const SizedBox.shrink();
            return _MiniPlayerBar(
              image: entry.image,
              child: _LocalMiniPlayerRow(entry: entry, state: state),
            );
          },
        );
      },
    );
  }
}

/// The chrome every mini-player state shares: artwork backdrop, top
/// progress line, and the fixed height [AppShell] reserves for it.
class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({required this.image, required this.child});

  final MediaImage? image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: MiniPlayer.height,
      child: ArtworkBackground(
        image: image,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.colors.border)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LocalMiniPlayerRow extends StatelessWidget {
  const _LocalMiniPlayerRow({required this.entry, required this.state});

  final QueueEntry entry;
  final PlaybackUiState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cubit = context.read<PlaybackCubit>();
    final downloaded = context.select<DownloadsCubit, bool>(
      (downloads) => downloads.state.isDownloaded(entry.id),
    );
    final offline = context.select<OfflineCubit, bool>(
      (offlineCubit) => offlineCubit.state.isOffline,
    );
    final notPlayableOffline = offline && !downloaded;
    final duration = state.duration;
    final progress = (duration != null && duration > Duration.zero)
        ? (state.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Column(
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
            height: MiniPlayer.height - 2,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.typography.bodyMedium.copyWith(
                                color: notPlayableOffline
                                    ? t.colors.textSecondary
                                    : t.colors.textPrimary,
                              ),
                            ),
                          ),
                          if (downloaded) ...[
                            SizedBox(width: t.spacing.xxs),
                            const DownloadedMarker.inline(size: 13),
                          ],
                        ],
                      ),
                      if (notPlayableOffline || entry.artist != null)
                        Text(
                          notPlayableOffline
                              ? 'Not available offline'
                              : entry.artist!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.typography.caption.copyWith(
                            color: t.colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                DeviceActionButton(iconSize: 20, color: t.colors.textSecondary),
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
    );
  }
}

/// The mini-player while this device is controlling another one (v0.5.6).
/// Shown even with an idle target ("Nothing playing on Living Room") — the
/// listener chose to control this device and deserves that state named
/// rather than the bar quietly vanishing.
class _RemoteMiniPlayer extends StatelessWidget {
  const _RemoteMiniPlayer({required this.control});

  final PlaybackControlState control;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final entry = control.currentEntry;
    final duration = control.duration;
    final progress = (duration != null && duration > Duration.zero)
        ? (control.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final subtitle =
        _connectionSubtitle(control) ??
        'Playing on ${control.device!.displayName}…';
    final canTogglePlay = control.commandAvailable(RemoteCommandKind.playPause);

    return _MiniPlayerBar(
      image: entry?.image,
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
              height: MiniPlayer.height - 2,
              child: Row(
                children: [
                  SizedBox(width: t.spacing.sm),
                  MediaArtwork(
                    image: entry?.image,
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
                          (entry == null
                              ? 'Nothing playing'
                              : entry.artist == null
                              ? entry.title
                              : '${entry.artist} • ${entry.title}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.typography.bodyMedium.copyWith(
                            color: t.colors.textPrimary,
                          ),
                        ),
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
                  DeviceActionButton(
                    iconSize: 20,
                    color: t.colors.textSecondary,
                  ),
                  IconButton(
                    icon: Icon(
                      control.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    color: t.colors.textPrimary,
                    onPressed: canTogglePlay
                        ? () => getIt<PlaybackControlCubit>().togglePlayPause()
                        : null,
                  ),
                  SizedBox(width: t.spacing.xxs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-line explanation for a connection state that is not simply
/// "synced", or `null` when the device's own name is the more useful
/// thing to show.
String? _connectionSubtitle(PlaybackControlState control) =>
    switch (control.connection) {
      PlaybackControlConnection.synced => null,
      PlaybackControlConnection.resynchronizing => 'Syncing…',
      PlaybackControlConnection.reconnecting => 'Reconnecting…',
      PlaybackControlConnection.targetEnded => 'No longer available',
    };
