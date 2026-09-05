import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../library/music_collection_cubits.dart';
import '../library/paged_collection_cubit.dart';
import 'music_rows.dart';
import 'music_skeletons.dart';

/// Lets the user pick one of their playlists — the picker behind Album and
/// Playlist's "Add to playlist" action (v0.1.6). Resolves to the chosen
/// [Playlist], or `null` if the sheet was dismissed without a choice.
Future<Playlist?> showPlaylistPicker(BuildContext context) {
  return showModalBottomSheet<Playlist>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider<PlaylistsCubit>(
      create: (_) => getIt<PlaylistsCubit>()..load(),
      child: const _PlaylistPickerSheet(),
    ),
  );
}

class _PlaylistPickerSheet extends StatelessWidget {
  const _PlaylistPickerSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SafeArea(
      child: SizedBox(
        // A fixed fraction of the screen, computed from MediaQuery rather
        // than FractionallySizedBox: a modal sheet gives its content loose
        // height constraints, and FractionallySizedBox cannot resolve a
        // percentage of a constraint that is itself sized to its content.
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(t.spacing.md),
              child: Text(
                'Add to playlist',
                style: t.typography.titleLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child:
                  BlocBuilder<PlaylistsCubit, PagedCollectionState<Playlist>>(
                    builder: (context, state) {
                      if (state.status == CollectionStatus.initial ||
                          state.status == CollectionStatus.loading) {
                        // MusicListSkeleton is a fixed-height Column meant
                        // for a scrolling sliver ancestor; this sheet's
                        // area is a bounded, non-scrolling Expanded, so it
                        // needs its own scroll view rather than the outer
                        // CustomScrollView every other screen provides.
                        return const SingleChildScrollView(
                          child: MusicListSkeleton(),
                        );
                      }
                      final failure = state.failure;
                      if (failure != null) {
                        return ErrorStateView.forFailure(
                          failure,
                          onRetry: context.read<PlaylistsCubit>().reload,
                        );
                      }
                      if (state.items.isEmpty) {
                        return const EmptyStateView(
                          title: 'No playlists yet',
                          message:
                              'Create a playlist on your Jellyfin server '
                              'first.',
                          icon: Icons.queue_music_outlined,
                        );
                      }
                      return ListView.builder(
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final playlist = state.items[index];
                          return PlaylistRow(
                            playlist: playlist,
                            onTap: () => Navigator.of(context).pop(playlist),
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
