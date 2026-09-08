import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinFavoritesRepository.dart';
import 'package:jellyfinity/infrastructure/media/CachedFavoritesRepository.dart';

import '../../support/FakeDioAdapter.dart';
import '../../support/FakeSessionContext.dart';
import '../../support/media_fakes.dart';

const _albumId = MediaId(serverId: 'server-1', itemId: 'album-1');

CachedFavoritesRepository _repository(
  FakeDioAdapter adapter, {
  required RecordingMediaCacheStore cache,
  FakeSessionContext? context,
}) {
  final session = context ?? FakeSessionContext();
  return CachedFavoritesRepository(
    JellyfinFavoritesRepository(testMediaApi(adapter, context: session)),
    cache,
    session,
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
}
