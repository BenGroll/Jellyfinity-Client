import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinLyricsResolver.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';

const _trackId = MediaId(serverId: 'server-1', itemId: 'track-1');
const _elsewhere = MediaId(serverId: 'server-2', itemId: 'track-1');

JellyfinLyricsResolver _resolver(
  FakeDioAdapter adapter, {
  FakeSessionContext? context,
}) {
  return JellyfinLyricsResolver(testMediaApi(adapter, context: context));
}

void main() {
  test('reads plain lyrics when no line carries timing', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({
        'Lyrics': [
          {'Text': 'First line'},
          {'Text': 'Second line'},
        ],
      }),
    );

    final result = await _resolver(adapter).resolve(_trackId);

    final lyrics = result.valueOrNull!;
    expect(lyrics.isSynchronized, isFalse);
    expect(lyrics.lines.map((l) => l.text), ['First line', 'Second line']);
    expect(lyrics.lines.every((l) => l.start == null), isTrue);
    expect(adapter.requests.single.path, '/Audio/track-1/Lyrics');
  });

  test(
    'reads synchronized lyrics when every line has non-decreasing timing',
    () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({
          'Lyrics': [
            {'Text': 'First line', 'Start': 0},
            {'Text': 'Second line', 'Start': 50000000},
          ],
        }),
      );

      final result = await _resolver(adapter).resolve(_trackId);

      final lyrics = result.valueOrNull!;
      expect(lyrics.isSynchronized, isTrue);
      expect(lyrics.lines[0].start, Duration.zero);
      expect(lyrics.lines[1].start, const Duration(seconds: 5));
    },
  );

  test(
    'falls back to plain lyrics when only some lines carry timing',
    () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({
          'Lyrics': [
            {'Text': 'First line', 'Start': 0},
            {'Text': 'Second line'},
          ],
        }),
      );

      final result = await _resolver(adapter).resolve(_trackId);

      expect(result.valueOrNull!.isSynchronized, isFalse);
    },
  );

  test('falls back to plain lyrics when timing runs backwards', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({
        'Lyrics': [
          {'Text': 'First line', 'Start': 50000000},
          {'Text': 'Second line', 'Start': 0},
        ],
      }),
    );

    final result = await _resolver(adapter).resolve(_trackId);

    expect(result.valueOrNull!.isSynchronized, isFalse);
  });

  test('is Ok(null) — an empty state — when the track has no lyrics', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({'error': 'Not Found'}, statusCode: 404),
    );

    final result = await _resolver(adapter).resolve(_trackId);

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, isNull);
  });

  test(
    'propagates a real failure rather than treating it as no lyrics',
    () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({'error': 'nope'}, statusCode: 500),
      );

      final result = await _resolver(adapter).resolve(_trackId);

      expect(result.failureOrNull, isA<RecoverableFailure>());
    },
  );

  test('will not query one server for another server\'s track', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({'Lyrics': []}),
    );

    final result = await _resolver(adapter).resolve(_elsewhere);

    expect(result.failureOrNull, isA<UnavailableFailure>());
    expect(adapter.callCount, isZero);
  });

  test('fails cleanly when nobody is signed in', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({'Lyrics': []}),
    );

    final result = await _resolver(
      adapter,
      context: FakeSessionContext.signedOut(),
    ).resolve(_trackId);

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
    expect(adapter.callCount, isZero);
  });
}
