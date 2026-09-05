import 'package:flutter/material.dart';

import '../../../../core/result/result.dart';
import '../../../../domain/media/MediaId.dart';
import 'PlaylistPickerSheet.dart';

/// Opens the playlist picker, then runs [add] against whatever playlist
/// the user picked (or just created), and reports the outcome.
///
/// One flow shared by every "add to playlist" entry point — a single
/// track's overflow menu, or a whole album/artist/playlist's bulk add —
/// since picking a destination and reporting success/failure is identical
/// in each case; only [add] itself differs.
Future<void> addToPlaylistFlow(
  BuildContext context, {
  required Future<Result<void>> Function(MediaId playlistId) add,
  String successMessage = 'Added to playlist.',
}) async {
  final target = await showPlaylistPicker(context);
  if (target == null || !context.mounted) return;

  final result = await add(target);
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case Ok<void>():
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    case Err<void>(:final failure):
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
  }
}
