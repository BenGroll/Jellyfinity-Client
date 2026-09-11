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
import '../../../../domain/playback/QueueOrigin.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/download_controls.dart';
import '../widgets/MediaArtwork.dart';
import '../widgets/MediaPlaybackActionsRow.dart';
import '../widgets/media_formatting.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/playlist_actions.dart';
import '../widgets/paged_collection_view.dart';
import 'media_detail_cubit.dart';

/// One playlist, in the order the user arranged it — and, online, the
/// place that order is changed.
///
/// Position numbers come from the playlist, not from the list on screen
/// (v0.4.2): a playlist entry that is not a song, or no longer in the
/// library, still occupies its number here, and the rows around it are
/// numbered as if it were there, because to the server it is. The same
/// number is what a drag moves a row to, which is why reorder could not
/// ship until the read model carried it (ADR-0024, ADR-0032).
class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    this.detail,
    this.tracks,
  });

  final MediaId playlistId;
  final PlaylistDetailCubit? detail;
  final PlaylistTracksCubit? tracks;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PlaylistDetailCubit>(
          create: (_) =>
              (detail ?? getIt<PlaylistDetailCubit>())..open(playlistId),
        ),
        BlocProvider<PlaylistTracksCubit>(
          create: (_) =>
              (tracks ?? getIt<PlaylistTracksCubit>())..forPlaylist(playlistId),
        ),
      ],
      child: const _PlaylistDetailView(),
    );
  }
}

class _PlaylistDetailView extends StatefulWidget {
  const _PlaylistDetailView();

  @override
  State<_PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<_PlaylistDetailView> {
  /// Reconcile-on-open runs at most once per visit (v0.2.1): opening a
  /// downloaded playlist online is one of the two triggers `ROADMAP.md`
  /// names for reconciling its membership against the server.
  bool _reconciled = false;

  void _maybeReconcile() {
    if (_reconciled) return;

    final tracks = context.read<PlaylistTracksCubit>().state;
    if (!tracks.isReady || tracks.isCached) return;

    final catalog = context.read<DownloadsCubit>().state;
    final playlist = context.read<PlaylistDetailCubit>().state.item;
    if (playlist == null || !catalog.isPlaylistDownloaded(playlist.id)) return;

    _reconciled = true;
    final messenger = ScaffoldMessenger.of(context);
    context.read<DownloadsCubit>().reconcilePlaylist(playlist.id).then((
      change,
    ) {
      if (!mounted || change.isEmpty) return;
      messenger.showSnackBar(
        SnackBar(content: Text(describePlaylistDownloadChange(change))),
      );
    });
  }

  /// Rename and delete, behind the app bar's overflow (v0.1.2's
  /// completion) — the two actions that change the playlist itself rather
  /// than what is in it.
  void _openPlaylistMenu(BuildContext context, Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _rename(playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete playlist'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _delete(playlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(Playlist playlist) async {
    if (!await renamePlaylist(context, playlist) || !mounted) return;
    // The header carries the name; the track list is untouched.
    await context.read<PlaylistDetailCubit>().retry();
  }

  Future<void> _delete(Playlist playlist) async {
    // Captured before the await, and the plain Navigator rather than
    // GoRouter: this page is always pushed, so popping it is a Navigator
    // concern, and not reaching for the router keeps the screen testable
    // without one.
    final navigator = Navigator.of(context);
    if (!await deletePlaylist(context, playlist) || !mounted) return;
    // Nothing left to show. Leaving the user on the page of a playlist
    // that no longer exists would be the one state this screen cannot
    // render honestly.
    await navigator.maybePop();
  }

  /// Moves the row at [from] to [to], both indices into the rows on
  /// screen. The cubit turns that into the playlist's own index and puts
  /// the list back if the server refuses.
  Future<void> _moveRow(int from, int to) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await context.read<PlaylistTracksCubit>().moveEntry(
      from: from,
      to: to,
    );
    if (failure == null || !mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Could not move that song. ${failure.message}')),
    );
  }

  /// Removes one row, then reloads so the numbering closes up behind it.
  Future<void> _removeRow(PlaylistTrack row) async {
    final playlist = context.read<PlaylistDetailCubit>().state.item;
    if (playlist == null) return;
    final removed = await removeFromPlaylist(
      context,
      playlistId: playlist.id,
      row: row,
    );
    if (!removed || !mounted) return;
    await context.read<PlaylistTracksCubit>().refresh();
    if (!mounted) return;
    // The header's song count and running time both just changed.
    await context.read<PlaylistDetailCubit>().retry();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocConsumer<PlaylistDetailCubit, MediaDetailState<Playlist>>(
      listener: (context, header) => _maybeReconcile(),
      builder: (context, header) {
        return AppScaffold(
          padded: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: header.item?.name,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () async {
                await context.read<PlaylistDetailCubit>().retry();
                if (context.mounted) {
                  await context.read<PlaylistTracksCubit>().refresh();
                }
              },
            ),
            if (header.item case final Playlist playlist)
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Playlist options',
                onPressed: () => _openPlaylistMenu(context, playlist),
              ),
          ],
          body: BlocConsumer<PlaylistTracksCubit, PagedCollectionState<Track>>(
            listener: (context, state) => _maybeReconcile(),
            builder: (context, state) {
              final cubit = context.read<PlaylistTracksCubit>();
              final catalog = context.watch<DownloadsCubit>().state;
              final playlist = header.item;
              // Editing a playlist reaches the server or fails
              // (ADR-0024), so a saved copy is a list to play, not one to
              // rearrange. Every row of a server-read page carries the
              // entry id a move names; a row that somehow does not simply
              // goes without a grip.
              final canReorder = !state.isCached && state.items.length > 1;
              final origin = playlist == null
                  ? null
                  : QueueOrigin.playlist(
                      playlistId: playlist.id,
                      name: playlist.name,
                      image: playlist.image,
                    );
              return PagedCollectionView<Track>(
                state: state,
                onReorder: canReorder ? _moveRow : null,
                headerSlivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
                      child: _PlaylistHeader(
                        state: header,
                        tracks: state.items,
                      ),
                    ),
                  ),
                ],
                skeleton: const MusicListSkeleton(itemCount: 8),
                emptyTitle: 'This playlist is empty',
                emptyIcon: Icons.queue_music_outlined,
                onLoadMore: cubit.loadMore,
                onRefresh: () async {
                  await context.read<PlaylistDetailCubit>().retry();
                  await cubit.refresh();
                },
                onRetry: cubit.reload,
                onRetryLoadMore: cubit.retryLoadMore,
                offlineGapNoun: 'song',
                unavailableBuilder: (context, item) => UnavailableRow(
                  item: item,
                  // Numbered like every other row: an entry Jellyfinity
                  // cannot read is still the playlist's fourth entry.
                  position: item.position == null ? null : item.position! + 1,
                ),
                itemBuilder: (context, track, index) {
                  final playable =
                      track.availability !=
                          MediaAvailability.remoteUnavailable ||
                      catalog.isDownloaded(track.id);
                  // Only a row that came from the server carries the entry
                  // id a removal or a move names (v0.1.2's completion,
                  // v0.4.2's reorder). One read from the saved copy or a
                  // download snapshot does not, and editing needs the
                  // server anyway.
                  final entry = track is PlaylistTrack ? track : null;
                  final editable = entry != null && entry.isEditable;
                  final canDrag = canReorder && editable;
                  return TrackRow(
                    // Keyed by the entry, not by where the row sits: a
                    // playlist may list the same song three times, and two
                    // identical keys make a drag move the wrong one.
                    key: ValueKey(
                      entry?.entryId ?? 'row-$index-${track.id.itemId}',
                    ),
                    track: track,
                    showArtwork: false,
                    position: (entry?.position ?? index) + 1,
                    playable: playable,
                    dragHandle: canDrag
                        ? ReorderableDragStartListener(
                            index: index,
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              color: t.colors.textSecondary,
                            ),
                          )
                        : null,
                    onMoveUp: canDrag && index > 0
                        ? () => _moveRow(index, index - 1)
                        : null,
                    onMoveDown: canDrag && index < state.items.length - 1
                        ? () => _moveRow(index, index + 1)
                        : null,
                    onTap: playable
                        ? () => context.read<PlaybackCubit>().playNow(
                            state.items,
                            startIndex: index,
                            origin: origin,
                          )
                        : null,
                    onPlayNext: playable
                        ? () => context.read<PlaybackCubit>().playNext(track)
                        : null,
                    onAddToQueue: playable
                        ? () => context.read<PlaybackCubit>().addToQueue(track)
                        : null,
                    onRemoveFromPlaylist: editable
                        ? () => _removeRow(entry)
                        : null,
                    downloadAction:
                        track.availability ==
                            MediaAvailability.remoteUnavailable
                        ? null
                        : TrackDownloadButton(track: track),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({required this.state, required this.tracks});

  final MediaDetailState<Playlist> state;

  /// The tracks loaded so far — enough to back the Play button without a
  /// second fetch.
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final playlist = state.item;

    if (playlist == null) {
      final failure = state.failure;
      if (failure != null) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: t.spacing.lg),
          child: ErrorStateView.forFailure(
            failure,
            title: 'Playlist unavailable',
            onRetry: context.read<PlaylistDetailCubit>().retry,
          ),
        );
      }
      return const MediaHeaderSkeleton();
    }

    final details = joinDetails([
      formatTrackCount(playlist.itemCount),
      playlist.duration == null ? null : formatRunningTime(playlist.duration!),
    ]);

    return Column(
      children: [
        SizedBox(height: t.spacing.sm),
        MediaArtwork(
          image: playlist.image,
          kind: MediaKind.playlist,
          size: 180,
        ),
        SizedBox(height: t.spacing.md),
        Text(
          playlist.name,
          textAlign: TextAlign.center,
          style: t.typography.titleLarge.copyWith(color: t.colors.textPrimary),
        ),
        if (details.isNotEmpty) ...[
          SizedBox(height: t.spacing.xxs),
          Text(
            details,
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
        ],
        Builder(
          builder: (context) {
            final catalog = context.watch<DownloadsCubit>().state;
            if (!catalog.isPlaylistDownloaded(playlist.id)) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.only(top: t.spacing.xxs),
              child: CollectionDownloadSummary(
                status: catalog.statusFor(DownloadOwner.playlist(playlist.id)),
              ),
            );
          },
        ),
        _PlaylistSessionNote(playlist: playlist),
        SizedBox(height: t.spacing.md),
        MediaPlaybackActionsRow(
          tracks: tracks,
          download: PlaylistDownloadButton(playlist: playlist),
          origin: QueueOrigin.playlist(
            playlistId: playlist.id,
            name: playlist.name,
            image: playlist.image,
          ),
        ),
        SizedBox(height: t.spacing.md),
      ],
    );
  }
}

/// "Continue — Blue in Green", when the queue that is sitting there was
/// started from this playlist (v0.4.2).
///
/// The playlist session ADR-0026 could not offer, built from the two
/// things that already exist: the restored queue and the origin it now
/// carries. It knows this is the same session because the queue says so,
/// not because the track happens to appear in the list — the same song in
/// two playlists is not two sessions.
///
/// Absent whenever there is nothing to carry on: another queue is loaded,
/// the queue is already playing, or this playlist was never the one
/// playing.
class _PlaylistSessionNote extends StatelessWidget {
  const _PlaylistSessionNote({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final playback = context.watch<PlaybackCubit>().state;
    final origin = playback.queue.origin;
    final entry = playback.queue.currentEntry;
    if (origin == null || origin.playlistId != playlist.id || entry == null) {
      return const SizedBox.shrink();
    }

    // Already playing: say where it is, and offer nothing — the transport
    // controls are a tap away and starting it again would only restart
    // the track.
    if (playback.isPlaying) {
      return Padding(
        padding: EdgeInsets.only(top: t.spacing.xs),
        child: Text(
          'Playing "${entry.title}" from this playlist',
          textAlign: TextAlign.center,
          style: t.typography.caption.copyWith(color: t.colors.textSecondary),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: t.spacing.xs),
      child: AppButton(
        label: 'Continue "${entry.title}"',
        icon: Icons.play_arrow_rounded,
        variant: AppButtonVariant.secondary,
        onPressed: () {
          context.read<PlaybackCubit>().resume();
          context.pushNamed(RouteNames.nowPlaying);
        },
      ),
    );
  }
}
