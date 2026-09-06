import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/downloads/DownloadsCubit.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../design/design.dart';
import '../../../../domain/downloads/downloads.dart';
import '../../../../domain/media/media.dart';
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

/// One playlist, in the order the user arranged it.
///
/// Position numbers come from the list, not from the tracks: a playlist
/// entry that is not a song, or no longer in the library, still occupies
/// its number here. Renumbering around it would quietly change the
/// playlist the user made.
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
              return PagedCollectionView<Track>(
                state: state,
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
                unavailableBuilder: (context, item) =>
                    UnavailableRow(item: item),
                itemBuilder: (context, track, index) {
                  final playable =
                      track.availability !=
                          MediaAvailability.remoteUnavailable ||
                      catalog.isDownloaded(track.id);
                  return TrackRow(
                    track: track,
                    showArtwork: false,
                    position: index + 1,
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
                    // Only a row that came from the server carries the
                    // entry id removal names (v0.1.2's completion). One
                    // read from the saved copy or a download snapshot
                    // does not, and editing needs the server anyway.
                    onRemoveFromPlaylist: track is PlaylistTrack
                        ? () => _removeRow(track)
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
        SizedBox(height: t.spacing.md),
        MediaPlaybackActionsRow(
          tracks: tracks,
          download: PlaylistDownloadButton(playlist: playlist),
        ),
        SizedBox(height: t.spacing.md),
      ],
    );
  }
}
