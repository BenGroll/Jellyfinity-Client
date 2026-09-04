import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import 'music_search_cubit.dart';

/// Music-scoped search: one field, four kept-apart categories.
///
/// Each category shows the first few matches and, when there are more,
/// offers the rest as its own paged list. That is the "explicit category
/// switching" `OUTLOOK.md` §12 describes, in the smallest form that is
/// still honest about how many matches there are.
class MusicSearchPage extends StatelessWidget {
  const MusicSearchPage({super.key, this.cubit});

  final MusicSearchCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MusicSearchCubit>(
      create: (_) => cubit ?? getIt<MusicSearchCubit>(),
      child: const _MusicSearchView(),
    );
  }
}

class _MusicSearchView extends StatelessWidget {
  const _MusicSearchView();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppScaffold(
      padded: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      title: 'Search music',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacing.md,
              t.spacing.xs,
              t.spacing.md,
              t.spacing.sm,
            ),
            child: const _SearchField(),
          ),
          const Expanded(child: _SearchResults()),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cubit = context.read<MusicSearchCubit>();

    return TextField(
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: t.typography.bodyLarge.copyWith(color: t.colors.textPrimary),
      onChanged: cubit.queryChanged,
      onSubmitted: (_) => cubit.submit(),
      decoration: InputDecoration(
        hintText: 'Artists, albums, songs, playlists',
        hintStyle: t.typography.bodyMedium.copyWith(
          color: t.colors.textDisabled,
        ),
        prefixIcon: Icon(Icons.search_rounded, color: t.colors.textSecondary),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear',
                  onPressed: () {
                    _controller.clear();
                    cubit.queryChanged('');
                  },
                ),
        ),
        filled: true,
        fillColor: t.colors.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: t.radii.mdBorder,
          borderSide: BorderSide(color: t.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: t.radii.mdBorder,
          borderSide: BorderSide(color: t.colors.border),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocBuilder<MusicSearchCubit, MusicSearchState>(
      builder: (context, state) {
        if (state.status == MusicSearchStatus.idle) {
          return const EmptyStateView(
            title: 'Search your music',
            message:
                'Artists, albums, songs and playlists are searched '
                'separately, so results stay easy to read.',
            icon: Icons.search_rounded,
          );
        }

        // Nothing has come back yet: show the shape of a result list
        // rather than a spinner.
        if (state.status == MusicSearchStatus.searching &&
            state.artists.isEmpty &&
            state.albums.isEmpty &&
            state.songs.isEmpty &&
            state.playlists.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
            child: const MusicListSkeleton(itemCount: 6),
          );
        }

        final whole = state.wholeSearchFailure;
        if (whole != null) {
          return ErrorStateView.forFailure(
            whole,
            title: 'Search needs the server',
            onRetry: context.read<MusicSearchCubit>().submit,
          );
        }

        if (state.foundNothing) {
          return EmptyStateView(
            title: 'No matches',
            message: 'Nothing in your music library matches "${state.query}".',
            icon: Icons.search_off_rounded,
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(
            t.spacing.md,
            0,
            t.spacing.md,
            t.spacing.xxl,
          ),
          children: [
            _Section<Artist>(
              category: SearchCategory.artists,
              query: state.query,
              section: state.artists,
              rowBuilder: (context, artist) => ArtistRow(
                artist: artist,
                onTap: () => context.pushNamed(
                  RouteNames.musicArtist,
                  pathParameters: {'id': artist.id.key},
                ),
              ),
            ),
            _Section<Album>(
              category: SearchCategory.albums,
              query: state.query,
              section: state.albums,
              rowBuilder: (context, album) => AlbumRow(
                album: album,
                onTap: () => context.pushNamed(
                  RouteNames.musicAlbum,
                  pathParameters: {'id': album.id.key},
                ),
              ),
            ),
            _Section<Track>(
              category: SearchCategory.songs,
              query: state.query,
              section: state.songs,
              rowBuilder: (context, track) => TrackRow(
                track: track,
                onTap: track.availability == MediaAvailability.remoteUnavailable
                    ? null
                    : () => context.read<PlaybackCubit>().playNow(
                        state.songs.items,
                        startIndex: state.songs.items.indexOf(track),
                      ),
              ),
            ),
            _Section<Playlist>(
              category: SearchCategory.playlists,
              query: state.query,
              section: state.playlists,
              rowBuilder: (context, playlist) => PlaylistRow(
                playlist: playlist,
                onTap: () => context.pushNamed(
                  RouteNames.musicPlaylist,
                  pathParameters: {'id': playlist.id.key},
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One category of results: a heading, a few rows, and a way to see the
/// rest. Renders nothing at all when the category has no matches, so an
/// artist search does not show three empty headings.
class _Section<T extends MediaItem> extends StatelessWidget {
  const _Section({
    required this.category,
    required this.query,
    required this.section,
    required this.rowBuilder,
  });

  final SearchCategory category;
  final String query;
  final SearchSection<T> section;
  final Widget Function(BuildContext context, T item) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (section.isEmpty && section.failure == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: t.spacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                category.label,
                style: t.typography.titleMedium.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
            ),
            if (section.hasMore)
              TextButton(
                onPressed: () => context.pushNamed(
                  RouteNames.musicSearchCategory,
                  pathParameters: {'category': category.name},
                  queryParameters: {'q': query},
                ),
                child: Text('Show all ${section.total}'),
              ),
          ],
        ),
        if (section.failure != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
            child: Text(
              section.failure!.message,
              style: t.typography.caption.copyWith(color: t.colors.danger),
            ),
          )
        else
          for (final item in section.items) rowBuilder(context, item),
      ],
    );
  }
}
