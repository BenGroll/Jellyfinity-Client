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

/// Music-scoped search, rendered inline in [HomeLibraryHeader]'s content
/// area rather than as a pushed page — ADR-0014 moved search out of a
/// subscreen so it is reachable at the very top of the UI at all times.
/// The field and the categorized results are unchanged from the page this
/// replaces; only the surrounding chrome (title, back button, its own
/// scaffold) is gone, since the shared header already provides that.
class InlineMusicSearch extends StatelessWidget {
  const InlineMusicSearch({super.key, this.cubit, this.onClose});

  final MusicSearchCubit? cubit;

  /// Clears the field and returns to the normal Home/Library content.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MusicSearchCubit>(
      create: (_) => cubit ?? getIt<MusicSearchCubit>(),
      child: _InlineSearchView(onClose: onClose),
    );
  }
}

class _InlineSearchView extends StatelessWidget {
  const _InlineSearchView({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.spacing.md,
            0,
            t.spacing.md,
            t.spacing.sm,
          ),
          child: _SearchField(onClose: onClose),
        ),
        Expanded(child: _SearchResults(onNavigate: onClose)),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({this.onClose});

  final VoidCallback? onClose;

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
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close search',
          onPressed: () {
            _controller.clear();
            cubit.queryChanged('');
            widget.onClose?.call();
          },
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
  const _SearchResults({this.onNavigate});

  /// Called just before any result row (or "Show all") pushes a route.
  ///
  /// `InlineMusicSearch` replaces the shell's header/pills entirely while
  /// active (`AppShell._searching`) rather than being a route itself, so
  /// a route pushed from underneath it would otherwise be invisible: the
  /// pushed page lives in the branch `Navigator` that `AppShell` is
  /// currently not showing. Calling this hands control back to
  /// `AppShell` first, so the branch (and the page just pushed onto it)
  /// is what's on screen by the time the push resolves.
  final VoidCallback? onNavigate;

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
              onNavigate: onNavigate,
              rowBuilder: (context, artist) => ArtistRow(
                artist: artist,
                onTap: () {
                  onNavigate?.call();
                  context.pushNamed(
                    RouteNames.libraryArtist,
                    pathParameters: {'id': artist.id.key},
                  );
                },
              ),
            ),
            _Section<Album>(
              category: SearchCategory.albums,
              query: state.query,
              section: state.albums,
              onNavigate: onNavigate,
              rowBuilder: (context, album) => AlbumRow(
                album: album,
                onTap: () {
                  onNavigate?.call();
                  context.pushNamed(
                    RouteNames.libraryAlbum,
                    pathParameters: {'id': album.id.key},
                  );
                },
              ),
            ),
            _Section<Track>(
              category: SearchCategory.songs,
              query: state.query,
              section: state.songs,
              onNavigate: onNavigate,
              rowBuilder: (context, track) => TrackRow(
                track: track,
                // Playing a track starts the mini-player but does not
                // navigate away, so search stays open — no onNavigate.
                onTap: track.availability == MediaAvailability.remoteUnavailable
                    ? null
                    : () => context.read<PlaybackCubit>().playNow(
                        state.songs.items,
                        startIndex: state.songs.items.indexOf(track),
                      ),
                onPlayNext:
                    track.availability == MediaAvailability.remoteUnavailable
                    ? null
                    : () => context.read<PlaybackCubit>().playNext(track),
                onAddToQueue:
                    track.availability == MediaAvailability.remoteUnavailable
                    ? null
                    : () => context.read<PlaybackCubit>().addToQueue(track),
              ),
            ),
            _Section<Playlist>(
              category: SearchCategory.playlists,
              query: state.query,
              section: state.playlists,
              onNavigate: onNavigate,
              rowBuilder: (context, playlist) => PlaylistRow(
                playlist: playlist,
                onTap: () {
                  onNavigate?.call();
                  context.pushNamed(
                    RouteNames.libraryPlaylist,
                    pathParameters: {'id': playlist.id.key},
                  );
                },
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
    this.onNavigate,
  });

  final SearchCategory category;
  final String query;
  final SearchSection<T> section;
  final Widget Function(BuildContext context, T item) rowBuilder;
  final VoidCallback? onNavigate;

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
                onPressed: () {
                  onNavigate?.call();
                  context.pushNamed(
                    RouteNames.librarySearchCategory,
                    pathParameters: {'category': category.name},
                    queryParameters: {'q': query},
                  );
                },
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
