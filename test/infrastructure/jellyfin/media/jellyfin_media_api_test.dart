import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/jellyfin_media_api.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';

void main() {
  group('signed out', () {
    test(
      'every request fails as unauthorized without touching the network',
      () async {
        final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));
        final api = testMediaApi(
          adapter,
          context: FakeSessionContext.signedOut(),
        );

        final items = await api.queryItems();
        final played = await api.setPlayed('item-1', played: true);

        expect(items.failureOrNull, isA<UnauthorizedFailure>());
        expect(played.failureOrNull, isA<UnauthorizedFailure>());
        expect(api.mapper().failureOrNull, isA<UnauthorizedFailure>());
        expect(adapter.callCount, isZero);
      },
    );
  });

  group('queryItems', () {
    test(
      'asks the server for one window, sorted, for the signed-in user',
      () async {
        final adapter = FakeDioAdapter(
          (_) async => jsonResponseBody(itemsResponse(const [])),
        );

        await testMediaApi(adapter).queryItems(
          includeItemTypes: const ['MusicAlbum'],
          sortBy: const ['SortName'],
          page: const PageRequest(startIndex: 200, limit: 50),
        );

        final request = adapter.requests.single;
        expect(request.path, JellyfinMediaApi.itemsPath);
        expect(request.queryParameters['userId'], 'user-1');
        expect(request.queryParameters['includeItemTypes'], 'MusicAlbum');
        expect(request.queryParameters['sortBy'], 'SortName');
        expect(request.queryParameters['sortOrder'], 'Ascending');
        expect(request.queryParameters['startIndex'], 200);
        expect(request.queryParameters['limit'], 50);
        expect(request.queryParameters['recursive'], isTrue);
      },
    );

    test(
      'does not recurse on endpoints that are already a collection',
      () async {
        final adapter = FakeDioAdapter(
          (_) async => jsonResponseBody(itemsResponse(const [])),
        );

        await testMediaApi(
          adapter,
        ).queryItems(path: JellyfinMediaApi.albumArtistsPath);

        expect(
          adapter.requests.single.queryParameters,
          isNot(contains('recursive')),
        );
      },
    );

    test('requests only the extra fields it needs', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );

      await testMediaApi(adapter).queryItems();

      final query = adapter.requests.single.queryParameters;
      expect(query['fields'], 'PrimaryImageAspectRatio');
      expect(query['enableImageTypes'], 'Primary,Backdrop,Logo');
    });

    test('reports a transport failure as a Result, not an exception', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({}, statusCode: 401),
      );

      final result = await testMediaApi(adapter).queryItems();

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    });
  });

  group('item', () {
    test('asks the collection endpoint for a single id', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 'album-1', 'Name': 'Kind of Blue', 'Type': 'MusicAlbum'},
          ]),
        ),
      );

      final result = await testMediaApi(adapter).item('album-1');

      final query = adapter.requests.single.queryParameters;
      expect(query['ids'], 'album-1');
      expect(query['limit'], 1);
      expect(query['fields'], contains('Overview'));
      expect(result.valueOrNull!.name, 'Kind of Blue');
    });

    test('answers with nothing when the item is gone, not a failure', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );

      final result = await testMediaApi(adapter).item('missing');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
    });
  });

  group('played flag', () {
    test('posts to set it and deletes to clear it', () async {
      final adapter = FakeDioAdapter((_) async => jsonResponseBody({}));
      final api = testMediaApi(adapter);

      await api.setPlayed('item-1', played: true);
      await api.setPlayed('item-1', played: false);

      expect(adapter.requests[0].method, 'POST');
      expect(adapter.requests[0].path, '/UserPlayedItems/item-1');
      expect(adapter.requests[0].queryParameters['userId'], 'user-1');
      expect(adapter.requests[1].method, 'DELETE');
    });

    test('does not fail on an empty response body', () async {
      // The endpoint's answer is its status code; some versions send no
      // body at all.
      final adapter = FakeDioAdapter((_) async => textResponseBody(''));

      final result = await testMediaApi(adapter).setPlayed('i', played: true);

      expect(result.isOk, isTrue);
    });
  });

  group('identity scoping', () {
    test('accepts an id from the active server', () {
      final api = testMediaApi(
        FakeDioAdapter((_) async => jsonResponseBody({})),
      );

      final id = api.localItemId(
        const MediaId(serverId: 'server-1', itemId: 'item-9'),
      );

      expect(id.valueOrNull, 'item-9');
    });

    test('refuses an id belonging to another saved server', () {
      final api = testMediaApi(
        FakeDioAdapter((_) async => jsonResponseBody({})),
      );

      final id = api.localItemId(
        const MediaId(serverId: 'server-2', itemId: 'item-9'),
      );

      expect(id.failureOrNull, isA<UnavailableFailure>());
    });

    test('binds the mapper to the active server', () {
      final api = testMediaApi(
        FakeDioAdapter((_) async => jsonResponseBody({})),
      );

      expect(api.mapper().valueOrNull!.serverId, 'server-1');
    });
  });

  group('session-scoped client', () {
    test('reuses one client while the server stays the same', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );
      final api = testMediaApi(adapter);

      await api.queryItems();
      await api.queryItems();

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.map((request) => request.baseUrl).toSet(), {
        'https://media.example.com',
      });
    });

    test('follows the active profile to a different server', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );
      final context = FakeSessionContext();
      final api = testMediaApi(adapter, context: context);

      await api.queryItems();
      context
        ..serverId = 'server-2'
        ..baseUrl = 'https://other.example.com'
        ..userId = 'user-2';
      await api.queryItems();

      expect(adapter.requests[0].baseUrl, 'https://media.example.com');
      expect(adapter.requests[1].baseUrl, 'https://other.example.com');
      expect(adapter.requests[1].queryParameters['userId'], 'user-2');
    });
  });
}
