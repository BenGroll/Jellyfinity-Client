import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/downloads/DownloadsCubit.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../design/design.dart';
import '../../../../domain/downloads/downloads.dart';
import '../../../../domain/media/media.dart';
import '../../../../infrastructure/artwork/ArtworkCache.dart';
import '../library/music_collection_cubits.dart';
import '../library/LibraryPage.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/download_controls.dart';
import '../widgets/FavoriteButton.dart';
import '../widgets/MediaArtwork.dart';
import '../widgets/media_formatting.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
import 'artist_stats_cubit.dart';
import 'media_detail_cubit.dart';

/// One artist: who they are, then what they released, newest release
/// order last — the discography a music app opens an artist for.
class ArtistDetailPage extends StatelessWidget {
  const ArtistDetailPage({
    super.key,
    required this.artistId,
    this.detail,
    this.albums,
    this.stats,
  });

  final MediaId artistId;
  final ArtistDetailCubit? detail;
  final AlbumsCubit? albums;
  final ArtistStatsCubit? stats;

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
        BlocProvider<ArtistStatsCubit>(
          create: (_) => (stats ?? getIt<ArtistStatsCubit>())..open(artistId),
        ),
      ],
      child: _ArtistPresenceReconciler(
        artistId: artistId,
        child: const _ArtistDetailView(),
      ),
    );
  }
}

/// Marks a downloaded artist's server-deleted tracks "only on this
/// device" the first time the page is opened online (v0.2.3) — the
/// artist counterpart to `ReconcileDownloadedCollection`, keyed off the
/// albums list because the artist screen loads no flat track list.
class _ArtistPresenceReconciler extends StatefulWidget {
  const _ArtistPresenceReconciler({required this.artistId, required this.child});

  final MediaId artistId;
  final Widget child;

  @override
  State<_ArtistPresenceReconciler> createState() =>
      _ArtistPresenceReconcilerState();
}

class _ArtistPresenceReconcilerState extends State<_ArtistPresenceReconciler> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AlbumsCubit, PagedCollectionState<Album>>(
      listenWhen: (_, _) => !_done,
      listener: (context, state) {
        if (_done || !state.isReady || state.isCached) return;
        final downloads = context.read<DownloadsCubit>();
        if (downloads.state
            .statusFor(DownloadOwner.artist(widget.artistId))
            .isEmpty) {
          return;
        }
        _done = true;
        downloads.reconcileArtist(widget.artistId);
      },
      child: widget.child,
    );
  }
}

class _ArtistDetailView extends StatelessWidget {
  const _ArtistDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArtistDetailCubit, MediaDetailState<Artist>>(
      builder: (context, header) {
        final artist = header.item;
        return AppScaffold(
          padded: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: artist?.name,
          actions: artist == null
              ? const []
              : [
                  BlocBuilder<ArtistStatsCubit, ArtistStatsState>(
                    builder: (context, stats) => ArtistDownloadButton(
                      artist: artist,
                      trackCount: stats.stats?.songCount,
                    ),
                  ),
                  FavoriteButton(
                    isFavorite: artist.isFavorite,
                    onChanged: (favorite) async {
                      final result = await getIt<FavoritesRepository>()
                          .setFavorite(artist.id, favorite: favorite);
                      return result.isOk;
                    },
                  ),
                ],
          body: BlocBuilder<AlbumsCubit, PagedCollectionState<Album>>(
            builder: (context, state) {
              final cubit = context.read<AlbumsCubit>();
              return PagedCollectionView<Album>(
                state: state,
                gridDelegate: albumGridDelegate,
                headerSlivers: [
                  SliverToBoxAdapter(child: _ArtistHeader(state: header)),
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
                    RouteNames.libraryAlbum,
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
          padding: EdgeInsets.symmetric(
            horizontal: t.spacing.md,
            vertical: t.spacing.lg,
          ),
          child: ErrorStateView.forFailure(
            failure,
            title: 'Artist unavailable',
            onRetry: context.read<ArtistDetailCubit>().retry,
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
        child: const MediaHeaderSkeleton(artworkSize: 140),
      );
    }

    return Column(
      children: [
        _ArtistBanner(banner: artist.banner),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
          child: Column(
            children: [
              Transform.translate(
                // Overlaps the banner slightly, the same "profile picture
                // over the cover" layout most music apps use — purely
                // cosmetic, so it is skipped entirely when there is no
                // banner to overlap.
                offset: Offset(0, artist.banner == null ? 0 : -32),
                child: MediaArtwork(
                  image: artist.image,
                  kind: MediaKind.artist,
                  size: 120,
                  shape: ArtworkShape.circle,
                ),
              ),
              Text(
                artist.name,
                textAlign: TextAlign.center,
                style: t.typography.titleLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
              if (artist.overview != null) ...[
                SizedBox(height: t.spacing.xs),
                Text(
                  artist.overview!,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.bodyMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: t.spacing.sm),
              const _ArtistStatsRow(),
              _ArtistDownloadSummary(artistId: artist.id),
              SizedBox(height: t.spacing.md),
            ],
          ),
        ),
      ],
    );
  }
}

/// The honest download summary an artist header shows once any of the
/// artist has been downloaded (v0.2.2) — the same line the album and
/// playlist headers carry, hidden entirely until there is something to
/// say.
class _ArtistDownloadSummary extends StatelessWidget {
  const _ArtistDownloadSummary({required this.artistId});

  final MediaId artistId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = context.watch<DownloadsCubit>().state.statusFor(
      DownloadOwner.artist(artistId),
    );
    if (status.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: t.spacing.xxs),
      child: CollectionDownloadSummary(status: status),
    );
  }
}

/// A wide backdrop behind the artist's profile picture (v0.1.6). `null`
/// collapses to nothing rather than a placeholder — a missing banner is
/// the header v0.1.0 already shipped, not a broken one.
class _ArtistBanner extends StatelessWidget {
  const _ArtistBanner({required this.banner});

  final MediaImage? banner;

  static const double _height = 140;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final image = banner;
    if (image == null) return const SizedBox(height: 16);

    final url = getIt<ArtworkResolver>().imageUrl(
      image,
      maxWidth: MediaQuery.sizeOf(context).width.round(),
    );
    if (url == null) return const SizedBox(height: 16);

    return SizedBox(
      height: _height,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: url.toString(),
        cacheManager: ArtworkCache.instance,
        fit: BoxFit.cover,
        fadeInDuration: context.motion.fast,
        placeholder: (context, _) => ColoredBox(color: t.colors.surfaceSunken),
        errorWidget: (context, _, _) =>
            ColoredBox(color: t.colors.surfaceSunken),
      ),
    );
  }
}

/// "12 albums · 340 songs · 18 hr 42 min" (v0.1.6) — hidden entirely while
/// loading or unavailable rather than showing a placeholder row, since
/// these numbers are live-only (`ArtistStats`'s doc comment) and an
/// offline artist page simply has none to show.
class _ArtistStatsRow extends StatelessWidget {
  const _ArtistStatsRow();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocBuilder<ArtistStatsCubit, ArtistStatsState>(
      builder: (context, state) {
        final stats = state.stats;
        if (stats == null) return const SizedBox.shrink();

        final text = joinDetails([
          _formatAlbumCount(stats.albumCount),
          formatTrackCount(stats.songCount),
          stats.totalDuration == null
              ? null
              : formatRunningTime(stats.totalDuration!),
        ]);
        if (text.isEmpty) return const SizedBox.shrink();

        return Text(
          text,
          textAlign: TextAlign.center,
          style: t.typography.caption.copyWith(color: t.colors.textSecondary),
        );
      },
    );
  }

  String? _formatAlbumCount(int count) {
    if (count <= 0) return null;
    return count == 1 ? '1 album' : '$count albums';
  }
}
