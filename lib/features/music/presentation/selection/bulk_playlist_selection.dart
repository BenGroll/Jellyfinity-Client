import 'package:flutter/material.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../domain/media/media.dart';
import '../widgets/PlaylistPickerSheet.dart';
import 'TrackSelectionCubit.dart';

/// Adds every checked track in [selection] to an existing or new playlist
/// (v0.7.0), in the order the tracks appear in [selectableTracks] — the
/// caller's currently loaded, currently playable rows, already in
/// displayed order.
///
/// [selectableTracks] rather than the whole loaded page is what makes
/// "unavailable rows" explicit: a checked id no longer present in it (the
/// row went unavailable, or scrolled-away paging never loaded it) is
/// silently dropped from what gets sent, and the count in the result
/// message says so. `PlaylistRepository.addTracks` answers for the whole
/// batch rather than row by row (ADR-0048), so that is also where "partial
/// success" is decided: everything requested that is still valid, sent in
/// one call, all-or-nothing from the server's point of view.
Future<void> addSelectedTracksToPlaylist(
  BuildContext context,
  TrackSelectionCubit selection,
  List<Track> selectableTracks,
) async {
  final requested = selection.state.selected;
  final orderedIds = <MediaId>[
    for (final track in selectableTracks)
      if (requested.contains(track.id)) track.id,
  ];
  final droppedCount = requested.length - orderedIds.length;

  if (orderedIds.isEmpty) {
    selection.exit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Those songs are no longer available to add.'),
      ),
    );
    return;
  }

  final playlist = await showPlaylistPicker(context);
  if (playlist == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final result = await getIt<PlaylistRepository>().addTracks(
    playlist.id,
    orderedIds,
  );

  result.when(
    ok: (_) {
      selection.exit();
      final count = orderedIds.length;
      final noun = count == 1 ? 'song' : 'songs';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            droppedCount > 0
                ? 'Added $count $noun to "${playlist.name}" — '
                      '$droppedCount no longer available were skipped.'
                : 'Added $count $noun to "${playlist.name}".',
          ),
        ),
      );
    },
    err: (failure) {
      // Kept selected, not cleared: a transient failure should be
      // retryable without reselecting everything, but the rows already
      // dropped as unavailable stay dropped.
      selection.retainOnly(orderedIds.toSet());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not add to "${playlist.name}". ${failure.message}',
          ),
        ),
      );
    },
  );
}
