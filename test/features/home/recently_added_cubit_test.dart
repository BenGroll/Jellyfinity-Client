import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/home/presentation/RecentlyAddedCubit.dart';

import '../../support/music_fakes.dart';

RecentlyAddedCubit _cubit(FakeMusicLibraryRepository music) {
  final cubit = RecentlyAddedCubit(music);
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  test(
    'load surfaces the newest albums in the order the server gave',
    () async {
      final music = FakeMusicLibraryRepository()
        ..recentlyAddedList = [
          testAlbum('new', name: 'Fresh'),
          testAlbum('old', name: 'Stale'),
        ];
      final cubit = _cubit(music);

      await cubit.load();

      expect(cubit.state.status, RecentlyAddedStatus.loaded);
      expect(cubit.state.albums.map((a) => a.name), ['Fresh', 'Stale']);
      expect(cubit.state.isCached, isFalse);
    },
  );

  test('an empty library loads empty, not failed', () async {
    final cubit = _cubit(FakeMusicLibraryRepository());

    await cubit.load();

    expect(cubit.state.status, RecentlyAddedStatus.loaded);
    expect(cubit.state.isEmpty, isTrue);
  });

  test('a failed first read is a failure with nothing shown', () async {
    final music = FakeMusicLibraryRepository()
      ..failure = const RecoverableFailure('You are offline.');
    final cubit = _cubit(music);

    await cubit.load();

    expect(cubit.state.status, RecentlyAddedStatus.failed);
    expect(cubit.state.failure, isA<RecoverableFailure>());
  });

  test('a failed refresh keeps the albums already on screen', () async {
    final music = FakeMusicLibraryRepository()
      ..recentlyAddedList = [testAlbum('a', name: 'Album A')];
    final cubit = _cubit(music);
    await cubit.load();

    music.failure = const RecoverableFailure('dropped');
    await cubit.refresh();

    expect(cubit.state.status, RecentlyAddedStatus.loaded);
    expect(cubit.state.albums, hasLength(1));
    expect(cubit.state.failure, isNull);
  });

  test('a cached answer is flagged so the section can say so', () async {
    final music = FakeMusicLibraryRepository()
      ..recentlyAddedList = [testAlbum('a')]
      ..source = PageSource.cache;
    final cubit = _cubit(music);

    await cubit.load();

    expect(cubit.state.status, RecentlyAddedStatus.loaded);
    expect(cubit.state.isCached, isTrue);
  });
}
