import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/service_locator.dart';
import '../../../app/downloads/DownloadsCubit.dart';
import '../../../app/favorites/FavoritesRevisionCubit.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';
import '../../../domain/downloads/downloads.dart';
import '../../../domain/media/media.dart';
import '../../music/presentation/library/LibraryPage.dart'
    show albumGridDelegate;
import '../../music/presentation/library/paged_collection_cubit.dart';
import '../../music/presentation/widgets/downloaded_marker.dart';
import '../../music/presentation/widgets/MediaPlaybackActionsRow.dart';
import '../../music/presentation/widgets/music_rows.dart';
import '../../music/presentation/widgets/music_skeletons.dart';
import '../../music/presentation/widgets/paged_collection_view.dart';
import 'favorites_cubits.dart';

/// The Favorites destination (v0.3.4, ADR-0028): a bottom-nav section of
/// its own, scoped by the same media-type pill as Library — today always
/// Music — showing the artists, albums and songs the profile has starred,
/// in the three shapes people look for them.
///
/// Favorites can be set from Artist, Album and Now Playing (ADR-0019) and
/// then, until now, never browsed. Each tab is an ordinary paged
/// collection; the Songs tab is playable straight through, like a
/// playlist. When a favorite is toggled anywhere else in the app,
/// [FavoritesRevisionCubit] ticks and every tab re-reads.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key, this.artists, this.albums, this.songs});

  /// Injectable seams for widget tests; the graph supplies these in the
  /// app, the same pattern as [LibraryPage].
  final FavoriteArtistsCubit? artists;
  final FavoriteAlbumsCubit? albums;
  final FavoriteTracksCubit? songs;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FavoriteArtistsCubit>(
          create: (_) => (artists ?? getIt<FavoriteArtistsCubit>())..load(),
        ),
        BlocProvider<FavoriteAlbumsCubit>(
          create: (_) => (albums ?? getIt<FavoriteAlbumsCubit>())..load(),
        ),
        BlocProvider<FavoriteTracksCubit>(
          create: (_) => (songs ?? getIt<FavoriteTracksCubit>())..load(),
        ),
      ],
      child: const _FavoritesView(),
    );
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocListener<FavoritesRevisionCubit, int>(
      // A star toggled on any other screen: re-read every tab so the
      // destination is never out of step with the heart buttons.
      listenWhen: (previous, current) => current != previous,
      listener: (context, _) {
        context.read<FavoriteArtistsCubit>().refresh();
        context.read<FavoriteAlbumsCubit>().refresh();
        context.read<FavoriteTracksCubit>().refresh();
      },
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelColor: t.colors.textPrimary,
              unselectedLabelColor: t.colors.textSecondary,
              indicatorColor: t.colors.accent,
              dividerColor: t.colors.border,
              labelStyle: t.typography.titleMedium,
              tabs: const [
                Tab(text: 'Artists'),
                Tab(text: 'Albums'),
                Tab(text: 'Songs'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _FavoriteArtistsTab(),
                  _FavoriteAlbumsTab(),
                  _FavoriteSongsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteArtistsTab extends StatefulWidget {
  const _FavoriteArtistsTab();

  @override
  State<_FavoriteArtistsTab> createState() => _FavoriteArtistsTabState();
}

class _FavoriteArtistsTabState extends State<_FavoriteArtistsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<FavoriteArtistsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<FavoriteArtistsCubit, PagedCollectionState<Artist>>(
      builder: (context, state) {
        final cubit = context.read<FavoriteArtistsCubit>();
        final catalog = context.watch<DownloadsCubit>().state;
        return PagedCollectionView<Artist>(
          key: const PageStorageKey('favorites.artists'),
          state: state,
          skeleton: const MusicListSkeleton(circular: true),
          emptyTitle: 'No favorite artists yet',
          emptyMessage:
              'Tap the heart on an artist and they show up here, ready '
              'to open again.',
          emptyIcon: Icons.favorite_border_rounded,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          itemBuilder: (context, artist, _) => ArtistRow(
            artist: artist,
            downloaded: DownloadedMarker.warranted(
              catalog.statusFor(DownloadOwner.artist(artist.id)),
            ),
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

class _FavoriteAlbumsTab extends StatefulWidget {
  const _FavoriteAlbumsTab();

  @override
  State<_FavoriteAlbumsTab> createState() => _FavoriteAlbumsTabState();
}

class _FavoriteAlbumsTabState extends State<_FavoriteAlbumsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<FavoriteAlbumsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<FavoriteAlbumsCubit, PagedCollectionState<Album>>(
      builder: (context, state) {
        final cubit = context.read<FavoriteAlbumsCubit>();
        final catalog = context.watch<DownloadsCubit>().state;
        return PagedCollectionView<Album>(
          key: const PageStorageKey('favorites.albums'),
          state: state,
          gridDelegate: albumGridDelegate,
          skeleton: const AlbumGridSkeleton(gridDelegate: albumGridDelegate),
          emptyTitle: 'No favorite albums yet',
          emptyMessage:
              'Tap the heart on an album and it shows up here, ready to '
              'play again.',
          emptyIcon: Icons.favorite_border_rounded,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          itemBuilder: (context, album, _) => AlbumTile(
            album: album,
            markUnavailable: !state.isCached,
            downloaded: DownloadedMarker.warranted(
              catalog.statusFor(DownloadOwner.album(album.id)),
            ),
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

class _FavoriteSongsTab extends StatefulWidget {
  const _FavoriteSongsTab();

  @override
  State<_FavoriteSongsTab> createState() => _FavoriteSongsTabState();
}

class _FavoriteSongsTabState extends State<_FavoriteSongsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<FavoriteTracksCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<FavoriteTracksCubit, PagedCollectionState<Track>>(
      builder: (context, state) {
        final cubit = context.read<FavoriteTracksCubit>();
        final catalog = context.watch<DownloadsCubit>().state;
        return PagedCollectionView<Track>(
          key: const PageStorageKey('favorites.songs'),
          state: state,
          skeleton: const MusicListSkeleton(),
          emptyTitle: 'No favorite songs yet',
          emptyMessage:
              'Tap the heart in the player, or on a song, and it joins '
              'this list — playable straight through, like a playlist.',
          emptyIcon: Icons.favorite_border_rounded,
          // The whole favorite-songs list is one thing to play: Play and
          // Shuffle sit above it, like a playlist header.
          headerSlivers: [
            if (state.isReady && state.items.isNotEmpty)
              SliverToBoxAdapter(
                child: MediaPlaybackActionsRow(tracks: state.items),
              ),
          ],
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          unavailableBuilder: (context, item) => UnavailableRow(item: item),
          itemBuilder: (context, track, index) {
            // A favorite the server no longer lists still plays if its
            // file is on the device (v0.2.3) — the same rule the Library
            // and search song lists follow.
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
            );
          },
        );
      },
    );
  }
}
