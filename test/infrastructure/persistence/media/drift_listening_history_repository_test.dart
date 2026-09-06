import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/ListeningContext.dart';
import 'package:jellyfinity/domain/media/ListeningHistoryRepository.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';
import 'package:jellyfinity/infrastructure/persistence/media/DriftListeningHistoryRepository.dart';

import '../../../support/FakeSessionContext.dart';
import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeSessionContext session;
  late DriftListeningHistoryRepository repository;

  setUp(() {
    db = newTestDatabase();
    session = FakeSessionContext();
    repository = DriftListeningHistoryRepository(db, session);
  });

  tearDown(() => db.close());

  ListeningContext album(String id, {String name = 'Kind of Blue'}) =>
      ListeningContext(
        kind: ListeningContextKind.album,
        id: MediaId(serverId: 'server-1', itemId: id),
        name: name,
        subtitle: 'Miles Davis',
      );

  ListeningContext track(String id) => ListeningContext(
    kind: ListeningContextKind.track,
    id: MediaId(serverId: 'server-1', itemId: id),
    name: 'Flamenco Sketches',
  );

  ListeningPlay play(ListeningContext context, DateTime at) =>
      ListeningPlay(context: context, playedAt: at);

  test('a first play becomes one entry', () async {
    await repository.record(play(album('album-1'), DateTime.utc(2026, 1, 1)));

    final entries = (await repository.recent(limit: 10)).valueOrNull!;
    expect(entries, hasLength(1));
    expect(entries.single.context.id.itemId, 'album-1');
    expect(entries.single.playCount, 1);
  });

  test(
    'playing an album straight through collapses into one entry, not twelve',
    () async {
      for (var i = 0; i < 12; i++) {
        await repository.record(
          play(album('album-1'), DateTime.utc(2026, 1, 1, 12, i)),
        );
      }

      final entries = (await repository.recent(limit: 50)).valueOrNull!;
      expect(entries, hasLength(1));
      expect(entries.single.playCount, 12);
      expect(entries.single.firstPlayedAt, DateTime.utc(2026, 1, 1, 12, 0));
      expect(entries.single.lastPlayedAt, DateTime.utc(2026, 1, 1, 12, 11));
    },
  );

  test('returning to an album moves it back to the front', () async {
    await repository.record(play(album('album-1'), DateTime.utc(2026, 1, 1)));
    await repository.record(play(album('album-2'), DateTime.utc(2026, 1, 2)));
    await repository.record(play(album('album-1'), DateTime.utc(2026, 1, 3)));

    final entries = (await repository.recent(limit: 10)).valueOrNull!;
    expect(entries.map((e) => e.context.id.itemId), ['album-1', 'album-2']);
    expect(entries.first.playCount, 2);
  });

  test('a clock that runs backwards never drags an entry earlier', () async {
    await repository.record(play(album('album-1'), DateTime.utc(2026, 1, 5)));
    await repository.record(play(album('album-1'), DateTime.utc(2026, 1, 1)));

    final entries = (await repository.recent(limit: 10)).valueOrNull!;
    expect(entries.single.lastPlayedAt, DateTime.utc(2026, 1, 5));
  });

  test('history is bounded: the oldest-played entry is evicted', () async {
    for (
      var i = 0;
      i < DriftListeningHistoryRepository.maxEntriesPerProfile + 5;
      i++
    ) {
      await repository.record(
        play(
          album('album-$i'),
          DateTime.utc(2026, 1, 1).add(Duration(days: i)),
        ),
      );
    }

    final entries = (await repository.recent(limit: 1000)).valueOrNull!;
    expect(
      entries,
      hasLength(DriftListeningHistoryRepository.maxEntriesPerProfile),
    );
    // The five oldest are gone; album-5 is the new tail.
    final ids = entries.map((e) => e.context.id.itemId).toSet();
    expect(ids.contains('album-0'), isFalse);
    expect(ids.contains('album-4'), isFalse);
    expect(ids.contains('album-5'), isTrue);
  });

  test('bumping an existing entry never evicts another', () async {
    for (
      var i = 0;
      i < DriftListeningHistoryRepository.maxEntriesPerProfile;
      i++
    ) {
      await repository.record(
        play(
          album('album-$i'),
          DateTime.utc(2026, 1, 1).add(Duration(days: i)),
        ),
      );
    }
    // Re-play the oldest — the row count cannot grow, so nothing is
    // evicted and the profile stays exactly at the cap.
    await repository.record(play(album('album-0'), DateTime.utc(2027, 1, 1)));

    final entries = (await repository.recent(limit: 1000)).valueOrNull!;
    expect(
      entries,
      hasLength(DriftListeningHistoryRepository.maxEntriesPerProfile),
    );
    expect(entries.first.context.id.itemId, 'album-0');
  });

  test("one profile's history never appears under another's", () async {
    await repository.record(play(album('album-1'), DateTime.utc(2026, 1, 1)));

    session.userId = 'user-2';
    expect((await repository.recent(limit: 10)).valueOrNull, isEmpty);

    await repository.record(play(album('album-2'), DateTime.utc(2026, 1, 2)));
    final second = (await repository.recent(limit: 10)).valueOrNull!;
    expect(second.map((e) => e.context.id.itemId), ['album-2']);

    session.userId = 'user-1';
    final first = (await repository.recent(limit: 10)).valueOrNull!;
    expect(first.map((e) => e.context.id.itemId), ['album-1']);
  });

  test('signing out hides history and makes recording a no-op', () async {
    await repository.record(play(album('album-1'), DateTime.utc(2026, 1, 1)));

    session.signOut();
    expect((await repository.recent(limit: 10)).valueOrNull, isEmpty);
    expect(
      (await repository.record(
        play(album('x'), DateTime.utc(2026, 1, 2)),
      )).isOk,
      isTrue,
    );

    // The signed-out record wrote nothing; only the earlier signed-in
    // play remains.
    final rows = await db.select(db.listeningHistoryEntries).get();
    expect(rows.map((r) => r.contextItemId), ['album-1']);
  });

  test('an album context and a track context are distinct entries', () async {
    await repository.record(play(album('album-1'), DateTime.utc(2026, 1, 1)));
    await repository.record(play(track('track-1'), DateTime.utc(2026, 1, 2)));

    final entries = (await repository.recent(limit: 10)).valueOrNull!;
    expect(entries, hasLength(2));
    expect(entries.map((e) => e.context.kind).toSet(), {
      ListeningContextKind.album,
      ListeningContextKind.track,
    });
  });

  test('recent respects its limit, newest first', () async {
    for (var i = 0; i < 6; i++) {
      await repository.record(
        play(
          album('album-$i'),
          DateTime.utc(2026, 1, 1).add(Duration(days: i)),
        ),
      );
    }

    final entries = (await repository.recent(limit: 3)).valueOrNull!;
    expect(entries.map((e) => e.context.id.itemId), [
      'album-5',
      'album-4',
      'album-3',
    ]);
  });
}
