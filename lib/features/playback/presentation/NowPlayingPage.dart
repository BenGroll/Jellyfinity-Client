import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/service_locator.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../app/router/route_paths.dart';
import '../../../app/settings/SettingsCubit.dart';
import '../../../design/design.dart';
import '../../../domain/media/media.dart';
import '../../../domain/playback/QueueEntry.dart';
import '../../../domain/playback/repeat_mode.dart';
import '../../../domain/playback/stream_quality.dart';
import '../../../domain/playback/TrackSourceInfo.dart';
import '../../music/presentation/widgets/MediaArtwork.dart';
import '../../music/presentation/widgets/media_formatting.dart';
import 'track_source_info_cubit.dart';

/// The full player: artwork, transport, seek, shuffle/repeat, and a way
/// into the queue. Reached by tapping [MiniPlayer]; a root route so it
/// covers the bottom nav from any tab.
class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackUiState>(
      builder: (context, state) {
        final entry = state.currentEntry;
        return AppScaffold(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.queue_music_rounded),
              onPressed: state.hasQueue
                  ? () => context.pushNamed(RouteNames.nowPlayingQueue)
                  : null,
            ),
          ],
          body: entry == null
              ? const EmptyStateView(
                  title: 'Nothing playing',
                  message: 'Play a song from your library to see it here.',
                  icon: Icons.music_note_outlined,
                )
              : _NowPlayingContent(entry: entry, state: state),
        );
      },
    );
  }
}

class _NowPlayingContent extends StatefulWidget {
  const _NowPlayingContent({required this.entry, required this.state});

  final QueueEntry entry;
  final PlaybackUiState state;

  @override
  State<_NowPlayingContent> createState() => _NowPlayingContentState();
}

class _NowPlayingContentState extends State<_NowPlayingContent> {
  late final TrackSourceInfoCubit _sourceInfo;

  @override
  void initState() {
    super.initState();
    _sourceInfo = getIt<TrackSourceInfoCubit>()..open(widget.entry.id);
  }

  @override
  void didUpdateWidget(covariant _NowPlayingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.id != oldWidget.entry.id) {
      _sourceInfo.open(widget.entry.id);
    }
  }

  @override
  void dispose() {
    unawaited(_sourceInfo.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cubit = context.read<PlaybackCubit>();
    final entry = widget.entry;
    final state = widget.state;

    return BlocProvider<TrackSourceInfoCubit>.value(
      value: _sourceInfo,
      child: Column(
        children: [
          SizedBox(height: t.spacing.lg),
          Expanded(
            child: Center(
              child: MediaArtwork(
                image: entry.image,
                kind: MediaKind.track,
                size: 280,
              ),
            ),
          ),
          SizedBox(height: t.spacing.xl),
          Text(
            entry.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.typography.titleLarge.copyWith(
              color: t.colors.textPrimary,
            ),
          ),
          if (entry.artist != null) ...[
            SizedBox(height: t.spacing.xxs),
            Text(
              entry.artist!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.bodyMedium.copyWith(
                color: t.colors.textSecondary,
              ),
            ),
          ],
          const _SourceQualityHint(),
          SizedBox(height: t.spacing.lg),
          _SeekBar(state: state),
          SizedBox(height: t.spacing.sm),
          _TransportRow(state: state, cubit: cubit),
          SizedBox(height: t.spacing.xl),
        ],
      ),
    );
  }
}

/// A small caption under the artist line: the source file's own format/
/// bitrate, and — when the active [StreamQuality] would actually need to
/// transcode it — what it is being transcoded to (ADR-0015).
class _SourceQualityHint extends StatelessWidget {
  const _SourceQualityHint();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final quality = context.watch<SettingsCubit>().state.streamQuality;

    return BlocBuilder<TrackSourceInfoCubit, TrackSourceInfoState>(
      builder: (context, state) {
        final info = state.info;
        if (info == null) return const SizedBox.shrink();

        final sourceHint = joinDetails([
          (info.codec ?? info.container)?.toUpperCase(),
          info.bitrateBps == null ? null : formatBitrate(info.bitrateBps!),
        ]);
        final transcodeHint = _isTranscoding(quality, info)
            ? 'Transcoding to ${StreamQuality.transcodeCodec.toUpperCase()} '
                  '· ${formatBitrate(quality.targetBitrateBps!)}'
            : null;
        final label = joinDetails([
          sourceHint.isEmpty ? null : sourceHint,
          transcodeHint,
        ]);
        if (label.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(top: t.spacing.xxs),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
        );
      },
    );
  }

  /// A client-side estimate of whether Jellyfin would actually transcode
  /// [info] to satisfy [quality], rather than a real answer from the
  /// server (that would need a `PlaybackInfo` negotiation round trip,
  /// out of scope per the roadmap's "use the existing streaming
  /// parameters" instruction — ADR-0015). A source already in the
  /// requested codec and at or under the target bitrate is assumed to
  /// stream/remux rather than transcode; this can be wrong at the
  /// margins.
  bool _isTranscoding(StreamQuality quality, TrackSourceInfo info) {
    final target = quality.targetBitrateBps;
    if (target == null) return false;
    final sameCodec = info.codec?.toLowerCase() == StreamQuality.transcodeCodec;
    final withinBitrate = info.bitrateBps != null && info.bitrateBps! <= target;
    return !(sameCodec && withinBitrate);
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.state});

  final PlaybackUiState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cubit = context.read<PlaybackCubit>();
    final duration = state.duration;
    final hasDuration = duration != null && duration > Duration.zero;
    final max = hasDuration ? duration.inMilliseconds.toDouble() : 1.0;
    final value = hasDuration
        ? state.position.inMilliseconds.toDouble().clamp(0.0, max)
        : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: t.colors.accent,
              inactiveTrackColor: t.colors.border,
              thumbColor: t.colors.accent,
            ),
            child: Slider(
              value: value,
              max: max,
              onChanged: hasDuration
                  ? (v) => cubit.seek(Duration(milliseconds: v.round()))
                  : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(state.position),
                style: t.typography.caption.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
              Text(
                hasDuration ? formatDuration(duration) : '--:--',
                style: t.typography.caption.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({required this.state, required this.cubit});

  final PlaybackUiState state;
  final PlaybackCubit cubit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repeatMode = state.queue.repeatMode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.shuffle_rounded),
          color: state.queue.shuffleEnabled
              ? t.colors.accent
              : t.colors.textSecondary,
          onPressed: state.hasQueue ? cubit.toggleShuffle : null,
        ),
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_previous_rounded),
          color: t.colors.textPrimary,
          onPressed: state.hasQueue ? cubit.previous : null,
        ),
        IconButton(
          iconSize: 64,
          icon: Icon(
            state.isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
          ),
          color: t.colors.accent,
          onPressed: state.hasQueue ? cubit.togglePlayPause : null,
        ),
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_next_rounded),
          color: t.colors.textPrimary,
          onPressed: state.hasQueue ? cubit.next : null,
        ),
        IconButton(
          icon: Icon(
            repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
          ),
          color: repeatMode == RepeatMode.off
              ? t.colors.textSecondary
              : t.colors.accent,
          onPressed: state.hasQueue
              ? () => cubit.setRepeatMode(_nextRepeatMode(repeatMode))
              : null,
        ),
      ],
    );
  }

  static RepeatMode _nextRepeatMode(RepeatMode current) => switch (current) {
    RepeatMode.off => RepeatMode.all,
    RepeatMode.all => RepeatMode.one,
    RepeatMode.one => RepeatMode.off,
  };
}
