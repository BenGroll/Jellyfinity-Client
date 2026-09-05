import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/connectivity/OfflineCubit.dart';
import '../../../../app/di/service_locator.dart';
import '../../../../app/downloads/DownloadsCubit.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/settings/SettingsCubit.dart';
import '../../../../design/design.dart';
import '../../../../domain/connectivity/OfflineLibraryScope.dart';
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

class _InlineSearchView extends StatefulWidget {
  const _InlineSearchView({this.onClose});

  final VoidCallback? onClose;

  @override
  State<_InlineSearchView> createState() => _InlineSearchViewState();
}

class _InlineSearchViewState extends State<_InlineSearchView> {
  /// The user's explicit choice on the "Downloaded" chip.
  bool _chipSelected = false;
  bool? _applied;

  void _sync(bool effective) {
    if (_applied == effective) return;
    _applied = effective;
    context.read<MusicSearchCubit>().showDownloadedOnly(effective);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // Offline + "Downloads only" scope: the search runs against downloads
    // and the chip has nothing to toggle (v0.2.3).
    final offline = context.watch<OfflineCubit>().state.isOffline;
    final limited =
        context.watch<SettingsCubit>().state.offlineLibraryScope ==
        OfflineLibraryScope.limited;
    final lockedToDownloads = offline && limited;
    final effective = _chipSelected || lockedToDownloads;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(effective);
    });

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
          child: _SearchField(onClose: widget.onClose),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(t.spacing.md, 0, t.spacing.md, 0),
          child: const _SearchStatusLine(),
        ),
        if (!lockedToDownloads)
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacing.md,
              t.spacing.xs,
              t.spacing.md,
              t.spacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _DownloadedSearchChip(
                selected: _chipSelected,
                onChanged: (value) => setState(() => _chipSelected = value),
              ),
            ),
          )
        else
          SizedBox(height: t.spacing.sm),
        Expanded(child: _SearchResults(onNavigate: widget.onClose)),
      ],
    );
  }
}

/// One slim line under the search field explaining why results might be
/// incomplete (v0.2.3) — the server is unreachable, or the app is
/// deliberately offline. Replaces the full-page "Search needs the server"
/// error and the per-category failure text: one honest line, not five.
class _SearchStatusLine extends StatelessWidget {
  const _SearchStatusLine();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final offline = context.watch<OfflineCubit>().state.isOffline;

    return BlocBuilder<MusicSearchCubit, MusicSearchState>(
      builder: (context, state) {
        final searched = state.status == MusicSearchStatus.results;
        final serverMissed =
            state.hasFailure || state.wholeSearchFailure != null;
        final downloadedOnly = context.read<MusicSearchCubit>().downloadedOnly;

        String? message;
        if (offline || downloadedOnly) {
          message = 'Searching music on this device';
        } else if (searched && serverMissed) {
          message = "Can't reach the server — showing downloaded music";
        }
        if (message == null) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(top: t.spacing.xs, bottom: t.spacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 14,
                color: t.colors.textSecondary,
              ),
              SizedBox(width: t.spacing.xs),
              Flexible(
                child: Text(
                  message,
                  style: t.typography.caption.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

    final catalog = context.watch<DownloadsCubit>().state;

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

        // The server could not be reached and nothing downloaded matched
        // either. Said once, quietly, in the status line above — here it
        // is just an empty result, not a full-page error (v0.2.3).
        if (state.wholeSearchFailure != null) {
          return EmptyStateView(
            title: 'No matches on this device',
            message:
                'Nothing downloaded matches "${state.query}". Connect to '
                'the server to search your whole library.',
            icon: Icons.search_off_rounded,
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
              rowBuilder: (context, track) {
                // Playing a track starts the mini-player but does not
                // navigate away, so search stays open — no onNavigate. A
                // download the server dropped still plays from its file
                // (v0.2.3).
                final playable =
                    track.availability != MediaAvailability.remoteUnavailable ||
                    catalog.isDownloaded(track.id);
                return TrackRow(
                  track: track,
                  playable: playable,
                  onTap: playable
                      ? () => context.read<PlaybackCubit>().playNow(
                          state.songs.items,
                          startIndex: state.songs.items.indexOf(track),
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

/// The "Downloaded" filter on the search screen (v0.2.3): searches only
/// the signed-in profile's downloads. Also the fallback a normal search
/// lands on automatically when the server cannot be reached — this chip
/// just makes it a deliberate choice too. Its selected state is owned by
/// [_InlineSearchViewState], which also forces it on while offline with
/// the "Downloads only" scope.
class _DownloadedSearchChip extends StatelessWidget {
  const _DownloadedSearchChip({
    required this.selected,
    required this.onChanged,
  });

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FilterChip(
      label: const Text('Downloaded'),
      avatar: Icon(
        Icons.download_done_rounded,
        size: 18,
        color: selected ? t.colors.accent : t.colors.textSecondary,
      ),
      selected: selected,
      tooltip: 'Search only music kept on this device',
      onSelected: onChanged,
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

    // A category with nothing to show renders nothing — including one that
    // failed. The status line under the search field is where an
    // unreachable server is explained, not four red lines between the
    // headings (v0.2.3).
    if (section.items.isEmpty) return const SizedBox.shrink();

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
        for (final item in section.items) rowBuilder(context, item),
      ],
    );
  }
}
