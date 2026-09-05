import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../infrastructure/artwork/ArtworkCache.dart';
import '../../music/presentation/widgets/FavoriteButton.dart';
import '../../music/presentation/widgets/MediaArtwork.dart';
import '../../music/presentation/widgets/media_formatting.dart';
import '../../music/presentation/widgets/music_rows.dart';
import 'now_playing_details_cubit.dart';
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
        return entry == null
            ? AppScaffold(
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  onPressed: () => context.pop(),
                ),
                body: const EmptyStateView(
                  title: 'Nothing playing',
                  message: 'Play a song from your library to see it here.',
                  icon: Icons.music_note_outlined,
                ),
              )
            : _NowPlayingContent(entry: entry, state: state);
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
  late final NowPlayingDetailsCubit _details;

  @override
  void initState() {
    super.initState();
    _sourceInfo = getIt<TrackSourceInfoCubit>()..open(widget.entry.id);
    _details = getIt<NowPlayingDetailsCubit>()..open(widget.entry.id);
  }

  @override
  void didUpdateWidget(covariant _NowPlayingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.id != oldWidget.entry.id) {
      _sourceInfo.open(widget.entry.id);
      _details.open(widget.entry.id);
    }
  }

  @override
  void dispose() {
    unawaited(_sourceInfo.close());
    unawaited(_details.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cubit = context.read<PlaybackCubit>();
    final entry = widget.entry;
    final state = widget.state;

    return MultiBlocProvider(
      providers: [
        BlocProvider<TrackSourceInfoCubit>.value(value: _sourceInfo),
        BlocProvider<NowPlayingDetailsCubit>.value(value: _details),
      ],
      child: AppScaffold(
        padded: false,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => context.pop(),
        ),
        // Lyrics and Queue are folded into the overflow sheet below
        // (v0.1.6) rather than each keeping their own app bar icon; the
        // heart moves down next to the title instead of living up here.
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onPressed: () => showTrackActionsSheet(
              context,
              onPlayNext: () => cubit.playNextEntry(entry),
              onAddToQueue: () => cubit.addEntryToQueue(entry),
              onLyrics: () => context.pushNamed(RouteNames.nowPlayingLyrics),
              onOpenQueue: state.hasQueue
                  ? () => context.pushNamed(RouteNames.nowPlayingQueue)
                  : null,
            ),
          ),
        ],
        body: Stack(
          fit: StackFit.expand,
          children: [
            _BlurredBackground(image: entry.image),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          entry.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.typography.headlineLarge.copyWith(
                            color: t.colors.textPrimary,
                          ),
                        ),
                      ),
                      BlocBuilder<
                        NowPlayingDetailsCubit,
                        NowPlayingDetailsState
                      >(
                        builder: (context, details) {
                          final track = details.track;
                          if (track == null) return const SizedBox.shrink();
                          return Padding(
                            padding: EdgeInsets.only(left: t.spacing.xs),
                            child: FavoriteButton(
                              isFavorite: track.isFavorite,
                              onChanged: (favorite) async {
                                final result =
                                    await getIt<FavoritesRepository>()
                                        .setFavorite(
                                          track.id,
                                          favorite: favorite,
                                        );
                                return result.isOk;
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _ArtistAlbumLinks(entry: entry),
                  const _SourceQualityRow(),
                  SizedBox(height: t.spacing.lg),
                  _SeekBar(state: state),
                  SizedBox(height: t.spacing.sm),
                  _TransportRow(state: state, cubit: cubit),
                  SizedBox(height: t.spacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A heavily blurred, scaled-up copy of the current artwork behind the
/// whole player (v0.1.6) — "just display a very blurred version of the
/// artwork" from the roadmap, rather than sampling a dominant color.
/// `null` artwork (or one that fails to resolve/load) leaves the plain
/// theme background untouched instead of showing a broken image.
class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({required this.image});

  final MediaImage? image;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final source = image;
    if (source == null) return ColoredBox(color: t.colors.background);

    final url = getIt<ArtworkResolver>().imageUrl(source, maxWidth: 400);
    if (url == null) return ColoredBox(color: t.colors.background);

    return ColoredBox(
      color: t.colors.background,
      child: ImageFiltered(
        // Strong enough that the foreground text stays readable over any
        // artwork (v0.1.6 feedback: the original 50-sigma blur still left
        // enough detail to compete with the title/transport controls).
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Transform.scale(
          // Blurring pulls the image's own edge color inward; scaling up
          // keeps that edge outside the visible bounds.
          scale: 1.6,
          child: CachedNetworkImage(
            imageUrl: url.toString(),
            cacheManager: ArtworkCache.instance,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            placeholder: (context, _) => const SizedBox.shrink(),
            errorWidget: (context, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// The artist and album lines under the title (v0.1.6), each opening its
/// page when the current track's full record is known to have one.
/// Before that record loads — or offline, where it never will — this
/// falls back to the queue snapshot's plain text, exactly as it always
/// rendered.
class _ArtistAlbumLinks extends StatelessWidget {
  const _ArtistAlbumLinks({required this.entry});

  final QueueEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocBuilder<NowPlayingDetailsCubit, NowPlayingDetailsState>(
      builder: (context, details) {
        final track = details.track;
        final artist = track?.artists.primary;
        final album = track?.albumId;

        final artistText = entry.artist;
        if (artistText == null && album == null) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(top: t.spacing.xxs),
          child: Column(
            children: [
              if (artistText != null)
                _LinkOrText(
                  text: artistText,
                  style: t.typography.bodyLarge,
                  color: t.colors.textSecondary,
                  linkColor: t.colors.accent,
                  onTap: artist != null && artist.isNavigable
                      ? () => _openLibraryRoute(
                          context,
                          RouteNames.libraryArtist,
                          artist.id!.key,
                        )
                      : null,
                ),
              if (entry.albumName != null)
                _LinkOrText(
                  text: entry.albumName!,
                  style: t.typography.bodyMedium,
                  color: t.colors.textSecondary,
                  linkColor: t.colors.accent,
                  onTap: album != null
                      ? () => _openLibraryRoute(
                          context,
                          RouteNames.libraryAlbum,
                          album.key,
                        )
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Closes Now Playing before opening a library page (v0.1.6's artist/
/// album links).
///
/// Now Playing is a root route, sitting outside the shell's own
/// navigator; the artist and album pages it links to are nested inside
/// the shell's Library branch. Pushing a shell-nested route directly from
/// a root route confuses `go_router`'s per-navigator page-key bookkeeping
/// once the branch's own stack already exists (a `!keyReservation
/// .contains(key)` assertion in Flutter's `Navigator`). Dismissing back to
/// the shell first — the same "tap an artist from the full-screen player"
/// behavior most music apps already have — sidesteps that rather than
/// pushing across navigators.
void _openLibraryRoute(BuildContext context, String routeName, String id) {
  final router = GoRouter.of(context);
  context.pop();
  router.pushNamed(routeName, pathParameters: {'id': id});
}

class _LinkOrText extends StatelessWidget {
  const _LinkOrText({
    required this.text,
    required this.style,
    required this.color,
    required this.linkColor,
    this.onTap,
  });

  final String text;
  final TextStyle style;
  final Color color;

  /// Signals "tappable" through color alone — no underline, which reads
  /// as noisy once a name is already accent-colored (v0.1.6).
  final Color linkColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: onTap == null ? color : linkColor),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// The source file's own format/bitrate, stacked on the left, and a badge
/// on the right naming either "Lossless" or the transcode target — the
/// v0.1.6 restyle of the single-line hint ADR-0015 shipped.
class _SourceQualityRow extends StatelessWidget {
  const _SourceQualityRow();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final quality = context.watch<SettingsCubit>().state.streamQuality;

    return BlocBuilder<TrackSourceInfoCubit, TrackSourceInfoState>(
      builder: (context, state) {
        final info = state.info;
        if (info == null) return const SizedBox.shrink();

        final format = (info.codec ?? info.container)?.toUpperCase();
        final bitrate = info.bitrateBps == null
            ? null
            : formatBitrate(info.bitrateBps!);
        if (format == null && bitrate == null) return const SizedBox.shrink();

        final transcoding = _isTranscoding(quality, info);
        final badgeLabel = transcoding
            ? '${StreamQuality.transcodeCodec.toUpperCase()} · '
                  '${formatBitrate(quality.targetBitrateBps!)}'
            : 'Lossless';

        return Padding(
          padding: EdgeInsets.only(top: t.spacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (format != null)
                      Text(
                        format,
                        style: t.typography.caption.copyWith(
                          color: t.colors.textSecondary,
                        ),
                      ),
                    if (bitrate != null)
                      Text(
                        bitrate,
                        style: t.typography.caption.copyWith(
                          color: t.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              _QualityBadge(label: badgeLabel, isLossless: !transcoding),
            ],
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

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.label, required this.isLossless});

  final String label;
  final bool isLossless;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = isLossless ? t.colors.accent : t.colors.textSecondary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.sm,
        vertical: t.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(t.radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: t.typography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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

    return Column(
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
