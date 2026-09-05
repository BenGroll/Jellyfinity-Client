import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../widgets/download_controls.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
import 'music_collection_cubits.dart';
import 'paged_collection_cubit.dart';

/// The Library tab, scoped to whichever media-type pill is active
/// (`MediaScopeCubit`) — today always Music, so this is the library in the
/// four shapes people look for it in.
///
/// Each tab is an independent paged collection with its own cubit, all
/// four created once for the page so switching tabs does not re-ask the
/// server for a list the user was already looking at. Nothing is loaded
/// until its tab is first opened. Its own title bar and search action are
/// gone as of ADR-0014 — `HomeLibraryHeader` (shared across every shell
/// tab) provides both now.
class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    this.artists,
    this.albums,
    this.songs,
    this.playlists,
  });

  // Injectable seams for widget tests; the graph supplies these in the
  // app, the same pattern as AccountsPage.
  final ArtistsCubit? artists;
  final AlbumsCubit? albums;
  final SongsCubit? songs;
  final PlaylistsCubit? playlists;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ArtistsCubit>(
          create: (_) => artists ?? getIt<ArtistsCubit>(),
        ),
        BlocProvider<AlbumsCubit>(
          create: (_) => albums ?? getIt<AlbumsCubit>(),
        ),
        BlocProvider<SongsCubit>(create: (_) => songs ?? getIt<SongsCubit>()),
        BlocProvider<PlaylistsCubit>(
          create: (_) => playlists ?? getIt<PlaylistsCubit>(),
        ),
      ],
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  bool _downloadedOnly = false;

  void _setDownloadedOnly(bool value) {
    setState(() => _downloadedOnly = value);
    context.read<ArtistsCubit>().showDownloadedOnly(value);
    context.read<AlbumsCubit>().showDownloadedOnly(value);
    context.read<SongsCubit>().showDownloadedOnly(value);
    context.read<PlaylistsCubit>().showDownloadedOnly(value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                t.spacing.md,
                t.spacing.xs,
                t.spacing.md,
                t.spacing.xs,
              ),
              child: FilterChip(
                label: const Text('Downloaded'),
                avatar: Icon(
                  Icons.download_done_rounded,
                  size: 18,
                  color: _downloadedOnly
                      ? t.colors.accent
                      : t.colors.textSecondary,
                ),
                selected: _downloadedOnly,
                onSelected: _setDownloadedOnly,
                tooltip: 'Show only music kept on this device',
              ),
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: t.colors.textPrimary,
            unselectedLabelColor: t.colors.textSecondary,
            indicatorColor: t.colors.accent,
            dividerColor: t.colors.border,
            labelStyle: t.typography.titleMedium,
            tabs: const [
              Tab(text: 'Artists'),
              Tab(text: 'Albums'),
              Tab(text: 'Songs'),
              Tab(text: 'Playlists'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [ArtistsTab(), AlbumsTab(), SongsTab(), PlaylistsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The layout every album grid uses — the real one and its skeleton — so
/// the content lands exactly where the placeholders were.
///
/// Sized by a maximum tile width rather than a column count, so a phone
/// gets two or three columns and a tablet gets more without a breakpoint
/// table.
const SliverGridDelegate albumGridDelegate =
    SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 190,
      childAspectRatio: 0.74,
      crossAxisSpacing: 12,
      mainAxisSpacing: 16,
    );

/// Every album artist in the library.
class ArtistsTab extends StatefulWidget {
  const ArtistsTab({super.key});

  @override
  State<ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<ArtistsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<ArtistsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<ArtistsCubit, PagedCollectionState<Artist>>(
      builder: (context, state) {
        final cubit = context.read<ArtistsCubit>();
        return PagedCollectionView<Artist>(
          key: const PageStorageKey('music.artists'),
          state: state,
          skeleton: const MusicListSkeleton(circular: true),
          emptyTitle: 'No artists yet',
          emptyMessage:
              'Once your Jellyfin server has scanned some music, your '
              'artists will appear here.',
          emptyIcon: Icons.person_outline_rounded,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          itemBuilder: (context, artist, _) => ArtistRow(
            artist: artist,
            markUnavailable: !state.isCached,
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

/// Every album in the library.
class AlbumsTab extends StatefulWidget {
  const AlbumsTab({super.key});

  @override
  State<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<AlbumsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<AlbumsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<AlbumsCubit, PagedCollectionState<Album>>(
      builder: (context, state) {
        final cubit = context.read<AlbumsCubit>();
        return PagedCollectionView<Album>(
          key: const PageStorageKey('music.albums'),
          state: state,
          gridDelegate: albumGridDelegate,
          skeleton: const AlbumGridSkeleton(gridDelegate: albumGridDelegate),
          emptyTitle: 'No albums yet',
          emptyMessage: 'Albums appear here once your library has some.',
          emptyIcon: Icons.album_outlined,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          itemBuilder: (context, album, _) => AlbumTile(
            album: album,
            markUnavailable: !state.isCached,
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

/// Every song in the library — the tab that has to survive 130k rows.
class SongsTab extends StatefulWidget {
  const SongsTab({super.key});

  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<SongsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<SongsCubit, PagedCollectionState<Track>>(
      builder: (context, state) {
        final cubit = context.read<SongsCubit>();
        return PagedCollectionView<Track>(
          key: const PageStorageKey('music.songs'),
          state: state,
          skeleton: const MusicListSkeleton(),
          emptyTitle: 'No songs yet',
          emptyIcon: Icons.music_note_outlined,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          unavailableBuilder: (context, item) => UnavailableRow(item: item),
          itemBuilder: (context, track, index) => TrackRow(
            track: track,
            markUnavailable: !state.isCached,
            onTap: track.availability == MediaAvailability.remoteUnavailable
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
            downloadAction:
                track.availability == MediaAvailability.remoteUnavailable
                ? null
                : TrackDownloadButton(track: track),
          ),
        );
      },
    );
  }
}

/// The user's playlists.
class PlaylistsTab extends StatefulWidget {
  const PlaylistsTab({super.key});

  @override
  State<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<PlaylistsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<PlaylistsCubit, PagedCollectionState<Playlist>>(
      builder: (context, state) {
        final cubit = context.read<PlaylistsCubit>();
        return PagedCollectionView<Playlist>(
          key: const PageStorageKey('music.playlists'),
          state: state,
          skeleton: const MusicListSkeleton(),
          emptyTitle: 'No playlists yet',
          emptyMessage:
              'Playlists you create on your Jellyfin server show up here.',
          emptyIcon: Icons.queue_music_outlined,
          onLoadMore: cubit.loadMore,
          onRefresh: cubit.refresh,
          onRetry: cubit.reload,
          onRetryLoadMore: cubit.retryLoadMore,
          itemBuilder: (context, playlist, _) => PlaylistRow(
            playlist: playlist,
            markUnavailable: !state.isCached,
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
