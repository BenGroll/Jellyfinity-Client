import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/playlists/PlaylistCurationService.dart';
import '../../../../core/result/result.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';
import 'music_rows.dart';
import 'music_skeletons.dart';
import 'paged_collection_view.dart';
import 'playlist_dialogs.dart';

/// Opens the add-to-playlist picker: an existing playlist, or a freshly
/// created one. Returns the chosen playlist's id, or `null` if the user
/// backed out without picking one.
Future<MediaId?> showPlaylistPicker(
  BuildContext context, {
  PlaylistsCubit? playlists,
}) {
  return showModalBottomSheet<MediaId>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PlaylistPickerSheet(playlists: playlists),
  );
}

/// The picker itself, a `BlocProvider` seam so widget tests can supply a
/// [PlaylistsCubit] directly — the same pattern `LibraryPage` uses.
class PlaylistPickerSheet extends StatelessWidget {
  const PlaylistPickerSheet({super.key, this.playlists});

  final PlaylistsCubit? playlists;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PlaylistsCubit>(
      create: (_) => (playlists ?? getIt<PlaylistsCubit>())..load(),
      child: const _PlaylistPickerView(),
    );
  }
}

class _PlaylistPickerView extends StatelessWidget {
  const _PlaylistPickerView();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.spacing.md,
                t.spacing.md,
                t.spacing.md,
                t.spacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add to Playlist', style: t.typography.titleMedium),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('New Playlist'),
              onTap: () => _createAndPick(context),
            ),
            const Divider(height: 1),
            Expanded(
              child:
                  BlocBuilder<PlaylistsCubit, PagedCollectionState<Playlist>>(
                    builder: (context, state) {
                      final cubit = context.read<PlaylistsCubit>();
                      return PagedCollectionView<Playlist>(
                        state: state,
                        skeleton: const MusicListSkeleton(itemCount: 4),
                        emptyTitle: 'No playlists yet',
                        emptyMessage: 'Create one below to get started.',
                        emptyIcon: Icons.queue_music_outlined,
                        onLoadMore: cubit.loadMore,
                        onRefresh: cubit.refresh,
                        onRetry: cubit.reload,
                        onRetryLoadMore: cubit.retryLoadMore,
                        itemBuilder: (context, playlist, _) => PlaylistRow(
                          playlist: playlist,
                          onTap: () => Navigator.of(context).pop(playlist.id),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndPick(BuildContext context) async {
    final name = await promptForPlaylistName(
      context,
      title: 'New Playlist',
      confirmLabel: 'Create',
    );
    if (name == null) return;
    if (!context.mounted) return;

    final result = await getIt<PlaylistCurationService>().createPlaylist(
      name,
    );
    if (!context.mounted) return;

    switch (result) {
      case Ok<MediaId>(:final value):
        Navigator.of(context).pop(value);
      case Err<MediaId>(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}
