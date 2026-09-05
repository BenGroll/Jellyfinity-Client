import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/downloads/DownloadsCubit.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../design/design.dart';
import '../../../../domain/downloads/downloads.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/download_controls.dart';
import '../widgets/FavoriteButton.dart';
import '../widgets/MediaArtwork.dart';
import '../widgets/MediaPlaybackActionsRow.dart';
import '../widgets/media_formatting.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
import '../widgets/reconcile_downloaded_collection.dart';
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
      child: ReconcileDownloadedCollection(
        owner: DownloadOwner.album(albumId),
        child: const _AlbumDetailView(),
      ),
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
        final album = header.item;
        return AppScaffold(
          padded: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: album?.name,
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
                  // A track the server could not describe has nothing to
                  // fetch, so it gets no download control either.
                  downloadAction:
                      track.availability == MediaAvailability.remoteUnavailable
                      ? null
                      : TrackDownloadButton(track: track),
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

    final downloadStatus = context.watch<DownloadsCubit>().state.statusFor(
      DownloadOwner.album(album.id),
    );

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
          style: t.typography.headlineLarge.copyWith(
            color: t.colors.textPrimary,
          ),
        ),
        if (album.artists.isNotEmpty) ...[
          SizedBox(height: t.spacing.xxs),
          _AlbumArtistCredit(artists: album.artists),
        ],
        if (details.isNotEmpty) ...[
          SizedBox(height: t.spacing.xxs),
          Text(
            details,
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
        ],
        if (!downloadStatus.isEmpty) ...[
          SizedBox(height: t.spacing.xxs),
          CollectionDownloadSummary(status: downloadStatus),
        ],
        SizedBox(height: t.spacing.md),
        MediaPlaybackActionsRow(
          tracks: tracks,
          download: AlbumDownloadButton(album: album),
          favorite: FavoriteButton(
            isFavorite: album.isFavorite,
            onChanged: (favorite) async {
              final result = await getIt<FavoritesRepository>().setFavorite(
                album.id,
                favorite: favorite,
              );
              return result.isOk;
            },
          ),
        ),
        SizedBox(height: t.spacing.md),
      ],
    );
  }
}

/// The album's artist credit line, with each navigable name (v0.1.6)
/// opening that artist's page — a credit the server gave only as a name
/// stays plain text, since [ArtistRef.isNavigable] is false for it.
///
/// Built from small tappable/plain [Text] pieces in a [Wrap] rather than
/// one [TextSpan] with a [GestureRecognizer]: a recognizer needs manual
/// disposal to avoid leaking, which a credit list this short does not
/// need to take on.
class _AlbumArtistCredit extends StatelessWidget {
  const _AlbumArtistCredit({required this.artists});

  final List<ArtistRef> artists;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Accent color alone signals "clickable" here — no underline, which
    // read as noisy once the artist name was made tappable (v0.1.6).
    final plainStyle = t.typography.bodyLarge.copyWith(
      color: t.colors.textSecondary,
    );
    final linkStyle = t.typography.bodyLarge.copyWith(color: t.colors.accent);

    final pieces = <Widget>[];
    for (var i = 0; i < artists.length; i++) {
      final artist = artists[i];
      if (i > 0) pieces.add(Text(', ', style: plainStyle));
      pieces.add(
        artist.isNavigable
            ? InkWell(
                onTap: () => context.pushNamed(
                  RouteNames.libraryArtist,
                  pathParameters: {'id': artist.id!.key},
                ),
                child: Text(artist.name, style: linkStyle),
              )
            : Text(artist.name, style: plainStyle),
      );
    }

    return Wrap(alignment: WrapAlignment.center, children: pieces);
  }
}
