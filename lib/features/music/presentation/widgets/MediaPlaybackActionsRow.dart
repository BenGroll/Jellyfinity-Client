import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/playback/PlaybackCubit.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import 'PlaylistPickerSheet.dart';

/// The Shuffle / Play / overflow row Album and Playlist headers share
/// (v0.1.6), replacing the single "Play" button both used to show.
///
/// [tracks] is whatever the screen has loaded so far — the same "enough
/// to back the button without a second fetch" contract the old Play
/// button already relied on.
class MediaPlaybackActionsRow extends StatelessWidget {
  const MediaPlaybackActionsRow({super.key, required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasTracks = tracks.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shuffle_rounded),
          tooltip: 'Shuffle',
          color: t.colors.textPrimary,
          onPressed: hasTracks
              ? () => context.read<PlaybackCubit>().playShuffled(tracks)
              : null,
        ),
        SizedBox(width: t.spacing.lg),
        IconButton(
          iconSize: 56,
          icon: const Icon(Icons.play_circle_filled_rounded),
          color: t.colors.accent,
          tooltip: 'Play',
          onPressed: hasTracks
              ? () =>
                    context.read<PlaybackCubit>().playNow(tracks, startIndex: 0)
              : null,
        ),
        SizedBox(width: t.spacing.lg),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'More',
          color: t.colors.textPrimary,
          onPressed: hasTracks ? () => _openMenu(context) : null,
        ),
      ],
    );
  }

  void _openMenu(BuildContext context) {
    final playback = context.read<PlaybackCubit>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _addToPlaylist(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to queue'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                playback.addAllToQueue(tracks);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToPlaylist(BuildContext context) async {
    final playlist = await showPlaylistPicker(context);
    if (playlist == null || !context.mounted) return;

    final result = await getIt<PlaylistRepository>().addTracks(playlist.id, [
      for (final track in tracks) track.id,
    ]);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isOk
              ? 'Added to "${playlist.name}"'
              : 'Could not add to "${playlist.name}"',
        ),
      ),
    );
  }
}
