import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';
import 'package:jellyfinity/infrastructure/persistence/media/media_cache_store.dart';
import 'package:jellyfinity/infrastructure/persistence/media/MediaCollectionKey.dart';

import '../../../support/test_database.dart';

const _server = 'server-1';

MediaId _id(String itemId) => MediaId(serverId: _server, itemId: itemId);

Album _album(String id, {String name = 'Kind of Blue'}) => Album(
  id: _id(id),
  name: name,
  artists: [ArtistRef(name: 'Miles Davis', id: _id('artist-1'))],
  productionYear: 1959,
  duration: const Duration(minutes: 45),
  trackCount: 5,
  image: MediaImage(
    itemId: _id(id),
    kind: MediaImageKind.primary,
    tag: 'tag-$id',
    aspectRatio: 1,
  ),
);

Track _track(String id, {int? trackNumber}) => Track(
  id: _id(id),
  name: 'So What',
  artists: [const ArtistRef(name: 'Miles Davis')],
  albumId: _id('album-1'),
  albumName: 'Kind of Blue',
  trackNumber: trackNumber,
  discNumber: 1,
  duration: const Duration(minutes: 9, seconds: 22),
);

Page<T> _page<T extends MediaItem>(
  List<T> items, {
  int startIndex = 0,
  int? totalCount,
  List<UnavailableItem> unavailable = const [],
}) => Page<T>(
  content: Partial(available: items, unavailable: unavailable),
  startIndex: startIndex,
  totalCount: totalCount ?? items.length + unavailable.length,
);

void main() {
  late AppDatabase db;
  late MediaCacheStore store;

  setUp(() {
    db = newTestDatabase();
    store = DriftMediaCacheStore(db);
  });
  tearDown(() => db.close());

  test('has nothing to say about a collection never read', () async {
    final page = await store.readPage<Album>(
      _server,
      MediaCollectionKey.albums,
      const PageRequest.first(),
    );

    // Not an empty page: "nothing saved" and "no albums" are different
    // answers, and only one of them should be shown to the user.
    expect(page, isNull);
  });

  test('reads back a saved window as the same albums', () async {
    await store.savePage(
      MediaCollectionKey.albums,
      _page([_album('album-1'), _album('album-2', name: 'Blue Train')]),
    );

    final page = await store.readPage<Album>(
      _server,
      MediaCollectionKey.albums,
      const PageRequest.first(),
    );

    expect(page!.items.map((a) => a.name), ['Kind of Blue', 'Blue Train']);
    final first = page.items.first;
    expect(first.productionYear, 1959);
    expect(first.trackCount, 5);
    expect(first.duration, const Duration(minutes: 45));
    expect(first.artists.single.name, 'Miles Davis');
    expect(first.artists.single.isNavigable, isTrue);
    expect(first.image!.tag, 'tag-album-1');
  });

  test('says a cached read is cached, and its media unreachable', () async {
    await store.savePage(MediaCollectionKey.albums, _page([_album('album-1')]));

    final page = await store.readPage<Album>(
      _server,
      MediaCollectionKey.albums,
      const PageRequest.first(),
    );

    expect(page!.source, PageSource.cache);
    expect(page.isCached, isTrue);
    // The metadata is real; the album is not playable with no server.
    expect(page.items.single.availability, MediaAvailability.remoteUnavailable);
  });

  test('keeps the order the server chose, across windows', () async {
    await store.savePage(
      MediaCollectionKey.tracksOfAlbum('album-1'),
      _page([
        _track('t1', trackNumber: 1),
        _track('t2', trackNumber: 2),
      ], totalCount: 4),
    );
    await store.savePage(
      MediaCollectionKey.tracksOfAlbum('album-1'),
      _page(
        [_track('t3', trackNumber: 3), _track('t4', trackNumber: 4)],
        startIndex: 2,
        totalCount: 4,
      ),
    );

    final second = await store.readPage<Track>(
      _server,
      MediaCollectionKey.tracksOfAlbum('album-1'),
      const PageRequest(startIndex: 2, limit: 2),
    );

    expect(second!.items.map((t) => t.trackNumber), [3, 4]);
    expect(second.startIndex, 2);
    expect(second.totalCount, 4);
    expect(second.hasMore, isFalse);
  });

  test(
    'ends paging where the cache ends, not where the library does',
    () async {
      // Two windows of a 130k-song library were browsed before the server
      // went away. Offline, the list is 200 songs long — claiming 130k
      // would page into windows that were never saved.
      await store.savePage(
        MediaCollectionKey.tracks,
        _page([
          for (var i = 0; i < 100; i++) _track('t$i'),
        ], totalCount: 130000),
      );

      final page = await store.readPage<Track>(
        _server,
        MediaCollectionKey.tracks,
        const PageRequest.first(),
      );

      expect(page!.totalCount, 100);
      expect(page.hasMore, isFalse);
    },
  );

  test('keeps an unmappable row in its place', () async {
    await store.savePage(
      MediaCollectionKey.tracksOfAlbum('album-1'),
      _page(
        [_track('t1', trackNumber: 1)],
        unavailable: const [
          UnavailableItem(id: 't2', reason: 'This song is unavailable.'),
        ],
      ),
    );

    final page = await store.readPage<Track>(
      _server,
      MediaCollectionKey.tracksOfAlbum('album-1'),
      const PageRequest.first(),
    );

    expect(page!.items.single.trackNumber, 1);
    expect(page.unavailable.single.id, 't2');
    expect(page.consumed, 2);
  });

  test('a shrunken window forgets the rows that vanished', () async {
    final key = MediaCollectionKey.tracksOfAlbum('album-1');
    await store.savePage(key, _page([_track('t1'), _track('t2')]));

    await store.savePage(key, _page([_track('t1')]));

    final page = await store.readPage<Track>(
      _server,
      key,
      const PageRequest.first(),
    );
    expect(page!.items.map((t) => t.id.itemId), ['t1']);
  });

  test('refuses to hand a track back as an album', () async {
    await store.savePage(MediaCollectionKey.albums, _page([_track('t1')]));

    final page = await store.readPage<Album>(
      _server,
      MediaCollectionKey.albums,
      const PageRequest.first(),
    );

    expect(page!.items, isEmpty);
    expect(page.unavailable.single.id, 't1');
  });

  test('stores and returns a single item for a detail header', () async {
    await store.saveItem(_album('album-1'));

    final item = await store.readItem(_id('album-1'));

    expect(item, isA<Album>());
    expect(item!.availability, MediaAvailability.remoteUnavailable);
    expect(await store.readItem(_id('nope')), isNull);
  });

  test('does not cache media it has no columns for', () async {
    // Movies and episodes arrive with the release that browses them, and
    // with the columns their entities need.
    await store.saveItem(
      Movie(id: _id('movie-1'), name: 'Heat', progress: PlaybackProgress.none),
    );

    expect(await store.readItem(_id('movie-1')), isNull);
  });

  test('forgets a removed server completely', () async {
    await store.savePage(MediaCollectionKey.albums, _page([_album('album-1')]));

    await store.clearServer(_server);

    expect(
      await store.readPage<Album>(
        _server,
        MediaCollectionKey.albums,
        const PageRequest.first(),
      ),
      isNull,
    );
    expect(await store.readItem(_id('album-1')), isNull);
  });

  test('keeps one server\'s library out of another\'s', () async {
    await store.savePage(MediaCollectionKey.albums, _page([_album('album-1')]));

    final other = await store.readPage<Album>(
      'server-2',
      MediaCollectionKey.albums,
      const PageRequest.first(),
    );

    expect(other, isNull);
  });
}
