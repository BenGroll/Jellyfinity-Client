import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/MusicPage.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/MediaArtwork.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
import 'media_detail_cubit.dart';

/// One artist: who they are, then what they released, newest release
/// order last — the discography a music app opens an artist for.
class ArtistDetailPage extends StatelessWidget {
  const ArtistDetailPage({
    super.key,
    required this.artistId,
    this.detail,
    this.albums,
  });

  final MediaId artistId;
  final ArtistDetailCubit? detail;
  final AlbumsCubit? albums;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ArtistDetailCubit>(
          create: (_) => (detail ?? getIt<ArtistDetailCubit>())..open(artistId),
        ),
        BlocProvider<AlbumsCubit>(
          create: (_) => (albums ?? getIt<AlbumsCubit>())..forArtist(artistId),
        ),
      ],
      child: const _ArtistDetailView(),
    );
  }
}

class _ArtistDetailView extends StatelessWidget {
  const _ArtistDetailView();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocBuilder<ArtistDetailCubit, MediaDetailState<Artist>>(
      builder: (context, header) {
        return AppScaffold(
          padded: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: header.item?.name,
          body: BlocBuilder<AlbumsCubit, PagedCollectionState<Album>>(
            builder: (context, state) {
              final cubit = context.read<AlbumsCubit>();
              return PagedCollectionView<Album>(
                state: state,
                gridDelegate: albumGridDelegate,
                headerSlivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
                      child: _ArtistHeader(state: header),
                    ),
                  ),
                ],
                skeleton: const AlbumGridSkeleton(
                  gridDelegate: albumGridDelegate,
                  itemCount: 6,
                ),
                emptyTitle: 'No albums for this artist',
                emptyMessage:
                    'Your server lists the artist but no albums under '
                    'them.',
                emptyIcon: Icons.album_outlined,
                onLoadMore: cubit.loadMore,
                onRefresh: () async {
                  await context.read<ArtistDetailCubit>().retry();
                  await cubit.refresh();
                },
                onRetry: cubit.reload,
                onRetryLoadMore: cubit.retryLoadMore,
                itemBuilder: (context, album, _) => AlbumTile(
                  album: album,
                  markUnavailable: !state.isCached,
                  onTap: () => context.pushNamed(
                    RouteNames.musicAlbum,
                    pathParameters: {'id': album.id.key},
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

class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({required this.state});

  final MediaDetailState<Artist> state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final artist = state.item;

    if (artist == null) {
      final failure = state.failure;
      if (failure != null) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: t.spacing.lg),
          child: ErrorStateView.forFailure(
            failure,
            title: 'Artist unavailable',
            onRetry: context.read<ArtistDetailCubit>().retry,
          ),
        );
      }
      return const MediaHeaderSkeleton(artworkSize: 140);
    }

    return Column(
      children: [
        SizedBox(height: t.spacing.sm),
        MediaArtwork(
          image: artist.image,
          kind: MediaKind.artist,
          size: 140,
          shape: ArtworkShape.circle,
        ),
        SizedBox(height: t.spacing.md),
        Text(
          artist.name,
          textAlign: TextAlign.center,
          style: t.typography.titleLarge.copyWith(color: t.colors.textPrimary),
        ),
        SizedBox(height: t.spacing.md),
      ],
    );
  }
}
