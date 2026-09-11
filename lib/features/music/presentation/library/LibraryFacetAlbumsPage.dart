import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
import 'LibraryPage.dart';
import 'music_collection_cubits.dart';
import 'paged_collection_cubit.dart';

/// Every album in one genre, or from one decade — the Explore tab's "show
/// all" for a genre or decade shelf (v0.4.4, ADR-0034).
///
/// The same [AlbumsCubit] and [PagedCollectionView] every other album
/// grid uses, narrowed with [AlbumsCubit.forGenre] or
/// [AlbumsCubit.forDecade] instead of [AlbumsCubit.forArtist] — a genre
/// or decade browse is just another way of asking "which albums", not a
/// different screen shape. Exactly one of [genre] and [decadeStart] is
/// expected; the caller (the router) never sets both.
class LibraryFacetAlbumsPage extends StatelessWidget {
  const LibraryFacetAlbumsPage({
    super.key,
    this.genre,
    this.decadeStart,
    this.albums,
  }) : assert(
         (genre == null) != (decadeStart == null),
         'exactly one of genre or decadeStart is expected',
       );

  final String? genre;
  final int? decadeStart;

  // Injectable seam for widget tests.
  final AlbumsCubit? albums;

  String get _title {
    final genreName = genre;
    return genreName ?? '${decadeStart}s';
  }

  String get _emptyMessage {
    final genreName = genre;
    return genreName != null
        ? 'No albums in $genreName yet.'
        : 'No albums from the ${decadeStart}s yet.';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padded: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      title: _title,
      body: BlocProvider<AlbumsCubit>(
        create: (_) {
          final cubit = albums ?? getIt<AlbumsCubit>();
          final genreName = genre;
          if (genreName != null) {
            cubit.forGenre(genreName);
          } else {
            cubit.forDecade(decadeStart!);
          }
          return cubit;
        },
        child: _FacetAlbumResults(emptyMessage: _emptyMessage),
      ),
    );
  }
}

class _FacetAlbumResults extends StatelessWidget {
  const _FacetAlbumResults({required this.emptyMessage});

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlbumsCubit, PagedCollectionState<Album>>(
      builder: (context, state) {
        final cubit = context.read<AlbumsCubit>();
        return PagedCollectionView<Album>(
          state: state,
          gridDelegate: albumGridDelegate,
          skeleton: const AlbumGridSkeleton(gridDelegate: albumGridDelegate),
          emptyTitle: 'No albums',
          emptyMessage: emptyMessage,
          emptyIcon: Icons.album_outlined,
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
