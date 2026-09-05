import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/playlists/PlaylistCurationService.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';

import '../../support/music_fakes.dart';

void main() {
  late FakeMusicLibraryRepository music;
  late FakePlaylistRepository playlists;
  late FakePlaylistEditor editor;
  late PlaylistCurationService service;

  setUp(() {
    music = FakeMusicLibraryRepository();
    playlists = FakePlaylistRepository();
    editor = FakePlaylistEditor();
    service = PlaylistCurationService(editor, playlists, music);
  });

  test('addAlbum pages through every track before adding them', () async {
    music.trackList = List.generate(250, (i) => testTrack('t$i'));
    final target = mediaId('target');

    final result = await service.addAlbum(target, mediaId('al1'));

    expect(result.isOk, isTrue);
    expect(editor.calls, hasLength(1));
    // Every one of the 250 tracks made it into the single addTracks call.
    expect(editor.calls.single, contains('t0'));
    expect(editor.calls.single, contains('t249'));
  });

  test('addArtist skips unavailable rows rather than failing', () async {
    music.trackList = [testTrack('t1'), testTrack('t2')];
    music.unavailable = const [
      UnavailableItem(id: 'm1', reason: 'Not a song.'),
    ];
    final target = mediaId('target');

    final result = await service.addArtist(target, mediaId('artist1'));

    expect(result.isOk, isTrue);
    expect(editor.calls.single, isNot(contains('m1')));
  });

  test('addAlbum surfaces a failure part-way through paging', () async {
    // More than one page, so failureAfterFirstPage can bite.
    music.trackList = List.generate(400, (i) => testTrack('t$i'));
    music.failureAfterFirstPage = const RecoverableFailure('offline');
    final target = mediaId('target');

    final result = await service.addAlbum(target, mediaId('al1'));

    expect(result.isErr, isTrue);
    expect(editor.calls, isEmpty);
  });

  test('addPlaylist copies a source playlist\'s tracks, in order', () async {
    playlists.trackList = [testTrack('t1'), testTrack('t2')];
    final target = mediaId('target');

    final result = await service.addPlaylist(target, mediaId('source'));

    expect(result.isOk, isTrue);
    final call = editor.calls.single;
    expect(call.indexOf('t1'), lessThan(call.indexOf('t2')));
  });

  group('mergePlaylists', () {
    test('creates a new playlist and copies every source into it', () async {
      playlists.trackList = [testTrack('t1')];

      final result = await service.mergePlaylists(
        name: 'Merged',
        sourcePlaylistIds: [mediaId('a'), mediaId('b')],
      );

      expect(result.isOk, isTrue);
      expect(editor.calls.first, contains('create(Merged)'));
      // One addTracks call per source, after the create.
      expect(editor.calls.where((c) => c.startsWith('addTracks')), hasLength(2));
      expect(editor.calls.where((c) => c.startsWith('delete')), isEmpty);
    });

    test('deletes sources only after they have been copied', () async {
      playlists.trackList = [testTrack('t1')];
      final sourceA = mediaId('a');
      final sourceB = mediaId('b');

      await service.mergePlaylists(
        name: 'Merged',
        sourcePlaylistIds: [sourceA, sourceB],
        deleteSources: true,
      );

      final addIndexes = <int>[];
      final deleteIndexes = <int>[];
      for (var i = 0; i < editor.calls.length; i++) {
        if (editor.calls[i].startsWith('addTracks')) addIndexes.add(i);
        if (editor.calls[i].startsWith('delete')) deleteIndexes.add(i);
      }
      expect(deleteIndexes, hasLength(2));
      // Every add happened before every delete.
      expect(addIndexes.every((a) => deleteIndexes.every((d) => a < d)), isTrue);
    });

    test('never deletes a source when copying it failed', () async {
      playlists.trackList = [testTrack('t1')];
      editor.failure = const RecoverableFailure('offline');

      final result = await service.mergePlaylists(
        name: 'Merged',
        sourcePlaylistIds: [mediaId('a')],
        deleteSources: true,
      );

      expect(result.isErr, isTrue);
      expect(editor.calls.any((c) => c.startsWith('delete')), isFalse);
    });
  });
}
