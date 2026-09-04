@Tags(['scale'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';
import 'package:jellyfinity/infrastructure/persistence/media/media_cache_store.dart';
import 'package:jellyfinity/infrastructure/persistence/media/MediaCollectionKey.dart';

import '../../../support/test_database.dart';

/// The media-scale query test ADR-0010 deferred to v0.0.8, now that there
/// are real media tables to run it against.
///
/// The shape under test is the one the Songs list actually produces at
/// the development library's size: a cache filled one window at a time
/// until it holds ~130k songs, then windows read back out of the middle
/// of it. What must hold is that reading window number 1,300 costs the
/// same as reading window number 1 — if the cache degrades with its own
/// size, offline browsing gets slower the more the user has browsed,
/// which is the opposite of the point.
void main() {
  const trackCount = 130000;
  const windowSize = 100;

  late AppDatabase db;
  late MediaCacheStore store;

  setUp(() {
    db = newTestDatabase();
    store = DriftMediaCacheStore(db);
  });
  tearDown(() => db.close());

  test('caches and pages a 130k-song library by the window', () async {
    final fill = Stopwatch()..start();
    for (var start = 0; start < trackCount; start += windowSize) {
      await store.savePage(
        MediaCollectionKey.tracks,
        Page<Track>(
          content: Partial(
            available: [
              for (var i = start; i < start + windowSize; i++)
                Track(
                  id: MediaId(serverId: 'server-1', itemId: 'track-$i'),
                  name: 'Song $i',
                  artists: [ArtistRef(name: 'Artist ${i % 900}')],
                  albumId: MediaId(
                    serverId: 'server-1',
                    itemId: 'album-${i % 9000}',
                  ),
                  albumName: 'Album ${i % 9000}',
                  trackNumber: (i % 12) + 1,
                  duration: const Duration(minutes: 4),
                ),
            ],
          ),
          startIndex: start,
          totalCount: trackCount,
        ),
      );
    }
    fill.stop();

    final rows = await db
        .customSelect('SELECT COUNT(*) AS c FROM cached_media_items')
        .getSingle();
    expect(rows.read<int>('c'), trackCount);

    // A window from the far end of the collection, which is where an
    // index-less implementation would start scanning.
    final deep = Stopwatch()..start();
    final page = await store.readPage<Track>(
      'server-1',
      MediaCollectionKey.tracks,
      const PageRequest(startIndex: 129900, limit: windowSize),
    );
    deep.stop();

    expect(page!.items, hasLength(windowSize));
    expect(page.items.first.name, 'Song 129900');
    expect(page.items.first.albumName, 'Album ${129900 % 9000}');
    expect(page.totalCount, trackCount);
    expect(page.hasMore, isFalse);
    expect(
      deep.elapsedMilliseconds,
      lessThan(100),
      reason:
          'a window read must use the (server, collection, position) '
          'primary key rather than scanning 130k entries',
    );

    // Reading one song by id stays a point lookup at full size.
    final point = Stopwatch()..start();
    final one = await store.readItem(
      const MediaId(serverId: 'server-1', itemId: 'track-64000'),
    );
    point.stop();
    expect(one!.name, 'Song 64000');
    expect(point.elapsedMilliseconds, lessThan(50));

    // Generous ceiling: a smoke test for "does not fall over", not a
    // benchmark.
    expect(
      fill.elapsedMilliseconds,
      lessThan(120000),
      reason: 'filling the cache one window at a time should not degrade',
    );
  });
}
