import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/jellyfin_media_api.dart';
import 'package:jellyfinity/infrastructure/jellyfin/media/JellyfinMusicLibraryRepository.dart';

import '../../../support/FakeDioAdapter.dart';
import '../../../support/FakeSessionContext.dart';

const _artistId = MediaId(serverId: 'server-1', itemId: 'artist-1');
const _albumId = MediaId(serverId: 'server-1', itemId: 'album-1');
const _elsewhere = MediaId(serverId: 'server-2', itemId: 'album-1');

JellyfinMusicLibraryRepository _repository(
  FakeDioAdapter adapter, {
  FakeSessionContext? context,
}) {
  return JellyfinMusicLibraryRepository(
    testMediaApi(adapter, context: context),
  );
}

void main() {
  test('lists album artists as domain artists', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(
        itemsResponse([
          {'Id': 'artist-1', 'Name': 'Miles Davis', 'Type': 'MusicArtist'},
        ], totalRecordCount: 4200),
      ),
    );

    final result = await _repository(adapter).artists();

    final page = result.valueOrNull!;
    expect(adapter.requests.single.path, JellyfinMediaApi.albumArtistsPath);
    expect(page.items.single.name, 'Miles Davis');
    expect(page.items.single.id, _artistId);
    expect(page.totalCount, 4200);
    expect(page.hasMore, isTrue);
  });

  test('asks only for the requested window of a huge library', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(
      adapter,
    ).tracks(page: const PageRequest(startIndex: 129900, limit: 100));

    final query = adapter.requests.single.queryParameters;
    expect(query['startIndex'], 129900);
    expect(query['limit'], 100);
    expect(query['includeItemTypes'], 'Audio');
  });

  test(
    "filters an artist's albums server-side and orders them by year",
    () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );

      await _repository(adapter).albums(artistId: _artistId);

      final query = adapter.requests.single.queryParameters;
      expect(query['albumArtistIds'], 'artist-1');
      expect(query['includeItemTypes'], 'MusicAlbum');
      expect(query['sortBy'], 'ProductionYear,SortName');
    },
  );

  group('recentlyAddedAlbums (v0.3.3)', () {
    test('asks for albums newest-first by acquisition date', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );

      await _repository(
        adapter,
      ).recentlyAddedAlbums(page: const PageRequest(startIndex: 0, limit: 20));

      final query = adapter.requests.single.queryParameters;
      expect(query['includeItemTypes'], 'MusicAlbum');
      expect(query['sortBy'], 'DateCreated,SortName');
      expect(query['sortOrder'], 'Descending');
      expect(query['limit'], 20);
    });

    test(
      'reports the window as complete, not a slice of every album',
      () async {
        // The server says the library holds 480 albums; the strip only ever
        // sees this window and must not believe there is more to page.
        final adapter = FakeDioAdapter(
          (_) async => jsonResponseBody(
            itemsResponse([
              {'Id': 'a1', 'Name': 'Just Landed', 'Type': 'MusicAlbum'},
              {'Id': 'a2', 'Name': 'Last Week', 'Type': 'MusicAlbum'},
            ], totalRecordCount: 480),
          ),
        );

        final page = (await _repository(
          adapter,
        ).recentlyAddedAlbums()).valueOrNull!;

        expect(page.items.map((album) => album.name), [
          'Just Landed',
          'Last Week',
        ]);
        expect(page.totalCount, 2);
        expect(page.hasMore, isFalse);
      },
    );
  });

  group('favorites (v0.3.4)', () {
    test('asks the server for favorites of each kind, alphabetical', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );
      final repository = _repository(adapter);

      await repository.favoriteArtists();
      await repository.favoriteAlbums();
      await repository.favoriteTracks(
        page: const PageRequest(startIndex: 0, limit: 40),
      );

      expect(adapter.requests[0].path, JellyfinMediaApi.albumArtistsPath);
      expect(adapter.requests[0].queryParameters['isFavorite'], isTrue);
      expect(
        adapter.requests[1].queryParameters['includeItemTypes'],
        'MusicAlbum',
      );
      expect(adapter.requests[1].queryParameters['isFavorite'], isTrue);
      expect(adapter.requests[1].queryParameters['sortBy'], 'SortName');
      expect(adapter.requests[2].queryParameters['includeItemTypes'], 'Audio');
      expect(adapter.requests[2].queryParameters['isFavorite'], isTrue);
      expect(adapter.requests[2].queryParameters['limit'], 40);
    });

    test('maps the favorites to domain entities and pages them', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 'a1', 'Name': 'Blue Train', 'Type': 'MusicAlbum'},
          ], totalRecordCount: 3),
        ),
      );

      final page = (await _repository(adapter).favoriteAlbums()).valueOrNull!;

      expect(page.items.single.name, 'Blue Train');
      expect(page.totalCount, 3);
      expect(page.hasMore, isTrue);
    });
  });

  test('orders an album in disc and track order', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(adapter).tracks(albumId: _albumId);

    final query = adapter.requests.single.queryParameters;
    expect(query['parentId'], 'album-1');
    expect(query['sortBy'], 'ParentIndexNumber,IndexNumber');
  });

  test(
    'keeps the usable tracks of an album that has an unreadable one',
    () async {
      // The roadmap's twelve-track album with one bad track: eleven songs
      // and one marked entry, not a failed screen.
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 't1', 'Name': 'So What', 'Type': 'Audio'},
            {'Id': 't2', 'Type': 'Audio'},
            {'Id': 't3', 'Name': 'Blue in Green', 'Type': 'Audio'},
          ]),
        ),
      );

      final result = await _repository(adapter).tracks(albumId: _albumId);

      final page = result.valueOrNull!;
      expect(page.items.map((track) => track.name), [
        'So What',
        'Blue in Green',
      ]);
      expect(page.unavailable.single.id, 't2');
      expect(page.hasUnavailable, isTrue);
    },
  );

  test('loads one album', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(
        itemsResponse([
          {
            'Id': 'album-1',
            'Name': 'Kind of Blue',
            'Type': 'MusicAlbum',
            'ProductionYear': 1959,
          },
        ]),
      ),
    );

    final result = await _repository(adapter).album(_albumId);

    expect(result.valueOrNull!.productionYear, 1959);
    expect(adapter.requests.single.queryParameters['ids'], 'album-1');
  });

  test('reports a removed album as unavailable rather than empty', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _repository(adapter).album(_albumId);

    expect(result.failureOrNull, isA<UnavailableFailure>());
  });

  test('will not query one server for another server\'s item', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _repository(adapter).album(_elsewhere);

    expect(result.failureOrNull, isA<UnavailableFailure>());
    expect(adapter.callCount, isZero);
  });

  test('fails cleanly when nobody is signed in', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    final result = await _repository(
      adapter,
      context: FakeSessionContext.signedOut(),
    ).artists();

    expect(result.failureOrNull, isA<UnauthorizedFailure>());
    expect(adapter.callCount, isZero);
  });

  test('passes a server failure through as a failure', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody({}, statusCode: 500),
    );

    final result = await _repository(adapter).artists();

    expect(result.isErr, isTrue);
  });

  test('searches each category server-side, not in Dart', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );
    final repository = _repository(adapter);

    await repository.artists(searchTerm: 'miles');
    await repository.albums(searchTerm: 'miles');
    await repository.tracks(searchTerm: 'miles');

    expect(adapter.requests.map((r) => r.queryParameters['searchTerm']), [
      'miles',
      'miles',
      'miles',
    ]);
    // Still a window, still one category per query — a music search must
    // not turn into "fetch the library and filter it".
    expect(
      adapter.requests.map((r) => r.queryParameters['limit']),
      everyElement(PageRequest.defaultLimit),
    );
    expect(adapter.requests.last.queryParameters['includeItemTypes'], 'Audio');
  });

  test('treats a blank search term as no search at all', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(adapter).albums(searchTerm: '   ');

    expect(
      adapter.requests.single.queryParameters.containsKey('searchTerm'),
      isFalse,
    );
  });

  test('keeps a search inside one artist when asked', () async {
    final adapter = FakeDioAdapter(
      (_) async => jsonResponseBody(itemsResponse(const [])),
    );

    await _repository(adapter).tracks(artistId: _artistId, searchTerm: 'blue');

    final query = adapter.requests.single.queryParameters;
    expect(query['artistIds'], 'artist-1');
    expect(query['searchTerm'], 'blue');
  });

  group('artistStats (v0.1.6)', () {
    test('reports album and song counts, and their summed runtime', () async {
      final adapter = FakeDioAdapter((options) async {
        final types = options.queryParameters['includeItemTypes'];
        if (types == 'MusicAlbum') {
          return jsonResponseBody(itemsResponse(const [], totalRecordCount: 7));
        }
        // Two songs, three minutes each — one page covers both.
        return jsonResponseBody(
          itemsResponse([
            {'Id': 't1', 'Name': 'So What', 'RunTimeTicks': 1800000000},
            {
              'Id': 't2',
              'Name': 'Freddie Freeloader',
              'RunTimeTicks': 1800000000,
            },
          ], totalRecordCount: 2),
        );
      });

      final result = await _repository(adapter).artistStats(_artistId);

      final stats = result.valueOrNull!;
      expect(stats.albumCount, 7);
      expect(stats.songCount, 2);
      expect(stats.totalDuration, const Duration(minutes: 6));
    });

    test('omits the total when there are too many songs to sum', () async {
      final adapter = FakeDioAdapter((options) async {
        final types = options.queryParameters['includeItemTypes'];
        if (types == 'MusicAlbum') {
          return jsonResponseBody(itemsResponse(const [], totalRecordCount: 1));
        }
        return jsonResponseBody(
          itemsResponse(
            const [],
            totalRecordCount: ArtistStats.durationSumLimit + 1,
          ),
        );
      });

      final result = await _repository(adapter).artistStats(_artistId);

      final stats = result.valueOrNull!;
      expect(stats.songCount, ArtistStats.durationSumLimit + 1);
      expect(stats.totalDuration, isNull);
      // The duration-summing pages were never requested.
      expect(adapter.callCount, 2);
    });

    test(
      'propagates a transport failure instead of a partial answer',
      () async {
        final adapter = FakeDioAdapter(
          (_) async => jsonResponseBody({}, statusCode: 401),
        );

        final result = await _repository(adapter).artistStats(_artistId);

        expect(result.failureOrNull, isA<UnauthorizedFailure>());
      },
    );
  });

  group('related artists and albums (v0.3.5)', () {
    test('reads the /Similar route and maps the same-typed rows', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 'artist-2', 'Name': 'John Coltrane', 'Type': 'MusicArtist'},
            {'Id': 'artist-3', 'Name': 'Bill Evans', 'Type': 'MusicArtist'},
          ]),
        ),
      );

      final result = await _repository(adapter).relatedArtists(_artistId);

      expect(
        adapter.requests.single.path,
        JellyfinMediaApi.similarItemsPath('artist-1'),
      );
      expect(result.valueOrNull!.map((a) => a.name), [
        'John Coltrane',
        'Bill Evans',
      ]);
    });

    test('drops a row that is not of the kind asked for', () async {
      // The similar-albums call comes back with a playlist mixed in; it is
      // left out rather than shown as a broken card.
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 'al2', 'Name': 'Milestones', 'Type': 'MusicAlbum'},
            {'Id': 'pl1', 'Name': 'A playlist', 'Type': 'Playlist'},
          ]),
        ),
      );

      final result = await _repository(adapter).similarAlbums(_albumId);

      expect(result.valueOrNull!.map((a) => a.name), ['Milestones']);
    });

    test('an empty answer is Ok with an empty list', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );

      final result = await _repository(adapter).similarAlbums(_albumId);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('a server without the endpoint surfaces its failure', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody({}, statusCode: 404),
      );

      final result = await _repository(adapter).relatedArtists(_artistId);

      expect(result.failureOrNull, isA<UnavailableFailure>());
    });

    test('an id from another server never queries this one', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );

      final result = await _repository(adapter).similarAlbums(_elsewhere);

      expect(result.failureOrNull, isA<UnavailableFailure>());
      expect(adapter.callCount, isZero);
    });
  });

  group('library exploration (v0.4.4)', () {
    test('filters albums by genre and by decade, server-side', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );
      final repository = _repository(adapter);

      await repository.albums(genre: 'Jazz');
      await repository.albums(decadeStart: 1990);

      expect(adapter.requests[0].queryParameters['genres'], 'Jazz');
      expect(adapter.requests[0].queryParameters.containsKey('years'), isFalse);
      expect(
        adapter.requests[1].queryParameters['years'],
        '1990,1991,1992,1993,1994,1995,1996,1997,1998,1999',
      );
    });

    test('reads the genre facet from /MusicGenres, bounded and scoped', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 'g1', 'Name': 'Jazz', 'Type': 'MusicGenre'},
            {'Id': 'g2', 'Name': 'Rock', 'Type': 'MusicGenre'},
          ]),
        ),
      );

      final result = await _repository(adapter).genres();

      expect(adapter.requests.single.path, JellyfinMediaApi.musicGenresPath);
      expect(result.valueOrNull, ['Jazz', 'Rock']);
    });

    test('reads the decade facet from /Years, bucketed newest first', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 'y1', 'Name': '1959', 'ProductionYear': 1959},
            {'Id': 'y2', 'Name': '1965', 'ProductionYear': 1965},
            {'Id': 'y3', 'Name': '2021', 'ProductionYear': 2021},
          ]),
        ),
      );

      final result = await _repository(adapter).decades();

      expect(adapter.requests.single.path, JellyfinMediaApi.yearsPath);
      expect(
        adapter.requests.single.queryParameters['includeItemTypes'],
        'MusicAlbum',
      );
      // 1959 and 1965 both fall in the 1950s/1960s decades respectively —
      // one decade per bucket, newest first.
      expect(result.valueOrNull, [2020, 1960, 1950]);
    });

    test('randomAlbum asks the server for one row, sorted Random', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 'album-1', 'Name': 'Kind of Blue', 'Type': 'MusicAlbum'},
          ]),
        ),
      );

      final result = await _repository(adapter).randomAlbum();

      expect(adapter.requests.single.queryParameters['sortBy'], 'Random');
      expect(adapter.requests.single.queryParameters['limit'], 1);
      expect(adapter.requests.single.queryParameters['includeItemTypes'], 'MusicAlbum');
      expect(result.valueOrNull!.name, 'Kind of Blue');
    });

    test('randomArtist asks the album-artist route, sorted Random', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(
          itemsResponse([
            {'Id': 'artist-1', 'Name': 'Miles Davis', 'Type': 'MusicArtist'},
          ]),
        ),
      );

      final result = await _repository(adapter).randomArtist();

      expect(adapter.requests.single.path, JellyfinMediaApi.albumArtistsPath);
      expect(adapter.requests.single.queryParameters['sortBy'], 'Random');
      expect(result.valueOrNull!.name, 'Miles Davis');
    });

    test('an empty library reports random pick as unavailable', () async {
      final adapter = FakeDioAdapter(
        (_) async => jsonResponseBody(itemsResponse(const [])),
      );

      final result = await _repository(adapter).randomAlbum();

      expect(result.failureOrNull, isA<UnavailableFailure>());
    });
  });
}
