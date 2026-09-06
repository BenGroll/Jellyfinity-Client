import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/downloads/DownloadsCubit.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../design/design.dart';
import '../../../../domain/downloads/downloads.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/download_controls.dart';
import '../widgets/MediaArtwork.dart';
import '../widgets/MediaPlaybackActionsRow.dart';
import '../widgets/media_formatting.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
import 'media_detail_cubit.dart';

/// One playlist, in the order the user arranged it.
///
/// Position numbers come from the list, not from the tracks: a playlist
/// entry that is not a song, or no longer in the library, still occupies
/// its number here. Renumbering around it would quietly change the
/// playlist the user made.
class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    this.detail,
    this.tracks,
  });

  final MediaId playlistId;
  final PlaylistDetailCubit? detail;
  final PlaylistTracksCubit? tracks;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PlaylistDetailCubit>(
          create: (_) =>
              (detail ?? getIt<PlaylistDetailCubit>())..open(playlistId),
        ),
        BlocProvider<PlaylistTracksCubit>(
          create: (_) =>
              (tracks ?? getIt<PlaylistTracksCubit>())..forPlaylist(playlistId),
        ),
      ],
      child: const _PlaylistDetailView(),
    );
  }
}

class _PlaylistDetailView extends StatefulWidget {
  const _PlaylistDetailView();

  @override
  State<_PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<_PlaylistDetailView> {
  /// Reconcile-on-open runs at most once per visit (v0.2.1): opening a
  /// downloaded playlist online is one of the two triggers `ROADMAP.md`
  /// names for reconciling its membership against the server.
  bool _reconciled = false;

  void _maybeReconcile() {
    if (_reconciled) return;

    final tracks = context.read<PlaylistTracksCubit>().state;
    if (!tracks.isReady || tracks.isCached) return;

    final catalog = context.read<DownloadsCubit>().state;
    final playlist = context.read<PlaylistDetailCubit>().state.item;
    if (playlist == null || !catalog.isPlaylistDownloaded(playlist.id)) return;

    _reconciled = true;
    final messenger = ScaffoldMessenger.of(context);
    context.read<DownloadsCubit>().reconcilePlaylist(playlist.id).then((
      change,
    ) {
      if (!mounted || change.isEmpty) return;
      messenger.showSnackBar(
        SnackBar(content: Text(describePlaylistDownloadChange(change))),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocConsumer<PlaylistDetailCubit, MediaDetailState<Playlist>>(
      listener: (context, header) => _maybeReconcile(),
      builder: (context, header) {
        return AppScaffold(
          padded: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: header.item?.name,
          body: BlocConsumer<PlaylistTracksCubit, PagedCollectionState<Track>>(
            listener: (context, state) => _maybeReconcile(),
            builder: (context, state) {
              final cubit = context.read<PlaylistTracksCubit>();
              final catalog = context.watch<DownloadsCubit>().state;
              return PagedCollectionView<Track>(
                state: state,
                headerSlivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
                      child: _PlaylistHeader(
                        state: header,
                        tracks: state.items,
                      ),
                    ),
                  ),
                ],
                skeleton: const MusicListSkeleton(itemCount: 8),
                emptyTitle: 'This playlist is empty',
                emptyIcon: Icons.queue_music_outlined,
                onLoadMore: cubit.loadMore,
                onRefresh: () async {
                  await context.read<PlaylistDetailCubit>().retry();
                  await cubit.refresh();
                },
                onRetry: cubit.reload,
                onRetryLoadMore: cubit.retryLoadMore,
                offlineGapNoun: 'song',
                unavailableBuilder: (context, item) =>
                    UnavailableRow(item: item),
                itemBuilder: (context, track, index) {
                  final playable =
                      track.availability !=
                          MediaAvailability.remoteUnavailable ||
                      catalog.isDownloaded(track.id);
                  return TrackRow(
                    track: track,
                    showArtwork: false,
                    position: index + 1,
                    playable: playable,
                    onTap: playable
                        ? () => context.read<PlaybackCubit>().playNow(
                            state.items,
                            startIndex: index,
                          )
                        : null,
                    onPlayNext: playable
                        ? () => context.read<PlaybackCubit>().playNext(track)
                        : null,
                    onAddToQueue: playable
                        ? () => context.read<PlaybackCubit>().addToQueue(track)
                        : null,
                    downloadAction:
                        track.availability ==
                            MediaAvailability.remoteUnavailable
                        ? null
                        : TrackDownloadButton(track: track),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({required this.state, required this.tracks});

  final MediaDetailState<Playlist> state;

  /// The tracks loaded so far — enough to back the Play button without a
  /// second fetch.
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final playlist = state.item;

    if (playlist == null) {
      final failure = state.failure;
      if (failure != null) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: t.spacing.lg),
          child: ErrorStateView.forFailure(
            failure,
            title: 'Playlist unavailable',
            onRetry: context.read<PlaylistDetailCubit>().retry,
          ),
        );
      }
      return const MediaHeaderSkeleton();
    }

    final details = joinDetails([
      formatTrackCount(playlist.itemCount),
      playlist.duration == null ? null : formatRunningTime(playlist.duration!),
    ]);

    return Column(
      children: [
        SizedBox(height: t.spacing.sm),
        MediaArtwork(
          image: playlist.image,
          kind: MediaKind.playlist,
          size: 180,
        ),
        SizedBox(height: t.spacing.md),
        Text(
          playlist.name,
          textAlign: TextAlign.center,
          style: t.typography.titleLarge.copyWith(color: t.colors.textPrimary),
        ),
        if (details.isNotEmpty) ...[
          SizedBox(height: t.spacing.xxs),
          Text(
            details,
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
        ],
        Builder(
          builder: (context) {
            final catalog = context.watch<DownloadsCubit>().state;
            if (!catalog.isPlaylistDownloaded(playlist.id)) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.only(top: t.spacing.xxs),
              child: CollectionDownloadSummary(
                status: catalog.statusFor(DownloadOwner.playlist(playlist.id)),
              ),
            );
          },
        ),
        SizedBox(height: t.spacing.md),
        MediaPlaybackActionsRow(
          tracks: tracks,
          download: PlaylistDownloadButton(playlist: playlist),
        ),
        SizedBox(height: t.spacing.md),
      ],
    );
  }
}
