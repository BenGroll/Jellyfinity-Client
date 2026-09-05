import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../app/playlists/PlaylistCurationService.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/MediaArtwork.dart';
import '../widgets/media_formatting.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
import '../widgets/playlist_add_flow.dart';
import 'media_detail_cubit.dart';

/// One album: its header, then its tracks.
///
/// The two load independently. The cover and title are on screen as soon
/// as the album itself is known, while a long track list is still coming
/// — and an album that loads with a broken track list is still an album,
/// which is the rule from `CONTEXT.md` about the twelve-track record with
/// one dead track.
class AlbumDetailPage extends StatelessWidget {
  const AlbumDetailPage({
    super.key,
    required this.albumId,
    this.detail,
    this.tracks,
  });

  final MediaId albumId;
  final AlbumDetailCubit? detail;
  final SongsCubit? tracks;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AlbumDetailCubit>(
          create: (_) => (detail ?? getIt<AlbumDetailCubit>())..open(albumId),
        ),
        BlocProvider<SongsCubit>(
          create: (_) => (tracks ?? getIt<SongsCubit>())..forAlbum(albumId),
        ),
      ],
      child: const _AlbumDetailView(),
    );
  }
}

class _AlbumDetailView extends StatelessWidget {
  const _AlbumDetailView();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocBuilder<AlbumDetailCubit, MediaDetailState<Album>>(
      builder: (context, header) {
        return AppScaffold(
          padded: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: header.item?.name,
          body: BlocBuilder<SongsCubit, PagedCollectionState<Track>>(
            builder: (context, state) {
              final cubit = context.read<SongsCubit>();
              return PagedCollectionView<Track>(
                state: state,
                headerSlivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
                      child: _AlbumHeader(state: header, tracks: state.items),
                    ),
                  ),
                ],
                skeleton: const MusicListSkeleton(itemCount: 8),
                emptyTitle: 'No songs on this album',
                emptyMessage:
                    'The album is in your library but has no playable '
                    'tracks on the server.',
                emptyIcon: Icons.music_off_outlined,
                onLoadMore: cubit.loadMore,
                onRefresh: () async {
                  await context.read<AlbumDetailCubit>().retry();
                  await cubit.refresh();
                },
                onRetry: cubit.reload,
                onRetryLoadMore: cubit.retryLoadMore,
                // A track the server could not describe keeps its place
                // in the running order, clearly marked.
                unavailableBuilder: (context, item) =>
                    UnavailableRow(item: item),
                itemBuilder: (context, track, index) => TrackRow(
                  track: track,
                  showArtwork: false,
                  position: track.trackNumber ?? index + 1,
                  markUnavailable: !state.isCached,
                  onTap:
                      track.availability == MediaAvailability.remoteUnavailable
                      ? null
                      : () => context.read<PlaybackCubit>().playNow(
                          state.items,
                          startIndex: index,
                        ),
                  onPlayNext:
                      track.availability == MediaAvailability.remoteUnavailable
                      ? null
                      : () => context.read<PlaybackCubit>().playNext(track),
                  onAddToQueue:
                      track.availability == MediaAvailability.remoteUnavailable
                      ? null
                      : () => context.read<PlaybackCubit>().addToQueue(track),
                  onAddToPlaylist:
                      track.availability == MediaAvailability.remoteUnavailable
                      ? null
                      : () => addToPlaylistFlow(
                          context,
                          add: (playlistId) => getIt<PlaylistCurationService>()
                              .addTrack(playlistId, track.id),
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Cover, title, credits and the line of facts an album card shows.
class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({required this.state, required this.tracks});

  final MediaDetailState<Album> state;

  /// The tracks loaded so far — enough to back the Play button without a
  /// second fetch. Bounded to what `PagedCollectionCubit` has already
  /// windowed in, same as every other screen here.
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final album = state.item;

    if (album == null) {
      final failure = state.failure;
      if (failure != null) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: t.spacing.lg),
          child: ErrorStateView.forFailure(
            failure,
            title: 'Album unavailable',
            onRetry: context.read<AlbumDetailCubit>().retry,
          ),
        );
      }
      return const MediaHeaderSkeleton();
    }

    final details = joinDetails([
      album.productionYear?.toString(),
      formatTrackCount(album.trackCount),
      album.duration == null ? null : formatRunningTime(album.duration!),
    ]);

    return Column(
      children: [
        SizedBox(height: t.spacing.sm),
        MediaArtwork(image: album.image, kind: MediaKind.album, size: 180),
        SizedBox(height: t.spacing.md),
        Text(
          album.name,
          textAlign: TextAlign.center,
          style: t.typography.titleLarge.copyWith(color: t.colors.textPrimary),
        ),
        if (album.artists.isNotEmpty) ...[
          SizedBox(height: t.spacing.xxs),
          Text(
            album.artists.display,
            textAlign: TextAlign.center,
            style: t.typography.bodyMedium.copyWith(color: t.colors.accent),
          ),
        ],
        if (details.isNotEmpty) ...[
          SizedBox(height: t.spacing.xxs),
          Text(
            details,
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
        ],
        SizedBox(height: t.spacing.md),
        if (tracks.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: t.spacing.sm,
            runSpacing: t.spacing.sm,
            children: [
              AppButton(
                label: 'Play',
                icon: Icons.play_arrow_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.read<PlaybackCubit>().playNow(
                  tracks,
                  startIndex: 0,
                ),
              ),
              AppButton(
                label: 'Add to Playlist',
                icon: Icons.playlist_add_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () => addToPlaylistFlow(
                  context,
                  add: (playlistId) => getIt<PlaylistCurationService>()
                      .addAlbum(playlistId, album.id),
                  successMessage: 'Album added to playlist.',
                ),
              ),
            ],
          ),
        SizedBox(height: t.spacing.md),
      ],
    );
  }
}
