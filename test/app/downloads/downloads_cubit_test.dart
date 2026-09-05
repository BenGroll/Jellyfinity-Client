import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/downloads/DownloadsCubit.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';

import '../../support/download_fakes.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';

void main() {
  late InMemoryDownloadStore store;
  late FakeDownloadEngine engine;
  late FakeAudioSourceResolver resolver;
  late FakeMusicLibraryRepository library;
  late FakePlaylistRepository playlists;
  late DownloadsCubit cubit;

  setUp(() {
    store = InMemoryDownloadStore();
    engine = FakeDownloadEngine();
    resolver = FakeAudioSourceResolver();
    library = FakeMusicLibraryRepository();
    playlists = FakePlaylistRepository();
    cubit = fakeDownloadsCubit(
      store: store,
      engine: engine,
      resolver: resolver,
      library: library,
      playlists: playlists,
    );
  });

  tearDown(() => cubit.close());

  group('requesting a track', () {
    test('queues, transfers, and completes it', () async {
      final track = testTrack('t1');

      await cubit.downloadTrack(track);
      await pumpEventQueue();

      final record = cubit.state[track.id]!;
      expect(record.state, DownloadState.completed);
      expect(engine.fetched, [track.id]);
      expect(store.records[track.id]?.state, DownloadState.completed);
    });

    test('adding it again does not fetch it twice', () async {
      final track = testTrack('t1');
      await cubit.downloadTrack(track);
      await pumpEventQueue();

      await cubit.downloadTrack(track);
      await pumpEventQueue();

      expect(engine.fetched, [track.id]);
    });

    test(
      'being downloaded on its own and via an album keeps two owners',
      () async {
        final track = testTrack('t1', albumId: 'album-1');
        library.trackList = [track];

        await cubit.downloadTrack(track);
        await cubit.downloadAlbum(testAlbum('album-1'));
        await pumpEventQueue();

        expect(engine.fetched, [track.id]);
        expect(cubit.state[track.id]?.owners, {
          DownloadOwner.track(track.id),
          DownloadOwner.album(mediaId('album-1')),
        });
      },
    );
  });

  group('requesting an album', () {
    test('queues every track the album has', () async {
      final album = testAlbum('album-1');
      library.trackList = [
        testTrack('t1', albumId: 'album-1'),
        testTrack('t2', albumId: 'album-1'),
      ];

      final result = await cubit.downloadAlbum(album);
      await pumpEventQueue();

      expect(result.isOk, isTrue);
      expect(engine.fetched.toSet(), {mediaId('t1'), mediaId('t2')});
      expect(cubit.state.isDownloaded(mediaId('t1')), isTrue);
      expect(cubit.state.isDownloaded(mediaId('t2')), isTrue);
    });

    test(
      'reports a failure instead of queuing anything it could not read',
      () async {
        library.failure = const UnavailableFailure('no such album');

        final result = await cubit.downloadAlbum(testAlbum('album-1'));

        expect(result.isErr, isTrue);
        expect(cubit.state.downloads, isEmpty);
      },
    );

    test('an empty album queues nothing and does not fail', () async {
      final result = await cubit.downloadAlbum(testAlbum('album-1'));
      expect(result.isOk, isTrue);
      expect(cubit.state.downloads, isEmpty);
    });
  });

  group('the worker', () {
    test('runs one transfer at a time, oldest request first', () async {
      final first = testTrack('t1');
      final second = testTrack('t2');
      // Hold the first transfer open so the second cannot start early.
      engine.gates[first.id] = Completer<void>();

      await cubit.downloadTrack(first);
      await cubit.downloadTrack(second);
      await pumpEventQueue();

      expect(engine.fetched, [first.id]);
      expect(cubit.state[second.id]?.state, DownloadState.queued);

      engine.gates[first.id]!.complete();
      await pumpEventQueue();

      expect(engine.fetched, [first.id, second.id]);
      expect(cubit.state[second.id]?.state, DownloadState.completed);
    });
  });

  group('pausing and retrying', () {
    test(
      'pause keeps bytes and stops the transfer without failing it',
      () async {
        final track = testTrack('t1');
        engine.gates[track.id] = Completer<void>();
        await cubit.downloadTrack(track);
        await pumpEventQueue();

        await cubit.pause(track.id);
        await pumpEventQueue();

        expect(engine.aborted, [track.id]);
        expect(cubit.state[track.id]?.state, DownloadState.paused);
        expect(cubit.state[track.id]?.failureReason, isNull);
      },
    );

    test('retry queues a paused download again', () async {
      final track = testTrack('t1');
      engine.gates[track.id] = Completer<void>();
      await cubit.downloadTrack(track);
      await pumpEventQueue();
      await cubit.pause(track.id);

      // The gate from the aborted attempt is gone; the retried fetch
      // completes normally.
      await cubit.retry(track.id);
      await pumpEventQueue();

      expect(cubit.state[track.id]?.state, DownloadState.completed);
    });

    test('a failed download can be retried', () async {
      final track = testTrack('t1');
      engine.failures[track.id] = const UnavailableFailure('gone');
      await cubit.downloadTrack(track);
      await pumpEventQueue();
      expect(cubit.state[track.id]?.state, DownloadState.failed);

      engine.failures.remove(track.id);
      await cubit.retry(track.id);
      await pumpEventQueue();

      expect(cubit.state[track.id]?.state, DownloadState.completed);
    });

    test(
      'retryAll retries every failed/paused track an owner asked for',
      () async {
        final album = testAlbum('album-1');
        final t1 = testTrack('t1', albumId: 'album-1');
        final t2 = testTrack('t2', albumId: 'album-1');
        library.trackList = [t1, t2];
        engine.failures[t1.id] = const UnavailableFailure('gone');
        engine.failures[t2.id] = const UnavailableFailure('gone');

        await cubit.downloadAlbum(album);
        await pumpEventQueue();
        expect(cubit.state[t1.id]?.state, DownloadState.failed);
        expect(cubit.state[t2.id]?.state, DownloadState.failed);

        engine.failures.clear();
        await cubit.retryAll(DownloadOwner.album(album.id));
        await pumpEventQueue();

        expect(cubit.state[t1.id]?.state, DownloadState.completed);
        expect(cubit.state[t2.id]?.state, DownloadState.completed);
      },
    );

    test(
      'an abort from pause does not get overwritten by a late failure',
      () async {
        final track = testTrack('t1');
        engine.gates[track.id] = Completer<void>();
        engine.failures[track.id] = const UnavailableFailure('gone');
        await cubit.downloadTrack(track);
        await pumpEventQueue();

        // Pause races the engine's own eventual failure for the aborted
        // transfer (FakeDownloadEngine.abort completes the gate itself,
        // the same way a real engine's cancellation unblocks its
        // stream); the user's pause must win.
        await cubit.pause(track.id);
        await pumpEventQueue();

        expect(cubit.state[track.id]?.state, DownloadState.paused);
      },
    );
  });

  group('failure reasons', () {
    test('maps an unauthorized source to a sign-in-again reason', () async {
      final track = testTrack('t1');
      resolver.unresolvable.add(track.id.itemId);

      await cubit.downloadTrack(track);
      await pumpEventQueue();

      expect(
        cubit.state[track.id]?.failureReason,
        DownloadFailureReason.unavailable,
      );
    });

    test('maps insufficient storage distinctly from other failures', () async {
      final track = testTrack('t1');
      engine.failures[track.id] = const InsufficientStorageFailure('full');

      await cubit.downloadTrack(track);
      await pumpEventQueue();

      expect(
        cubit.state[track.id]?.failureReason,
        DownloadFailureReason.insufficientStorage,
      );
    });
  });

  group('removing', () {
    test(
      'removing a track with no owner drops every claim and the file',
      () async {
        final track = testTrack('t1', albumId: 'album-1');
        library.trackList = [track];
        await cubit.downloadTrack(track);
        await cubit.downloadAlbum(testAlbum('album-1'));
        await pumpEventQueue();

        await cubit.removeTrack(track.id);

        expect(cubit.state[track.id], isNull);
        expect(engine.discarded, [track.id]);
        expect(store.records[track.id], isNull);
      },
    );

    test(
      'removing an album keeps a track also downloaded on its own',
      () async {
        final track = testTrack('t1', albumId: 'album-1');
        final album = testAlbum('album-1');
        library.trackList = [track];
        await cubit.downloadTrack(track);
        await cubit.downloadAlbum(album);
        await pumpEventQueue();

        await cubit.removeAlbum(album.id);

        expect(cubit.state[track.id]?.state, DownloadState.completed);
        expect(cubit.state[track.id]?.owners, {DownloadOwner.track(track.id)});
        expect(engine.discarded, isEmpty);
      },
    );

    test('removing the last owner deletes the file', () async {
      final track = testTrack('t1', albumId: 'album-1');
      final album = testAlbum('album-1');
      library.trackList = [track];
      await cubit.downloadAlbum(album);
      await pumpEventQueue();

      await cubit.removeAlbum(album.id);

      expect(cubit.state[track.id], isNull);
      expect(engine.discarded, [track.id]);
    });

    test('cancels an in-flight transfer before discarding it', () async {
      final track = testTrack('t1');
      engine.gates[track.id] = Completer<void>();
      await cubit.downloadTrack(track);
      await pumpEventQueue();

      await cubit.removeTrack(track.id);

      expect(engine.aborted, [track.id]);
      expect(engine.discarded, [track.id]);
    });
  });

  group('restart recovery', () {
    test('an interrupted download resumes from its partial bytes', () async {
      final track = testTrack('t1');
      store.records[track.id] = downloadRecord(
        track.id,
        title: track.name,
        state: DownloadState.downloading,
        receivedBytes: 0,
      );
      engine.partials[track.id] = 4096;

      await cubit.restore();
      await pumpEventQueue();

      // It picks up as a normal queued download and finishes.
      expect(cubit.state[track.id]?.state, DownloadState.completed);
      expect(engine.fetched, [track.id]);
    });

    test('a completed record survives a restart untouched', () async {
      final track = testTrack('t1');
      store.records[track.id] = downloadRecord(
        track.id,
        state: DownloadState.completed,
        totalBytes: 900,
        receivedBytes: 900,
      );

      await cubit.restore();
      await pumpEventQueue();

      expect(cubit.state[track.id]?.state, DownloadState.completed);
      // Nothing was re-fetched — it was already done.
      expect(engine.fetched, isEmpty);
    });

    test(
      'a paused record stays paused rather than resuming on its own',
      () async {
        final track = testTrack('t1');
        store.records[track.id] = downloadRecord(
          track.id,
          state: DownloadState.paused,
        );

        await cubit.restore();
        await pumpEventQueue();

        expect(cubit.state[track.id]?.state, DownloadState.paused);
        expect(engine.fetched, isEmpty);
      },
    );

    test('a downloaded playlist\'s snapshot is restored', () async {
      final t1 = testTrack('t1');
      final t2 = testTrack('t2');
      store.records[t1.id] = downloadRecord(
        t1.id,
        state: DownloadState.completed,
        owners: {DownloadOwner.playlist(mediaId('pl-1'))},
      );
      store.records[t2.id] = downloadRecord(
        t2.id,
        state: DownloadState.completed,
        owners: {DownloadOwner.playlist(mediaId('pl-1'))},
      );
      store.playlistSnapshots[mediaId('pl-1')] = [
        (position: 0, trackId: t1.id),
        (position: 1, trackId: t2.id),
      ];

      await cubit.restore();
      await pumpEventQueue();

      expect(cubit.state.isPlaylistDownloaded(mediaId('pl-1')), isTrue);
      expect(
        cubit.state
            .playlistDownloadsInOrder(mediaId('pl-1'))
            .map((r) => r.id.itemId),
        ['t1', 't2'],
      );
    });
  });

  group('requesting a playlist (v0.2.1)', () {
    test(
      'queues every member in playlist order and records a snapshot',
      () async {
        playlists.trackList = [
          testTrack('t1'),
          testTrack('t2'),
          testTrack('t3'),
        ];

        final result = await cubit.downloadPlaylist(testPlaylist('pl-1'));
        await pumpEventQueue();

        expect(result.isOk, isTrue);
        expect(engine.fetched, [mediaId('t1'), mediaId('t2'), mediaId('t3')]);
        expect(
          cubit.state
              .playlistDownloadsInOrder(mediaId('pl-1'))
              .map((r) => r.id.itemId),
          ['t1', 't2', 't3'],
        );
        expect(store.playlistSnapshots[mediaId('pl-1')], hasLength(3));
      },
    );

    test('reuses a track already downloaded on its own', () async {
      final shared = testTrack('t1');
      playlists.trackList = [shared, testTrack('t2')];

      await cubit.downloadTrack(shared);
      await pumpEventQueue();
      await cubit.downloadPlaylist(testPlaylist('pl-1'));
      await pumpEventQueue();

      // t1 fetched once, for the standalone request; the playlist only
      // adds a reason to keep it.
      expect(engine.fetched, [mediaId('t1'), mediaId('t2')]);
      expect(cubit.state[shared.id]?.owners, {
        DownloadOwner.track(shared.id),
        DownloadOwner.playlist(mediaId('pl-1')),
      });
    });

    test('reports a failure when the playlist could not be read', () async {
      playlists.failure = const UnavailableFailure('no such playlist');

      final result = await cubit.downloadPlaylist(testPlaylist('pl-1'));

      expect(result.isErr, isTrue);
      expect(cubit.state.isPlaylistDownloaded(mediaId('pl-1')), isFalse);
    });
  });

  group('removing a playlist (v0.2.1)', () {
    test('drops the file when nothing else wants it', () async {
      playlists.trackList = [testTrack('t1'), testTrack('t2')];
      await cubit.downloadPlaylist(testPlaylist('pl-1'));
      await pumpEventQueue();

      await cubit.removePlaylist(mediaId('pl-1'));

      expect(cubit.state[mediaId('t1')], isNull);
      expect(engine.discarded.toSet(), {mediaId('t1'), mediaId('t2')});
      expect(cubit.state.isPlaylistDownloaded(mediaId('pl-1')), isFalse);
      expect(store.playlistSnapshots[mediaId('pl-1')], isNull);
    });

    test('keeps a member another playlist still lists', () async {
      final shared = testTrack('t1');
      playlists.tracksByPlaylist['pl-1'] = [shared, testTrack('t2')];
      playlists.tracksByPlaylist['pl-2'] = [shared];

      await cubit.downloadPlaylist(testPlaylist('pl-1'));
      await pumpEventQueue();
      await cubit.downloadPlaylist(testPlaylist('pl-2'));
      await pumpEventQueue();

      await cubit.removePlaylist(mediaId('pl-1'));

      expect(cubit.state[shared.id]?.state, DownloadState.completed);
      expect(cubit.state[shared.id]?.owners, {
        DownloadOwner.playlist(mediaId('pl-2')),
      });
      expect(cubit.state[mediaId('t2')], isNull);
    });
  });

  group('reconciling a playlist (v0.2.1)', () {
    test('queues a track added to the playlist on the server', () async {
      playlists.tracksByPlaylist['pl-1'] = [testTrack('t1')];
      await cubit.downloadPlaylist(testPlaylist('pl-1'));
      await pumpEventQueue();

      playlists.tracksByPlaylist['pl-1'] = [testTrack('t1'), testTrack('t2')];
      final change = await cubit.reconcilePlaylist(mediaId('pl-1'));
      await pumpEventQueue();

      expect(change.added, 1);
      expect(change.removed, 0);
      expect(cubit.state.isDownloaded(mediaId('t2')), isTrue);
      expect(
        cubit.state
            .playlistDownloadsInOrder(mediaId('pl-1'))
            .map((r) => r.id.itemId),
        ['t1', 't2'],
      );
    });

    test('drops the claim on a track removed from the playlist', () async {
      playlists.tracksByPlaylist['pl-1'] = [testTrack('t1'), testTrack('t2')];
      await cubit.downloadPlaylist(testPlaylist('pl-1'));
      await pumpEventQueue();

      playlists.tracksByPlaylist['pl-1'] = [testTrack('t1')];
      final change = await cubit.reconcilePlaylist(mediaId('pl-1'));
      await pumpEventQueue();

      expect(change.removed, 1);
      expect(change.removedButKept, 0);
      expect(cubit.state[mediaId('t2')], isNull);
      expect(engine.discarded, contains(mediaId('t2')));
    });

    test(
      'keeps a removed member the user also downloaded on its own',
      () async {
        final shared = testTrack('t2');
        playlists.tracksByPlaylist['pl-1'] = [testTrack('t1'), shared];
        await cubit.downloadPlaylist(testPlaylist('pl-1'));
        await cubit.downloadTrack(shared);
        await pumpEventQueue();

        playlists.tracksByPlaylist['pl-1'] = [testTrack('t1')];
        final change = await cubit.reconcilePlaylist(mediaId('pl-1'));
        await pumpEventQueue();

        expect(change.removed, 1);
        expect(change.removedButKept, 1);
        expect(cubit.state[shared.id]?.owners, {
          DownloadOwner.track(shared.id),
        });
      },
    );

    test('does nothing for a playlist that is not downloaded', () async {
      final change = await cubit.reconcilePlaylist(mediaId('pl-1'));
      expect(change.isEmpty, isTrue);
    });

    test('does not reconcile against a cache-served read', () async {
      playlists.tracksByPlaylist['pl-1'] = [testTrack('t1')];
      await cubit.downloadPlaylist(testPlaylist('pl-1'));
      await pumpEventQueue();

      playlists.tracksByPlaylist['pl-1'] = [testTrack('t1'), testTrack('t2')];
      playlists.source = PageSource.cache;
      final change = await cubit.reconcilePlaylist(mediaId('pl-1'));

      expect(change.isEmpty, isTrue);
      expect(cubit.state.stateOf(mediaId('t2')), isNull);
    });
  });
}
