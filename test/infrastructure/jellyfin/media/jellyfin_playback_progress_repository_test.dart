import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinPlaybackProgressRepository.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';

const _movieId = MediaId(serverId: 'server-1', itemId: 'movie-1');
const _minuteInTicks = 600000000;

JellyfinPlaybackProgressRepository _repository(FakeDioAdapter adapter) =>
    JellyfinPlaybackProgressRepository(testMediaApi(adapter));

void main() {
  test('reads the resume position the server holds for this user', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(
        itemsResponse([
          {
            'Id': 'movie-1',
            'Name': 'Interstellar',
            'Type': 'Movie',
            'UserData': {
              'PlaybackPositionTicks': 30 * _minuteInTicks,
              'Played': false,
            },
          },
        ]),
      ),
    );

    final result = await _repository(adapter).forItem(_movieId);

    expect(result.valueOrNull!.position, const Duration(minutes: 30));
    expect(result.valueOrNull!.isResumable, isTrue);
  });

  test('an item the user never played has no progress, not an error', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(
        itemsResponse([
          {'Id': 'movie-1', 'Name': 'Interstellar', 'Type': 'Movie'},
        ]),
      ),
    );

    final result = await _repository(adapter).forItem(_movieId);

    expect(result.valueOrNull, PlaybackProgress.none);
  });

  test('a removed item is unavailable', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _repository(adapter).forItem(_movieId);

    expect(result.failureOrNull, isA<UnavailableFailure>());
  });

  test('marks an item played and unplayed', () async {
    final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));
    final repository = _repository(adapter);

    expect((await repository.markPlayed(_movieId)).isOk, isTrue);
    expect((await repository.markUnplayed(_movieId)).isOk, isTrue);

    expect(adapter.requests[0].method, 'POST');
    expect(adapter.requests[0].path, '/UserPlayedItems/movie-1');
    expect(adapter.requests[1].method, 'DELETE');
  });

  test("will not mark another server's item", () async {
    final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

    final result = await _repository(
      adapter,
    ).markPlayed(const MediaId(serverId: 'server-2', itemId: 'movie-1'));

    expect(result.failureOrNull, isA<UnavailableFailure>());
    expect(adapter.callCount, isZero);
  });

  test('reports a playback session starting at position zero', () async {
    final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

    final result = await _repository(adapter).reportStart(_movieId);

    expect(result.isOk, isTrue);
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/Sessions/Playing');
    final body = adapter.requests.single.data as Map;
    expect(body['ItemId'], 'movie-1');
    expect(body['PositionTicks'], 0);
  });

  test('reports live progress as ticks', () async {
    final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

    final result = await _repository(adapter).reportProgress(
      _movieId,
      position: const Duration(minutes: 5),
      isPaused: true,
    );

    expect(result.isOk, isTrue);
    expect(adapter.requests.single.path, '/Sessions/Playing/Progress');
    final body = adapter.requests.single.data as Map;
    expect(body['PositionTicks'], 5 * _minuteInTicks);
    expect(body['IsPaused'], isTrue);
  });

  test('reports where playback stopped', () async {
    final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

    final result = await _repository(
      adapter,
    ).reportStop(_movieId, position: const Duration(minutes: 2));

    expect(result.isOk, isTrue);
    expect(adapter.requests.single.path, '/Sessions/Playing/Stopped');
    final body = adapter.requests.single.data as Map;
    expect(body['PositionTicks'], 2 * _minuteInTicks);
  });

  test('will not report progress for another server\'s item', () async {
    final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));

    final result = await _repository(
      adapter,
    ).reportStart(const MediaId(serverId: 'server-2', itemId: 'movie-1'));

    expect(result.failureOrNull, isA<UnavailableFailure>());
    expect(adapter.callCount, isZero);
  });
}
