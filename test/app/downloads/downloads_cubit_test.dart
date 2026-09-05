import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/downloads/DownloadsCubit.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/app/session/SessionState.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';

import '../../support/download_fakes.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/session_fakes.dart';
import '../../support/settings_fakes.dart';

void main() {
  late InMemoryDownloadStore store;
  late FakeDownloadEngine engine;
  late FakeAudioSourceResolver resolver;
  late FakeMusicLibraryRepository library;
  late FakePlaylistRepository playlists;
  late SessionCubit session;
  late DownloadsCubit cubit;

  setUp(() {
    store = InMemoryDownloadStore();
    engine = FakeDownloadEngine();
    resolver = FakeAudioSourceResolver();
    library = FakeMusicLibraryRepository();
    playlists = FakePlaylistRepository();
    session = fakeSessionCubit(signedIn: fakeAuthSession());
    cubit = fakeDownloadsCubit(
      store: store,
      engine: engine,
      resolver: resolver,
      library: library,
      playlists: playlists,
      session: session,
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
      // Its file is still on the device.
      engine.stored[track.id] = Uri.file('/downloads/t1/audio.flac');

      await cubit.restore();
      await pumpEventQueue();

      expect(cubit.state[track.id]?.state, DownloadState.completed);
      // Nothing was re-fetched — it was already done.
      expect(engine.fetched, isEmpty);
    });

    test(
      'a completed record whose file has vanished is downloaded again (v0.2.3)',
      () async {
        final track = testTrack('t1');
        store.records[track.id] = downloadRecord(
          track.id,
          state: DownloadState.completed,
          totalBytes: 900,
          receivedBytes: 900,
        );
        // No engine.stored entry: the record says "downloaded", the file
        // is not there — storage cleared under the app, an OS restore
        // that dropped media. It must not stay a phantom "downloaded".

        await cubit.restore();
        await pumpEventQueue();

        expect(engine.fetched, [track.id]);
        expect(cubit.state[track.id]?.state, DownloadState.completed);
      },
    );

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

    test(
      'a waiting-for-network record is re-evaluated, not left stuck (v0.2.2)',
      () async {
        final track = testTrack('t1');
        store.records[track.id] = downloadRecord(
          track.id,
          state: DownloadState.waitingForNetwork,
        );

        // The default fake network is unmetered, so the worker's gate
        // clears it and it completes — connectivity_plus would not have
        // fired a change event to unstick it.
        await cubit.restore();
        await pumpEventQueue();

        expect(cubit.state[track.id]?.state, DownloadState.completed);
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

  group('requesting an artist (v0.2.2)', () {
    test('downloads every track credited to the artist', () async {
      library.trackList = [testTrack('t1'), testTrack('t2'), testTrack('t3')];

      final result = await cubit.downloadArtist(testArtist('ar-1'));
      await pumpEventQueue();

      expect(result.isOk, isTrue);
      expect(engine.fetched, [mediaId('t1'), mediaId('t2'), mediaId('t3')]);
      for (final id in ['t1', 't2', 't3']) {
        expect(cubit.state[mediaId(id)]?.owners, {
          DownloadOwner.artist(mediaId('ar-1')),
        });
      }
    });

    test('pages a large artist rather than reading it all at once', () async {
      library.trackList = [for (var i = 0; i < 250; i++) testTrack('t$i')];

      await cubit.downloadArtist(testArtist('ar-1'));
      await pumpEventQueue();

      // 250 tracks over the default 100-wide window: three reads, and
      // every track requested.
      final trackReads = library.calls
          .where((call) => call.method == 'tracks')
          .toList();
      expect(trackReads, hasLength(3));
      expect(trackReads.map((c) => c.page.startIndex), [0, 100, 200]);
      expect(cubit.state.downloads, hasLength(250));
    });

    test('reuses a track an album download already holds', () async {
      final shared = testTrack('t1', albumId: 'al-1');
      library.trackList = [shared, testTrack('t2')];

      await cubit.downloadAlbum(testAlbum('al-1', name: 'Kind of Blue'));
      await pumpEventQueue();
      await cubit.downloadArtist(testArtist('ar-1'));
      await pumpEventQueue();

      // Fetched once for the album; the artist only adds a reason to keep
      // it.
      expect(engine.fetched.where((id) => id == shared.id), hasLength(1));
      expect(cubit.state[shared.id]?.owners, {
        DownloadOwner.album(mediaId('al-1')),
        DownloadOwner.artist(mediaId('ar-1')),
      });
    });

    test('reports a failure when the artist could not be read', () async {
      library.failure = const UnavailableFailure('no such artist');

      final result = await cubit.downloadArtist(testArtist('ar-1'));

      expect(result.isErr, isTrue);
      expect(cubit.state.downloads, isEmpty);
    });

    test(
      'removing the artist keeps a track another target still wants',
      () async {
        final shared = testTrack('t1', albumId: 'al-1');
        library.tracksByAlbum['al-1'] = [shared];
        library.tracksByArtist['ar-1'] = [shared, testTrack('t2')];
        await cubit.downloadAlbum(testAlbum('al-1'));
        await pumpEventQueue();
        await cubit.downloadArtist(testArtist('ar-1'));
        await pumpEventQueue();

        await cubit.removeArtist(mediaId('ar-1'));
        await pumpEventQueue();

        // t1 stays — the album still holds it; t2 goes with the artist.
        expect(cubit.state[shared.id]?.owners, {
          DownloadOwner.album(mediaId('al-1')),
        });
        expect(cubit.state[mediaId('t2')], isNull);
        expect(engine.discarded, contains(mediaId('t2')));
        expect(engine.discarded, isNot(contains(shared.id)));
      },
    );
  });

  group('download quality (v0.2.2)', () {
    test('fetches at the settings-selected download quality', () async {
      final settings = fakeSettingsCubit(downloadQuality: StreamQuality.medium);
      addTearDown(settings.close);
      final scoped = fakeDownloadsCubit(
        store: store,
        engine: engine,
        resolver: resolver,
        library: library,
        playlists: playlists,
        settings: settings,
      );
      addTearDown(scoped.close);

      await scoped.downloadTrack(testTrack('t1'));
      await pumpEventQueue();

      expect(resolver.requestedQuality['t1'], StreamQuality.medium);
    });

    test('a quality change does not re-fetch a completed download', () async {
      final settings = fakeSettingsCubit(
        downloadQuality: StreamQuality.original,
      );
      addTearDown(settings.close);
      final scoped = fakeDownloadsCubit(
        store: store,
        engine: engine,
        resolver: resolver,
        library: library,
        playlists: playlists,
        settings: settings,
      );
      addTearDown(scoped.close);

      await scoped.downloadTrack(testTrack('t1'));
      await pumpEventQueue();
      expect(engine.fetched, [mediaId('t1')]);

      await settings.setDownloadQuality(StreamQuality.dataSaver);
      await pumpEventQueue();

      // Still one fetch: the file on the device is left as it is.
      expect(engine.fetched, [mediaId('t1')]);
    });
  });

  group('Wi-Fi-only downloads (v0.2.2)', () {
    ({DownloadsCubit cubit, FakeNetworkCondition network}) wifiOnly(
      NetworkState network,
    ) {
      final settings = fakeSettingsCubit(downloadsWifiOnly: true);
      addTearDown(settings.close);
      final condition = FakeNetworkCondition(state: network);
      final scoped = fakeDownloadsCubit(
        store: store,
        engine: engine,
        resolver: resolver,
        library: library,
        playlists: playlists,
        settings: settings,
        network: condition,
      );
      addTearDown(scoped.close);
      return (cubit: scoped, network: condition);
    }

    test(
      'holds a request on a metered connection instead of failing it',
      () async {
        final (:cubit, :network) = wifiOnly(NetworkState.metered);

        await cubit.downloadTrack(testTrack('t1'));
        await pumpEventQueue();

        expect(
          cubit.state.stateOf(mediaId('t1')),
          DownloadState.waitingForNetwork,
        );
        expect(engine.fetched, isEmpty);
      },
    );

    test('resumes a held request when Wi-Fi comes back', () async {
      final (:cubit, :network) = wifiOnly(NetworkState.metered);

      await cubit.downloadTrack(testTrack('t1'));
      await pumpEventQueue();
      expect(
        cubit.state.stateOf(mediaId('t1')),
        DownloadState.waitingForNetwork,
      );

      network.moveTo(NetworkState.unmetered);
      await pumpEventQueue();

      expect(cubit.state.stateOf(mediaId('t1')), DownloadState.completed);
      expect(engine.fetched, [mediaId('t1')]);
    });

    test('resumes a held request when the preference is turned off', () async {
      final settings = fakeSettingsCubit(downloadsWifiOnly: true);
      addTearDown(settings.close);
      final scoped = fakeDownloadsCubit(
        store: store,
        engine: engine,
        resolver: resolver,
        library: library,
        playlists: playlists,
        settings: settings,
        network: FakeNetworkCondition(state: NetworkState.metered),
      );
      addTearDown(scoped.close);

      await scoped.downloadTrack(testTrack('t1'));
      await pumpEventQueue();
      expect(
        scoped.state.stateOf(mediaId('t1')),
        DownloadState.waitingForNetwork,
      );

      await settings.setDownloadsWifiOnly(false);
      await pumpEventQueue();

      expect(scoped.state.stateOf(mediaId('t1')), DownloadState.completed);
    });

    test('an unmetered connection runs the download normally', () async {
      final (:cubit, :network) = wifiOnly(NetworkState.unmetered);

      await cubit.downloadTrack(testTrack('t1'));
      await pumpEventQueue();

      expect(cubit.state.stateOf(mediaId('t1')), DownloadState.completed);
    });
  });

  group('downloaded-collection identity (v0.2.3)', () {
    test('downloading an album records its name and artwork', () async {
      library.tracksByAlbum['al-1'] = [testTrack('t1', albumId: 'al-1')];

      await cubit.downloadAlbum(testAlbum('al-1', name: 'Kind of Blue'));
      await pumpEventQueue();

      final owner = DownloadOwner.album(mediaId('al-1'));
      expect(cubit.state.collectionIdentity(owner)?.name, 'Kind of Blue');
      expect(store.collectionsMap[owner]?.name, 'Kind of Blue');
    });

    test('downloading a playlist gives the Downloads screen its real name', () async {
      playlists.trackList = [testTrack('t1')];

      await cubit.downloadPlaylist(testPlaylist('pl-1', name: 'Roadtrip'));
      await pumpEventQueue();

      expect(
        cubit.state.collectionName(DownloadOwner.playlist(mediaId('pl-1'))),
        'Roadtrip',
      );
    });

    test('removing a collection forgets its stored identity', () async {
      library.tracksByAlbum['al-1'] = [testTrack('t1', albumId: 'al-1')];
      await cubit.downloadAlbum(testAlbum('al-1', name: 'Kind of Blue'));
      await pumpEventQueue();

      await cubit.removeAlbum(mediaId('al-1'));
      await pumpEventQueue();

      final owner = DownloadOwner.album(mediaId('al-1'));
      expect(cubit.state.collectionIdentity(owner), isNull);
      expect(store.collectionsMap.containsKey(owner), isFalse);
    });

    test('restore reloads stored collection identities', () async {
      final owner = DownloadOwner.playlist(mediaId('pl-1'));
      store.collectionsMap[owner] = DownloadedCollection(
        owner: owner,
        name: 'Saved Mix',
      );

      await cubit.restore();
      await pumpEventQueue();

      expect(cubit.state.collectionName(owner), 'Saved Mix');
    });
  });

  group('per-profile downloads (v0.2.3)', () {
    test('switching profile rebuilds the catalog from that profile\'s records', () async {
      // Alice has a download.
      store.records[mediaId('t1')] = downloadRecord(
        mediaId('t1'),
        state: DownloadState.completed,
      );
      engine.stored[mediaId('t1')] = Uri.file('/downloads/t1/audio.flac');
      await cubit.restore();
      await pumpEventQueue();
      expect(cubit.state.isDownloaded(mediaId('t1')), isTrue);

      // Bob signs in — a different profile with nothing downloaded.
      store.accountKey = 'server-1/user-2';
      session.emit(
        SessionState.signedIn(
          fakeAuthSession(
            account: fakeJellyfinAccount(id: 'acct-2', userId: 'user-2'),
          ),
        ),
      );
      await pumpEventQueue();

      expect(cubit.state.downloads, isEmpty);
      expect(cubit.state.isLoaded, isTrue);
    });

    test('signing out empties the catalog', () async {
      store.records[mediaId('t1')] = downloadRecord(
        mediaId('t1'),
        state: DownloadState.completed,
      );
      engine.stored[mediaId('t1')] = Uri.file('/downloads/t1/audio.flac');
      await cubit.restore();
      await pumpEventQueue();

      store.accountKey = 'signed-out';
      session.emit(const SessionState.signedOut());
      await pumpEventQueue();

      expect(cubit.state.downloads, isEmpty);
    });

    test('restore claims downloads left unscoped by the schema-v6 upgrade', () async {
      store.accountKey = '';
      store.records[mediaId('t1')] = downloadRecord(
        mediaId('t1'),
        state: DownloadState.completed,
      );
      engine.stored[mediaId('t1')] = Uri.file('/downloads/t1/audio.flac');

      store.accountKey = 'server-1/user-1';
      await cubit.restore();
      await pumpEventQueue();

      expect(cubit.state.isDownloaded(mediaId('t1')), isTrue);
    });
  });
}
