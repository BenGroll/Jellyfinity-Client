import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../app/playlists/PlaylistCurationService.dart';
import '../../../../core/result/result.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';
import '../widgets/MediaArtwork.dart';
import '../widgets/media_formatting.dart';
import '../widgets/music_rows.dart';
import '../widgets/music_skeletons.dart';
import '../widgets/paged_collection_view.dart';
import '../widgets/playlist_add_flow.dart';
import '../widgets/playlist_dialogs.dart';
import 'media_detail_cubit.dart';
import 'playlist_edit_cubit.dart';

/// One playlist, in the order the user arranged it.
///
/// Position numbers come from the list, not from the tracks: a playlist
/// entry that is not a song, or no longer in the library, still occupies
/// its number here. Renumbering around it would quietly change the
/// playlist the user made.
///
/// Browsing (this screen's default) uses the same windowed
/// `PlaylistTracksCubit` every other list in the app uses. Reordering and
/// removing (`PlaylistEditCubit`, entered via the app bar's edit action)
/// load the whole playlist instead — the two are different enough views
/// of the same data that sharing one cubit between them would blur which
/// one a given screen state belongs to.
class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    this.detail,
    this.tracks,
    this.edit,
  });

  final MediaId playlistId;
  final PlaylistDetailCubit? detail;
  final PlaylistTracksCubit? tracks;
  final PlaylistEditCubit? edit;

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
        BlocProvider<PlaylistEditCubit>(
          create: (_) => edit ?? getIt<PlaylistEditCubit>(),
        ),
      ],
      child: _PlaylistDetailView(playlistId: playlistId),
    );
  }
}

class _PlaylistDetailView extends StatelessWidget {
  const _PlaylistDetailView({required this.playlistId});

  final MediaId playlistId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaylistDetailCubit, MediaDetailState<Playlist>>(
      builder: (context, header) {
        return BlocBuilder<PlaylistEditCubit, PlaylistEditState>(
          builder: (context, editState) {
            return AppScaffold(
              padded: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
              title: header.item?.name,
              actions: _actions(context, header.item, editState),
              body: editState.editing
                  ? _PlaylistEditBody(playlistId: playlistId)
                  : _PlaylistBrowseBody(header: header),
            );
          },
        );
      },
    );
  }

  List<Widget> _actions(
    BuildContext context,
    Playlist? playlist,
    PlaylistEditState editState,
  ) {
    final editCubit = context.read<PlaylistEditCubit>();

    if (editState.editing) {
      return [
        TextButton(
          onPressed: () {
            editCubit.stopEditing();
            context.read<PlaylistTracksCubit>().reload();
          },
          child: const Text('Done'),
        ),
      ];
    }

    if (playlist == null) return const [];

    return [
      IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Reorder or remove songs',
        onPressed: () => editCubit.startEditing(playlistId),
      ),
      IconButton(
        icon: const Icon(Icons.more_vert_rounded),
        onPressed: () => showOverflowSheet(context, [
          OverflowAction(
            icon: Icons.edit_outlined,
            label: 'Rename',
            onSelected: () => _rename(context, playlist),
          ),
          OverflowAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            onSelected: () => _delete(context, playlist),
          ),
        ]),
      ),
    ];
  }

  Future<void> _rename(BuildContext context, Playlist playlist) async {
    final name = await promptForPlaylistName(
      context,
      title: 'Rename Playlist',
      initialValue: playlist.name,
    );
    if (name == null || !context.mounted) return;

    final result = await getIt<PlaylistCurationService>().renamePlaylist(
      playlist.id,
      name,
    );
    if (!context.mounted) return;
    switch (result) {
      case Ok<void>():
        await context.read<PlaylistDetailCubit>().retry();
      case Err<void>(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _delete(BuildContext context, Playlist playlist) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete "${playlist.name}"?',
      message: 'This removes the playlist from your Jellyfin server. Its '
          'songs stay in your library.',
    );
    if (!confirmed || !context.mounted) return;

    final result = await getIt<PlaylistCurationService>().deletePlaylist(
      playlist.id,
    );
    if (!context.mounted) return;
    switch (result) {
      case Ok<void>():
        context.pop();
      case Err<void>(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

/// The normal, windowed, read-only view of the playlist.
class _PlaylistBrowseBody extends StatelessWidget {
  const _PlaylistBrowseBody({required this.header});

  final MediaDetailState<Playlist> header;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocBuilder<PlaylistTracksCubit, PagedCollectionState<Track>>(
      builder: (context, state) {
        final cubit = context.read<PlaylistTracksCubit>();
        return PagedCollectionView<Track>(
          state: state,
          headerSlivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
                child: _PlaylistHeader(state: header, tracks: state.items),
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
          unavailableBuilder: (context, item) => UnavailableRow(item: item),
          itemBuilder: (context, track, index) => TrackRow(
            track: track,
            showArtwork: false,
            position: index + 1,
            markUnavailable: !state.isCached,
            onTap: track.availability == MediaAvailability.remoteUnavailable
                ? null
                : () => context.read<PlaybackCubit>().playNow(
                    state.items,
                    startIndex: index,
                  ),
            onPlayNext: track.availability == MediaAvailability.remoteUnavailable
                ? null
                : () => context.read<PlaybackCubit>().playNext(track),
            onAddToQueue:
                track.availability == MediaAvailability.remoteUnavailable
                ? null
                : () => context.read<PlaybackCubit>().addToQueue(track),
            onAddToPlaylist:
                track.availability == MediaAvailability.remoteUnavailable
                ? null
                : () => addToPlaylistFlow(
                    context,
                    add: (playlistId) => getIt<PlaylistCurationService>()
                        .addTrack(playlistId, track.id),
                  ),
          ),
        );
      },
    );
  }
}

/// Reorder/remove, over the whole playlist loaded at once
/// ([PlaylistEditCubit]).
class _PlaylistEditBody extends StatelessWidget {
  const _PlaylistEditBody({required this.playlistId});

  final MediaId playlistId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaylistEditCubit, PlaylistEditState>(
      builder: (context, state) {
        final cubit = context.read<PlaylistEditCubit>();

        switch (state.status) {
          case PlaylistEditStatus.initial:
          case PlaylistEditStatus.loading:
            return const MusicListSkeleton(itemCount: 8);
          case PlaylistEditStatus.failed:
            return ErrorStateView.forFailure(state.failure!, onRetry: cubit.retry);
          case PlaylistEditStatus.ready:
            if (state.tracks.isEmpty) {
              return const EmptyStateView(
                title: 'This playlist is empty',
                icon: Icons.queue_music_outlined,
              );
            }
            return ReorderableListView.builder(
              itemCount: state.tracks.length,
              onReorderItem: cubit.reorder,
              itemBuilder: (context, index) {
                final track = state.tracks[index];
                return _EditableTrackRow(
                  key: ValueKey(track.playlistEntryId ?? '${track.id.key}#$index'),
                  track: track,
                  position: index + 1,
                  onRemove: () => cubit.remove(track),
                );
              },
            );
        }
      },
    );
  }
}

class _EditableTrackRow extends StatelessWidget {
  const _EditableTrackRow({
    required super.key,
    required this.track,
    required this.position,
    required this.onRemove,
  });

  final Track track;
  final int position;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final artists = formatArtists(track.artists);

    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.xxs,
      ),
      child: SizedBox(
        height: musicRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: rowArtworkSize,
              child: Center(
                child: Text(
                  '$position',
                  style: t.typography.bodyMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(width: t.spacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.bodyLarge.copyWith(
                      color: t.colors.textPrimary,
                    ),
                  ),
                  if (artists != null && artists.isNotEmpty)
                    Text(
                      artists,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.caption.copyWith(
                        color: t.colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              iconSize: 20,
              color: t.colors.textSecondary,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
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
        SizedBox(height: t.spacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: t.spacing.sm,
          runSpacing: t.spacing.sm,
          children: [
            if (tracks.isNotEmpty)
              AppButton(
                label: 'Play',
                icon: Icons.play_arrow_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    context.read<PlaybackCubit>().playNow(tracks, startIndex: 0),
              ),
            AppButton(
              label: 'Add to Playlist',
              icon: Icons.playlist_add_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => addToPlaylistFlow(
                context,
                add: (targetId) => getIt<PlaylistCurationService>()
                    .addPlaylist(targetId, playlist.id),
                successMessage: 'Added to playlist.',
              ),
            ),
          ],
        ),
        SizedBox(height: t.spacing.md),
      ],
    );
  }
}
