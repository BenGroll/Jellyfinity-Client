import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/downloads/DownloadsCubit.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/LibraryPage.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/download_controls.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
import 'music_search_cubit.dart';

/// Every match in one search category, paged.
///
/// The screen behind "Show all 412 songs". It is the ordinary library
/// list with a search term attached — same cubits, same paging, same
/// states — which is the reason search was modelled as a parameter on the
/// collection reads rather than as its own result type.
class SearchCategoryPage extends StatelessWidget {
  const SearchCategoryPage({
    super.key,
    required this.category,
    required this.query,
    this.artists,
    this.albums,
    this.songs,
    this.playlists,
  });

  final SearchCategory category;
  final String query;

  final ArtistsCubit? artists;
  final AlbumsCubit? albums;
  final SongsCubit? songs;
  final PlaylistsCubit? playlists;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padded: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      title: '${category.label} · "$query"',
      body: switch (category) {
        SearchCategory.artists => BlocProvider<ArtistsCubit>(
          create: (_) => (artists ?? getIt<ArtistsCubit>())..searchFor(query),
          child: const _ArtistResults(),
        ),
        SearchCategory.albums => BlocProvider<AlbumsCubit>(
          create: (_) => (albums ?? getIt<AlbumsCubit>())..searchFor(query),
          child: const _AlbumResults(),
        ),
        SearchCategory.songs => BlocProvider<SongsCubit>(
          create: (_) => (songs ?? getIt<SongsCubit>())..searchFor(query),
          child: const _SongResults(),
        ),
        SearchCategory.playlists => BlocProvider<PlaylistsCubit>(
          create: (_) =>
              (playlists ?? getIt<PlaylistsCubit>())..searchFor(query),
          child: const _PlaylistResults(),
        ),
      },
    );
  }
}

const String _noMatches = 'No matches';

class _ArtistResults extends StatelessWidget {
  const _ArtistResults();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArtistsCubit, PagedCollectionState<Artist>>(
      builder: (context, state) {
        final cubit = context.read<ArtistsCubit>();
        return PagedCollectionView<Artist>(
          state: state,
          skeleton: const MusicListSkeleton(circular: true),
          emptyTitle: _noMatches,
          emptyIcon: Icons.search_off_rounded,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          itemBuilder: (context, artist, _) => ArtistRow(
            artist: artist,
            onTap: () => context.pushNamed(
              RouteNames.libraryArtist,
              pathParameters: {'id': artist.id.key},
            ),
          ),
        );
      },
    );
  }
}

class _AlbumResults extends StatelessWidget {
  const _AlbumResults();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlbumsCubit, PagedCollectionState<Album>>(
      builder: (context, state) {
        final cubit = context.read<AlbumsCubit>();
        return PagedCollectionView<Album>(
          state: state,
          gridDelegate: albumGridDelegate,
          skeleton: const AlbumGridSkeleton(gridDelegate: albumGridDelegate),
          emptyTitle: _noMatches,
          emptyIcon: Icons.search_off_rounded,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          itemBuilder: (context, album, _) => AlbumTile(
            album: album,
            onTap: () => context.pushNamed(
              RouteNames.libraryAlbum,
              pathParameters: {'id': album.id.key},
            ),
          ),
        );
      },
    );
  }
}

class _SongResults extends StatelessWidget {
  const _SongResults();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SongsCubit, PagedCollectionState<Track>>(
      builder: (context, state) {
        final cubit = context.read<SongsCubit>();
        final catalog = context.watch<DownloadsCubit>().state;
        return PagedCollectionView<Track>(
          state: state,
          skeleton: const MusicListSkeleton(),
          emptyTitle: _noMatches,
          emptyIcon: Icons.search_off_rounded,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          unavailableBuilder: (context, item) => UnavailableRow(item: item),
          itemBuilder: (context, track, index) {
            final playable =
                track.availability != MediaAvailability.remoteUnavailable ||
                catalog.isDownloaded(track.id);
            return TrackRow(
              track: track,
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
                  track.availability == MediaAvailability.remoteUnavailable
                  ? null
                  : TrackDownloadButton(track: track),
            );
          },
        );
      },
    );
  }
}

class _PlaylistResults extends StatelessWidget {
  const _PlaylistResults();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaylistsCubit, PagedCollectionState<Playlist>>(
      builder: (context, state) {
        final cubit = context.read<PlaylistsCubit>();
        return PagedCollectionView<Playlist>(
          state: state,
          skeleton: const MusicListSkeleton(),
          emptyTitle: _noMatches,
          emptyIcon: Icons.search_off_rounded,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          itemBuilder: (context, playlist, _) => PlaylistRow(
            playlist: playlist,
            onTap: () => context.pushNamed(
              RouteNames.libraryPlaylist,
              pathParameters: {'id': playlist.id.key},
            ),
          ),
        );
      },
    );
  }
}
