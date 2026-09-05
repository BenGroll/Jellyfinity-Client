import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/library/paged_collection_cubit.dart';

import '../../support/music_fakes.dart';
import '../../support/offline_fakes.dart';

/// A library big enough that no screen could hold it, windowed the way
/// the real one is.
List<Track> _library(int count) => [
  for (var i = 0; i < count; i++) testTrack('t$i', name: 'Song $i'),
];

SongsCubit _songs(
  FakeMusicLibraryRepository music, {
  int pageSize = 50,
  FakeDownloadsLibrarySource? downloads,
  FakeOfflineMode? offline,
}) {
  final cubit = SongsCubit(
    music,
    downloads ?? FakeDownloadsLibrarySource(),
    offline ?? FakeOfflineMode(),
    pageSize: pageSize,
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  test('shows a skeleton before it shows songs', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(10);
    final cubit = _songs(music);

    final states = <CollectionStatus>[];
    cubit.stream.listen((state) => states.add(state.status));

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(states, [CollectionStatus.loading, CollectionStatus.ready]);
    expect(cubit.state.items, hasLength(10));
  });

  test('asks for one window of a 130k-song library, not the library', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(130000);
    final cubit = _songs(music, pageSize: 100);

    await cubit.load();

    expect(cubit.state.items, hasLength(100));
    expect(cubit.state.hasMore, isTrue);
    expect(music.calls.single.page.limit, 100);
  });

  test('appends the next window instead of replacing the list', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(130);
    final cubit = _songs(music);

    await cubit.load();
    await cubit.loadMore();

    expect(cubit.state.items, hasLength(100));
    expect(cubit.state.items.first.name, 'Song 0');
    expect(cubit.state.items.last.name, 'Song 99');
    expect(music.calls.map((c) => c.page.startIndex), [0, 50]);
  });

  test('stops asking once the collection is exhausted', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(60);
    final cubit = _songs(music);

    await cubit.load();
    await cubit.loadMore();
    await cubit.loadMore();

    expect(cubit.state.items, hasLength(60));
    expect(cubit.state.hasMore, isFalse);
    expect(music.calls, hasLength(2));
  });

  test('ignores an overlapping request rather than interleaving it', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(300);
    final cubit = _songs(music);
    await cubit.load();

    await Future.wait([cubit.loadMore(), cubit.loadMore()]);

    expect(music.calls, hasLength(2));
    expect(cubit.state.items, hasLength(100));
  });

  test('a failed first window is a failed screen', () async {
    final music = FakeMusicLibraryRepository()
      ..failure = const RecoverableFailure('offline');
    final cubit = _songs(music);

    await cubit.load();

    expect(cubit.state.status, CollectionStatus.failed);
    expect(cubit.state.failure, isA<RecoverableFailure>());
  });

  test('a failed next window keeps every window before it', () async {
    final music = FakeMusicLibraryRepository()
      ..trackList = _library(200)
      ..failureAfterFirstPage = const RecoverableFailure('dropped');
    final cubit = _songs(music);

    await cubit.load();
    await cubit.loadMore();

    // The screen still holds its songs; only the footer says something
    // went wrong.
    expect(cubit.state.status, CollectionStatus.ready);
    expect(cubit.state.items, hasLength(50));
    expect(cubit.state.loadMoreFailure, isA<RecoverableFailure>());
    expect(cubit.state.isLoadingMore, isFalse);
  });

  test('does not keep retrying a window that just failed', () async {
    final music = FakeMusicLibraryRepository()
      ..trackList = _library(200)
      ..failureAfterFirstPage = const RecoverableFailure('dropped');
    final cubit = _songs(music);
    await cubit.load();
    await cubit.loadMore();

    await cubit.loadMore();

    expect(music.calls, hasLength(2));
  });

  test('retrying the failed window picks up where it stopped', () async {
    final music = FakeMusicLibraryRepository()
      ..trackList = _library(200)
      ..failureAfterFirstPage = const RecoverableFailure('dropped');
    final cubit = _songs(music);
    await cubit.load();
    await cubit.loadMore();

    music.failureAfterFirstPage = null;
    await cubit.retryLoadMore();

    expect(cubit.state.items, hasLength(100));
    expect(cubit.state.loadMoreFailure, isNull);
  });

  test('a refresh keeps the current songs on screen throughout', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(200);
    final cubit = _songs(music);
    await cubit.load();

    final duringRefresh = <bool>[];
    cubit.stream.listen((state) {
      if (state.isRefreshing) duringRefresh.add(state.items.isNotEmpty);
    });

    await cubit.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(duringRefresh, [isTrue]);
    expect(cubit.state.items, hasLength(50));
    expect(cubit.state.isRefreshing, isFalse);
  });

  test('a failed refresh keeps the songs and reports itself', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(200);
    final cubit = _songs(music);
    await cubit.load();

    music.failure = const RecoverableFailure('offline');
    await cubit.refresh();

    expect(cubit.state.items, hasLength(50));
    expect(cubit.state.loadMoreFailure, isA<RecoverableFailure>());
  });

  test('keeps rows it could not read, and still advances', () async {
    final music = FakeMusicLibraryRepository()
      ..trackList = _library(4)
      ..unavailable = const [
        UnavailableItem(id: 'x', reason: 'This song is unavailable.'),
      ];
    final cubit = _songs(music);

    await cubit.load();

    expect(cubit.state.items, hasLength(4));
    expect(cubit.state.unavailable, hasLength(1));
    expect(cubit.state.isPartial, isTrue);
    // Four usable songs plus one that is not, is not an empty screen.
    expect(cubit.state.isEmpty, isFalse);
  });

  test('reports an empty collection as empty, not as an error', () async {
    final cubit = _songs(FakeMusicLibraryRepository());

    await cubit.load();

    expect(cubit.state.isEmpty, isTrue);
    expect(cubit.state.failure, isNull);
  });

  test('passes on that a window came from the saved copy', () async {
    final music = FakeMusicLibraryRepository()
      ..trackList = _library(5)
      ..source = PageSource.cache;
    final cubit = _songs(music);

    await cubit.load();

    expect(cubit.state.isCached, isTrue);
  });

  test('returning to a tab does not re-ask for the list', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(10);
    final cubit = _songs(music);

    await cubit.load();
    await cubit.load();

    expect(music.calls, hasLength(1));
  });

  test('a new search term starts the list over', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(10);
    final cubit = _songs(music);
    await cubit.load();
    await cubit.loadMore();

    await cubit.searchFor('Song 3');

    expect(music.calls.last.searchTerm, 'Song 3');
    expect(music.calls.last.page.startIndex, 0);
    expect(cubit.state.items, hasLength(1));
  });

  test(
    'the Downloaded filter reads the downloads, not the server (v0.2.3)',
    () async {
      final music = FakeMusicLibraryRepository()..trackList = _library(10);
      final downloads = FakeDownloadsLibrarySource()
        ..trackList = [testTrack('d1', name: 'Kept Song')];
      final cubit = _songs(music, downloads: downloads);
      await cubit.load();
      music.calls.clear();

      await cubit.showDownloadedOnly(true);

      expect(cubit.downloadedOnly, isTrue);
      expect(cubit.state.items.single.name, 'Kept Song');
      expect(cubit.state.isCached, isTrue);
      // The server was not asked again.
      expect(music.calls, isEmpty);
    },
  );

  test('crossing offline re-reads a list already on screen (v0.2.3)', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(10);
    final offline = FakeOfflineMode();
    final cubit = _songs(music, offline: offline);
    await cubit.load();
    expect(music.calls, hasLength(1));

    offline.setConnected(false);
    await Future<void>.delayed(Duration.zero);

    expect(music.calls, hasLength(2));
  });

  test(
    'a reload asked for mid-fetch wins over the window in flight (v0.2.3)',
    () async {
      // The offline switch and the "Downloads only" scope can both fire a
      // reload on the same frame; the second must not be dropped for the
      // first still being busy.
      final music = FakeMusicLibraryRepository()
        ..trackList = _library(10)
        ..responseDelay = const Duration(milliseconds: 30);
      final downloads = FakeDownloadsLibrarySource()
        ..trackList = [testTrack('d1', name: 'Kept Song')];
      final cubit = _songs(music, downloads: downloads);
      await cubit.load();

      // A slow server reload starts...
      unawaited(cubit.reload());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // ...and the scope flips to downloads-only while it is in flight.
      await cubit.showDownloadedOnly(true);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(cubit.downloadedOnly, isTrue);
      expect(cubit.state.items.single.name, 'Kept Song');
    },
  );

  test('crossing offline leaves an unopened tab alone (v0.2.3)', () async {
    final music = FakeMusicLibraryRepository()..trackList = _library(10);
    final offline = FakeOfflineMode();
    _songs(music, offline: offline);

    offline.setConnected(false);
    await Future<void>.delayed(Duration.zero);

    // Never loaded, so nothing to re-read.
    expect(music.calls, isEmpty);
  });
}
