import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/detail/playlist_edit_cubit.dart';

import '../../support/music_fakes.dart';

/// A copy of [track] carrying [entryId] — what a real playlist read
/// attaches (`BaseItemMapper.toTrack` from `dto.playlistItemId`), which
/// `testTrack` does not set.
Track _withEntryId(Track track, String entryId) => Track(
  id: track.id,
  name: track.name,
  artists: track.artists,
  albumId: track.albumId,
  albumName: track.albumName,
  trackNumber: track.trackNumber,
  discNumber: track.discNumber,
  duration: track.duration,
  playlistEntryId: entryId,
  availability: track.availability,
  image: track.image,
);

void main() {
  late FakePlaylistRepository playlists;
  late FakePlaylistEditor editor;
  late PlaylistEditCubit cubit;

  setUp(() {
    playlists = FakePlaylistRepository();
    editor = FakePlaylistEditor();
    cubit = PlaylistEditCubit(playlists, editor);
  });

  tearDown(() => cubit.close());

  test('loads the whole playlist, across more than one page', () async {
    playlists.trackList = List.generate(
      250,
      (i) => testTrack('t$i', name: 'Track $i'),
    );

    await cubit.startEditing(mediaId('pl1'));

    expect(cubit.state.status, PlaylistEditStatus.ready);
    expect(cubit.state.tracks, hasLength(250));
  });

  test('a failed load reports the failure', () async {
    playlists.failure = const RecoverableFailure('offline');

    await cubit.startEditing(mediaId('pl1'));

    expect(cubit.state.status, PlaylistEditStatus.failed);
    expect(cubit.state.failure, isNotNull);
  });

  test('reorder updates local order immediately and confirms it', () async {
    // Each track needs a distinct entry id, the way a real playlist read
    // would give it (BaseItemMapper.toTrack -> dto.playlistItemId).
    playlists.trackList = [
      _withEntryId(testTrack('t1', name: 'One'), 'e1'),
      _withEntryId(testTrack('t2', name: 'Two'), 'e2'),
      _withEntryId(testTrack('t3', name: 'Three'), 'e3'),
    ];
    await cubit.startEditing(mediaId('pl1'));

    await cubit.reorder(0, 2);

    expect(
      cubit.state.tracks.map((t) => t.name),
      ['Two', 'Three', 'One'],
    );
    expect(editor.calls.single, contains('moveEntry'));
    expect(editor.calls.single, contains('e1'));
  });

  test('a failed reorder reloads from the server', () async {
    playlists.trackList = [
      _withEntryId(testTrack('t1', name: 'One'), 'e1'),
      _withEntryId(testTrack('t2', name: 'Two'), 'e2'),
    ];
    await cubit.startEditing(mediaId('pl1'));
    editor.failure = const RecoverableFailure('offline');

    await cubit.reorder(0, 1);

    // Reconciled back to the server's real (unchanged) order.
    expect(cubit.state.tracks.map((t) => t.name), ['One', 'Two']);
  });

  test('remove drops the entry immediately and confirms it', () async {
    final track = _withEntryId(testTrack('t1', name: 'One'), 'e1');
    playlists.trackList = [
      track,
      _withEntryId(testTrack('t2', name: 'Two'), 'e2'),
    ];
    await cubit.startEditing(mediaId('pl1'));

    await cubit.remove(track);

    expect(cubit.state.tracks.map((t) => t.name), ['Two']);
    expect(editor.calls.single, contains('removeEntries'));
    expect(editor.calls.single, contains('e1'));
  });

  test('stopEditing turns edit mode off without discarding progress', () async {
    playlists.trackList = [_withEntryId(testTrack('t1'), 'e1')];
    await cubit.startEditing(mediaId('pl1'));

    cubit.stopEditing();

    expect(cubit.state.editing, isFalse);
  });
}
