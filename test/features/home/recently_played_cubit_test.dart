import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/ListeningContext.dart';
import 'package:jellyfinity/domain/media/ListeningHistoryEntry.dart';
import 'package:jellyfinity/features/home/presentation/RecentlyPlayedCubit.dart';

import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';

ListeningHistoryEntry _albumEntry(
  String id, {
  required DateTime lastPlayedAt,
  int playCount = 1,
}) => ListeningHistoryEntry(
  context: ListeningContext(
    kind: ListeningContextKind.album,
    id: mediaId(id),
    name: 'Album $id',
  ),
  firstPlayedAt: lastPlayedAt,
  lastPlayedAt: lastPlayedAt,
  playCount: playCount,
);

RecentlyPlayedCubit _cubit(
  SeededListeningHistoryRepository history, [
  FakeMediaMetadataRepository? metadata,
]) {
  final cubit = RecentlyPlayedCubit(
    history,
    metadata ?? FakeMediaMetadataRepository(),
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  test('load surfaces the history newest-first', () async {
    final now = DateTime.utc(2026, 9, 7, 12);
    final history = SeededListeningHistoryRepository()
      ..entries = [
        _albumEntry('b', lastPlayedAt: now),
        _albumEntry('a', lastPlayedAt: now.subtract(const Duration(days: 1))),
      ];
    final cubit = _cubit(history);

    await cubit.load();

    expect(cubit.state.status, RecentlyPlayedStatus.loaded);
    expect(cubit.state.entries.map((e) => e.context.name), [
      'Album b',
      'Album a',
    ]);
  });

  test('an empty history loads empty, not failed', () async {
    final cubit = _cubit(SeededListeningHistoryRepository());

    await cubit.load();

    expect(cubit.state.status, RecentlyPlayedStatus.loaded);
    expect(cubit.state.isEmpty, isTrue);
  });

  test('a failed first read is a failure with nothing shown', () async {
    final history = SeededListeningHistoryRepository()
      ..failure = const UnexpectedFailure('Could not read listening history.');
    final cubit = _cubit(history);

    await cubit.load();

    expect(cubit.state.status, RecentlyPlayedStatus.failed);
    expect(cubit.state.failure, isA<UnexpectedFailure>());
  });

  test('a failed refresh keeps the rows already on screen', () async {
    final now = DateTime.utc(2026, 9, 7, 12);
    final history = SeededListeningHistoryRepository()
      ..entries = [_albumEntry('a', lastPlayedAt: now)];
    final cubit = _cubit(history);
    await cubit.load();

    history.failure = const UnexpectedFailure('gone');
    await cubit.refresh();

    expect(cubit.state.status, RecentlyPlayedStatus.loaded);
    expect(cubit.state.entries, hasLength(1));
    expect(cubit.state.failure, isNull);
  });

  test('resolveTrack returns the track behind a track-kind row', () async {
    final track = testTrack('t1', name: 'Solo Flight');
    final metadata = FakeMediaMetadataRepository()..items = [track];
    final cubit = _cubit(SeededListeningHistoryRepository(), metadata);

    final result = await cubit.resolveTrack(track.id);

    expect(result.valueOrNull?.name, 'Solo Flight');
  });

  test('resolveTrack fails cleanly when the id no longer resolves', () async {
    final cubit = _cubit(
      SeededListeningHistoryRepository(),
      FakeMediaMetadataRepository()
        ..failure = const UnavailableFailure('No such item.'),
    );

    final result = await cubit.resolveTrack(mediaId('gone'));

    expect(result.isErr, isTrue);
  });
}
