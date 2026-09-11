import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinFavoritesRepository.dart';
import 'package:jellyfinity/infrastructure/media/CachedFavoritesRepository.dart';

import '../../support/FakeDioAdapter.dart';
import '../../support/FakeSessionContext.dart';
import '../../support/media_fakes.dart';
import '../../support/offline_fakes.dart';

const _albumId = MediaId(serverId: 'server-1', itemId: 'album-1');

CachedFavoritesRepository _repository(
  FakeDioAdapter adapter, {
  required RecordingMediaCacheStore cache,
  FakeSessionContext? context,
  FakeOfflineMode? offline,
}) {
  final session = context ?? FakeSessionContext();
  return CachedFavoritesRepository(
    JellyfinFavoritesRepository(testMediaApi(adapter, context: session)),
    cache,
    session,
    offline ?? FakeOfflineMode(),
  );
}

FakeDioAdapter _ok() => FakeDioAdapter((_) async => jsonResponseBody({}));

FakeDioAdapter _rejecting() => FakeDioAdapter(
  (options) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'no route',
  ),
);

void main() {
  test('mirrors a successful toggle into the local favorites cache', () async {
    final cache = RecordingMediaCacheStore();
    await cache.replaceFavorites('server-1/user-1', MediaKind.album, const []);
    await cache.saveItem(
      Album(id: _albumId, name: 'Kind of Blue', artists: const []),
    );

    await _repository(
      _ok(),
      cache: cache,
    ).setFavorite(_albumId, favorite: true, kind: MediaKind.album);

    final page = await cache.readFavorites<Album>(
      'server-1/user-1',
      MediaKind.album,
      const PageRequest.first(),
    );
    expect(page!.items.single.name, 'Kind of Blue');
  });

  test('does not touch the cache when the server write fails', () async {
    final cache = RecordingMediaCacheStore();
    await cache.replaceFavorites('server-1/user-1', MediaKind.album, const []);

    final result = await _repository(
      _rejecting(),
      cache: cache,
    ).setFavorite(_albumId, favorite: true, kind: MediaKind.album);

    expect(result.isErr, isTrue);
    final page = await cache.readFavorites<Album>(
      'server-1/user-1',
      MediaKind.album,
      const PageRequest.first(),
    );
    expect(page!.items, isEmpty);
  });

  test('still writes to the server when the kind is not given', () async {
    final adapter = _ok();
    final result = await _repository(
      adapter,
      cache: RecordingMediaCacheStore(),
    ).setFavorite(_albumId, favorite: true);

    expect(result.isOk, isTrue);
    expect(adapter.requests.single.method, 'POST');
  });

  group('offline (v0.4.3)', () {
    test(
      'records a pending intent and updates the cache without touching '
      'the server',
      () async {
        final cache = RecordingMediaCacheStore();
        await cache.replaceFavorites(
          'server-1/user-1',
          MediaKind.album,
          const [],
        );
        await cache.saveItem(
          Album(id: _albumId, name: 'Kind of Blue', artists: const []),
        );
        final adapter = _ok();

        final result = await _repository(
          adapter,
          cache: cache,
          offline: FakeOfflineMode(connected: false),
        ).setFavorite(_albumId, favorite: true, kind: MediaKind.album);

        expect(result.isOk, isTrue);
        expect(adapter.requests, isEmpty);

        final page = await cache.readFavorites<Album>(
          'server-1/user-1',
          MediaKind.album,
          const PageRequest.first(),
        );
        expect(page!.items.single.name, 'Kind of Blue');

        final pending = await cache.pendingFavorites('server-1/user-1');
        expect(pending.single.id, _albumId);
        expect(pending.single.favorite, isTrue);
      },
    );

    test('coalesces rapid offline toggles into the latest intent', () async {
      final cache = RecordingMediaCacheStore();
      final repository = _repository(
        _ok(),
        cache: cache,
        offline: FakeOfflineMode(connected: false),
      );

      await repository.setFavorite(
        _albumId,
        favorite: true,
        kind: MediaKind.album,
      );
      await repository.setFavorite(
        _albumId,
        favorite: false,
        kind: MediaKind.album,
      );

      final pending = await cache.pendingFavorites('server-1/user-1');
      expect(pending, hasLength(1));
      expect(pending.single.favorite, isFalse);
    });

    test(
      'refuses the write when nobody is signed in, doing nothing',
      () async {
        final cache = RecordingMediaCacheStore();

        final result = await _repository(
          _ok(),
          cache: cache,
          context: FakeSessionContext.signedOut(),
          offline: FakeOfflineMode(connected: false),
        ).setFavorite(_albumId, favorite: true, kind: MediaKind.album);

        expect(result.isErr, isTrue);
      },
    );

    test(
      "never records another profile's pending intent",
      () async {
        final cache = RecordingMediaCacheStore();

        await _repository(
          _ok(),
          cache: cache,
          context: FakeSessionContext(userId: 'user-1'),
          offline: FakeOfflineMode(connected: false),
        ).setFavorite(_albumId, favorite: true, kind: MediaKind.album);

        expect(await cache.pendingFavorites('server-1/user-2'), isEmpty);
      },
    );

    test(
      'a fresh online success clears a stale offline intent for the '
      'same item',
      () async {
        final cache = RecordingMediaCacheStore();
        await cache.recordPendingFavorite(
          'server-1/user-1',
          _albumId,
          MediaKind.album,
          favorite: true,
        );

        final result = await _repository(
          _ok(),
          cache: cache,
        ).setFavorite(_albumId, favorite: false, kind: MediaKind.album);

        expect(result.isOk, isTrue);
        expect(await cache.pendingFavorites('server-1/user-1'), isEmpty);
      },
    );
  });
}
