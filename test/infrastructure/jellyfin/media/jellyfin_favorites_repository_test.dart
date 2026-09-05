import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinFavoritesRepository.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';

const _trackId = MediaId(serverId: 'server-1', itemId: 'track-1');
const _elsewhere = MediaId(serverId: 'server-2', itemId: 'track-1');

void main() {
  test('posts to favorite and deletes to unfavorite', () async {
    final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));
    final repository = JellyfinFavoritesRepository(testMediaApi(adapter));

    await repository.setFavorite(_trackId, favorite: true);
    await repository.setFavorite(_trackId, favorite: false);

    expect(adapter.requests[0].method, 'POST');
    expect(adapter.requests[0].path, '/UserFavoriteItems/track-1');
    expect(adapter.requests[1].method, 'DELETE');
  });

  test('refuses an id belonging to another saved server', () async {
    final repository = JellyfinFavoritesRepository(
      testMediaApi(FakeDioAdapter((_) async => jsonResponseBody({}))),
    );

    final result = await repository.setFavorite(_elsewhere, favorite: true);

    expect(result.failureOrNull, isA<UnavailableFailure>());
  });
}
