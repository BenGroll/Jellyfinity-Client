import 'package:flutter/material.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/media/media.dart';

/// Creating, renaming, deleting, and removing from playlists — the
/// curation actions v0.1.2 specified and left unbuilt.
///
/// Free functions over `getIt<PlaylistRepository>()` rather than a cubit,
/// the same shape the favorite toggle uses (v0.1.6): each is a one-shot
/// mutation with no state to hold between calls, and the screens that
/// invoke them already own the list that has to reload afterwards.
///
/// Every one of them asks first and says what happened afterwards. A
/// playlist is something the user made by hand, so an edit that silently
/// succeeds or silently fails is the worst outcome available.

/// Asks for a playlist name.
///
/// Returns the trimmed name, or `null` if the user backed out. A blank
/// name cannot be confirmed — an untitled playlist is not findable again.
Future<String?> promptForPlaylistName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _NameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
    ),
  );
}

/// Creates a playlist, asking for its name first, and answers with the
/// playlist that now exists — or `null` if the user backed out or the
/// server refused.
///
/// The name comes back alongside the id because every caller needs both:
/// one to navigate to the new playlist, the other to name it on screen
/// before any read has returned it.
///
/// [trackIds] seeds the new playlist, for a caller that is creating one
/// around something the user is already looking at.
Future<({MediaId id, String name})?> createPlaylist(
  BuildContext context, {
  List<MediaId> trackIds = const [],
}) async {
  final name = await promptForPlaylistName(
    context,
    title: 'New playlist',
    confirmLabel: 'Create',
  );
  if (name == null || !context.mounted) return null;

  final messenger = ScaffoldMessenger.of(context);
  final result = await getIt<PlaylistRepository>().create(
    name,
    trackIds: trackIds,
  );

  switch (result) {
    case Ok<MediaId>(:final value):
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            trackIds.isEmpty
                ? 'Created "$name".'
                : 'Created "$name" with '
                      '${trackIds.length} '
                      '${trackIds.length == 1 ? 'song' : 'songs'}.',
          ),
        ),
      );
      return (id: value, name: name);
    case Err<MediaId>(:final failure):
      messenger.showSnackBar(
        SnackBar(content: Text('Could not create "$name". ${failure.message}')),
      );
      return null;
  }
}

/// Renames [playlist], asking for the new name first. Answers whether the
/// server accepted it, so the caller knows whether to reload.
Future<bool> renamePlaylist(BuildContext context, Playlist playlist) async {
  final name = await promptForPlaylistName(
    context,
    title: 'Rename playlist',
    confirmLabel: 'Rename',
    initialValue: playlist.name,
  );
  if (name == null || name == playlist.name || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  final result = await getIt<PlaylistRepository>().rename(playlist.id, name);
  if (result case Err<void>(:final failure)) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not rename the playlist. ${failure.message}'),
      ),
    );
    return false;
  }
  messenger.showSnackBar(SnackBar(content: Text('Renamed to "$name".')));
  return true;
}

/// Deletes [playlist] after confirming. Answers whether it is gone.
///
/// The confirmation says the songs stay, because that is the fear the
/// action provokes — the same reasoning `confirmRemoveDownload` follows
/// for removing a download.
Future<bool> deletePlaylist(BuildContext context, Playlist playlist) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete "${playlist.name}"?'),
      content: const Text(
        'The playlist is deleted from your server. The songs in it stay in '
        'your library.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (!(confirmed ?? false) || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  final result = await getIt<PlaylistRepository>().delete(playlist.id);
  if (result case Err<void>(:final failure)) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not delete the playlist. ${failure.message}'),
      ),
    );
    return false;
  }
  messenger.showSnackBar(
    SnackBar(content: Text('Deleted "${playlist.name}".')),
  );
  return true;
}

/// Removes one row from a playlist. Answers whether it is gone.
///
/// Takes the [PlaylistTrack] rather than a track id: it is one appearance
/// of a song that is being removed, and a playlist may list that song
/// more than once.
Future<bool> removeFromPlaylist(
  BuildContext context, {
  required MediaId playlistId,
  required PlaylistTrack row,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await getIt<PlaylistRepository>().removeEntries(playlistId, [
    row.entryId,
  ]);
  if (result case Err<void>(:final failure)) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not remove "${row.name}". ${failure.message}'),
      ),
    );
    return false;
  }
  messenger.showSnackBar(
    SnackBar(content: Text('Removed "${row.name}" from the playlist.')),
  );
  return true;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialValue,
  });

  final String title;
  final String confirmLabel;
  final String initialValue;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  void _submit() {
    if (_name.isEmpty) return;
    Navigator.of(context).pop(_name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Late night listening',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          // A playlist with no name cannot be found again, so there is
          // nothing sensible to do with an empty field but wait.
          onPressed: _name.isEmpty ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
