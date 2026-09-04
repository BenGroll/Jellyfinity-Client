import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/jellyfin_media_api.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinTrackSourceInfoResolver.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';

const _trackId = MediaId(serverId: 'server-1', itemId: 'track-1');
const _elsewhere = MediaId(serverId: 'server-2', itemId: 'track-1');

JellyfinTrackSourceInfoResolver _resolver(
  FakeDioAdapter adapter, {
  FakeSessionContext? context,
}) {
  return JellyfinTrackSourceInfoResolver(
    testMediaApi(adapter, context: context),
  );
}

void main() {
  test(
    'reads a track\'s source details, asking only for MediaSources',
    () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {
              'Id': 'track-1',
              'Name': 'So What',
              'Type': 'Audio',
              'MediaSources': [
                {
                  'Container': 'flac',
                  'MediaStreams': [
                    {'Type': 'Audio', 'Codec': 'flac', 'BitRate': 995000},
                  ],
                },
              ],
            },
          ]),
        ),
      );

      final result = await _resolver(adapter).resolve(_trackId);

      final info = result.valueOrNull!;
      expect(info.codec, 'flac');
      expect(info.bitrateBps, 995000);
      expect(
        adapter.requests.single.queryParameters['fields'],
        JellyfinMediaApi.trackSourceFields.join(','),
      );
    },
  );

  test('reports a removed track as unavailable rather than empty', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _resolver(adapter).resolve(_trackId);

    expect(result.failureOrNull, isA<UnavailableFailure>());
  });

  test('is unavailable when the item has no usable media source', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(
        itemsResponse([
          {'Id': 'track-1', 'Name': 'So What', 'Type': 'Audio'},
        ]),
      ),
    );

    final result = await _resolver(adapter).resolve(_trackId);

    expect(result.failureOrNull, isA<UnavailableFailure>());
  });

  test('will not query one server for another server\'s track', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _resolver(adapter).resolve(_elsewhere);

    expect(result.failureOrNull, isA<UnavailableFailure>());
    expect(adapter.callCount, isZero);
  });

  test('fails cleanly when nobody is signed in', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _resolver(
      adapter,
      context: FakeSessionContext.signedOut(),
    ).resolve(_trackId);

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
    expect(adapter.callCount, isZero);
  });
}
