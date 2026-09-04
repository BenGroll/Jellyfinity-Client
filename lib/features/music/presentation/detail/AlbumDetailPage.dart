import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/MediaArtwork.dart';
import '../widgets/media_formatting.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
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
                      child: _AlbumHeader(state: header),
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
  const _AlbumHeader({required this.state});

  final MediaDetailState<Album> state;

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
      ],
    );
  }
}
