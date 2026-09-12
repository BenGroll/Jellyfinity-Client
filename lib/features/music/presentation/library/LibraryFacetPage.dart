import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../design/design.dart';
import 'LibraryPage.dart';
import 'music_collection_cubits.dart';

/// Every artist, album or song in one genre, or every album and song from
/// one decade — the Explore tab's "show all" for a genre or decade shelf
/// (v0.4.4/v0.4.5, ADR-0034).
///
/// Reuses [ArtistsTab]/[AlbumsTab]/[SongsTab] from the ordinary Library
/// tabs exactly as they render there, each narrowed with
/// [ArtistsCubit.forGenre]/[AlbumsCubit.forGenre]/[AlbumsCubit.forDecade]/
/// [SongsCubit.forGenre]/[SongsCubit.forDecade] instead of an unfiltered
/// `load()` — a genre or decade browse is just another way of asking
/// "which artists/albums/songs", not a different screen shape.
///
/// A decade has no artist tab: an artist has no single release year to
/// filter by (`MusicLibraryRepository.artists`' `genre`-only doc
/// comment), so [decadeStart] shows Albums and Songs, and [genre] shows
/// Artists, Albums and Songs. Exactly one of [genre]/[decadeStart] is
/// expected; the router that builds this page never sets both.
class LibraryFacetPage extends StatelessWidget {
  const LibraryFacetPage({
    super.key,
    this.genre,
    this.decadeStart,
    this.artists,
    this.albums,
    this.songs,
  }) : assert(
         (genre == null) != (decadeStart == null),
         'exactly one of genre or decadeStart is expected',
       );

  final String? genre;
  final int? decadeStart;

  // Injectable seams for widget tests.
  final ArtistsCubit? artists;
  final AlbumsCubit? albums;
  final SongsCubit? songs;

  @override
  Widget build(BuildContext context) {
    final genreName = genre;
    final title = genreName ?? '${decadeStart}s';
    final tabs = genreName != null
        ? const ['Artists', 'Albums', 'Songs']
        : const ['Albums', 'Songs'];

    return MultiBlocProvider(
      providers: [
        if (genreName != null)
          BlocProvider<ArtistsCubit>(
            create: (_) =>
                (artists ?? getIt<ArtistsCubit>())..forGenre(genreName),
          ),
        BlocProvider<AlbumsCubit>(
          create: (_) {
            final cubit = albums ?? getIt<AlbumsCubit>();
            return genreName != null
                ? (cubit..forGenre(genreName))
                : (cubit..forDecade(decadeStart!));
          },
        ),
        BlocProvider<SongsCubit>(
          create: (_) {
            final cubit = songs ?? getIt<SongsCubit>();
            return genreName != null
                ? (cubit..forGenre(genreName))
                : (cubit..forDecade(decadeStart!));
          },
        ),
      ],
      child: _FacetView(title: title, tabs: tabs),
    );
  }
}

class _FacetView extends StatelessWidget {
  const _FacetView({required this.title, required this.tabs});

  final String title;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DefaultTabController(
      length: tabs.length,
      child: AppScaffold(
        padded: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: title,
        body: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelColor: t.colors.textPrimary,
              unselectedLabelColor: t.colors.textSecondary,
              indicatorColor: t.colors.accent,
              dividerColor: t.colors.border,
              labelStyle: t.typography.titleMedium,
              tabs: [for (final label in tabs) Tab(text: label)],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  if (tabs.contains('Artists')) const ArtistsTab(),
                  const AlbumsTab(),
                  const SongsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
