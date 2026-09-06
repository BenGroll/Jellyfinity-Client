import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/artist.dart';
import 'package:jellyfinity/domain/media/media_availability.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/playback/PlaybackQueue.dart';
import 'package:jellyfinity/domain/playback/QueueEntry.dart';
import 'package:jellyfinity/domain/playback/QueueRepository.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart';
import 'package:jellyfinity/infrastructure/persistence/playback/DriftQueueRepository.dart';

import '../../../support/test_database.dart';

QueueEntry _entry(String itemId, {String title = 'Track'}) => QueueEntry(
  id: MediaId(serverId: 's1', itemId: itemId),
  title: title,
  artist: 'Artist',
  albumName: 'Album',
  duration: const Duration(minutes: 3, seconds: 30),
);

void main() {
  late AppDatabase db;
  late QueueRepository repository;

  setUp(() {
    db = newTestDatabase();
    repository = DriftQueueRepository(db, DriftKeyValueStore(db));
  });
  tearDown(() => db.close());

  test('an empty database loads as an empty queue at zero position', () async {
    final result = await repository.load();

    final restored = result.valueOrNull!;
    expect(restored.queue.isEmpty, isTrue);
    expect(restored.position, Duration.zero);
  });

  test('round-trips entries, current index, shuffle and repeat', () async {
    final queue = PlaybackQueue.empty
        .withEntries([
          _entry('a', title: 'First'),
          _entry('b', title: 'Second'),
          _entry('c', title: 'Third'),
        ], startIndex: 1)
        .withRepeatMode(RepeatMode.all);

    await repository.replace(queue);
    final restored = (await repository.load()).valueOrNull!;

    expect(restored.queue.entries.map((e) => e.title), [
      'First',
      'Second',
      'Third',
    ]);
    expect(restored.queue.currentIndex, 1);
    expect(restored.queue.currentEntry!.title, 'Second');
    expect(restored.queue.repeatMode, RepeatMode.all);
  });

  test('a full display snapshot survives the round trip', () async {
    final entry = QueueEntry(
      id: MediaId(serverId: 's1', itemId: 'a'),
      title: 'Kind of Blue',
      artist: 'Miles Davis',
      albumName: 'Kind of Blue',
      duration: const Duration(minutes: 5),
      availability: MediaAvailability.remoteOnly,
    );

    await repository.replace(
      PlaybackQueue.empty.withEntries([entry], startIndex: 0),
    );
    final restored =
        (await repository.load()).valueOrNull!.queue.entries.single;

    expect(restored.title, 'Kind of Blue');
    expect(restored.artist, 'Miles Davis');
    expect(restored.albumName, 'Kind of Blue');
    expect(restored.duration, const Duration(minutes: 5));
  });

  test('the album and artist ids survive the round trip (v0.3.1)', () async {
    final entry = QueueEntry(
      id: MediaId(serverId: 's1', itemId: 'a'),
      title: 'So What',
      artist: 'Miles Davis, John Coltrane',
      artists: const [
        ArtistRef(
          name: 'Miles Davis',
          id: MediaId(serverId: 's1', itemId: 'md'),
        ),
        ArtistRef(name: 'John Coltrane'),
      ],
      albumId: const MediaId(serverId: 's1', itemId: 'kob'),
      albumName: 'Kind of Blue',
    );

    await repository.replace(
      PlaybackQueue.empty.withEntries([entry], startIndex: 0),
    );
    final restored =
        (await repository.load()).valueOrNull!.queue.entries.single;

    expect(restored.albumId, const MediaId(serverId: 's1', itemId: 'kob'));
    expect(restored.artists.map((a) => a.name), [
      'Miles Davis',
      'John Coltrane',
    ]);
    expect(restored.artists.first.id?.itemId, 'md');
    expect(restored.artists[1].id, isNull);
  });

  test('replace overwrites what was there before, not merges', () async {
    await repository.replace(
      PlaybackQueue.empty.withEntries([_entry('a')], startIndex: 0),
    );
    await repository.replace(
      PlaybackQueue.empty.withEntries([_entry('b')], startIndex: 0),
    );

    final restored = (await repository.load()).valueOrNull!;
    expect(restored.queue.entries, hasLength(1));
    expect(restored.queue.entries.single.id.itemId, 'b');
  });

  test('savePosition persists without touching the entries', () async {
    await repository.replace(
      PlaybackQueue.empty.withEntries([
        _entry('a'),
        _entry('b'),
      ], startIndex: 0),
    );

    await repository.savePosition(
      currentIndex: 1,
      position: const Duration(seconds: 42),
    );

    final restored = (await repository.load()).valueOrNull!;
    expect(restored.queue.entries, hasLength(2));
    expect(restored.queue.currentIndex, 1);
    expect(restored.position, const Duration(seconds: 42));
  });

  test('a marked-unavailable entry stays marked across a restart', () async {
    final queue = PlaybackQueue.empty
        .withEntries([_entry('a'), _entry('b')], startIndex: 0)
        .withEntryMarkedUnavailable(0);

    await repository.replace(queue);
    final restored = (await repository.load()).valueOrNull!;

    expect(
      restored.queue.entries.first.availability,
      MediaAvailability.remoteUnavailable,
    );
  });

  test('replacing with an empty queue clears the saved entries', () async {
    await repository.replace(
      PlaybackQueue.empty.withEntries([_entry('a')], startIndex: 0),
    );
    await repository.replace(PlaybackQueue.empty);

    final restored = (await repository.load()).valueOrNull!;
    expect(restored.queue.isEmpty, isTrue);
  });
}
