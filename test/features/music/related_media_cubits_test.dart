import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/features/music/presentation/detail/related_media_cubits.dart';

import '../../support/music_fakes.dart';
import '../../support/offline_fakes.dart';

void main() {
  group('RelatedArtistsCubit (v0.3.5)', () {
    test('open surfaces the artists the server considers related', () async {
      final music = FakeMusicLibraryRepository()
        ..relatedArtistList = [
          testArtist('b', name: 'John Coltrane'),
          testArtist('c', name: 'Bill Evans'),
        ];
      final cubit = RelatedArtistsCubit(music, FakeOfflineMode());
      addTearDown(cubit.close);

      await cubit.open(mediaId('a'));

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.hasLoaded, isTrue);
      expect(cubit.state.items.map((a) => a.name), [
        'John Coltrane',
        'Bill Evans',
      ]);
      expect(cubit.state.isAbsent, isFalse);
    });

    test(
      'a server with nothing to suggest leaves the section absent',
      () async {
        final cubit = RelatedArtistsCubit(
          FakeMusicLibraryRepository(),
          FakeOfflineMode(),
        );
        addTearDown(cubit.close);

        await cubit.open(mediaId('a'));

        expect(cubit.state.hasLoaded, isTrue);
        expect(cubit.state.isAbsent, isTrue);
      },
    );

    test('a failed read is swallowed — the strip is a bonus', () async {
      final music = FakeMusicLibraryRepository()
        ..similarityFailure = const RecoverableFailure('no /Similar endpoint');
      final cubit = RelatedArtistsCubit(music, FakeOfflineMode());
      addTearDown(cubit.close);

      await cubit.open(mediaId('a'));

      expect(cubit.state.hasLoaded, isTrue);
      expect(cubit.state.isAbsent, isTrue);
    });

    test(
      'coming back online re-reads a strip that was empty offline',
      () async {
        final music = FakeMusicLibraryRepository()
          ..similarityFailure = const RecoverableFailure('offline');
        final offline = FakeOfflineMode(manual: true);
        final cubit = RelatedArtistsCubit(music, offline);
        addTearDown(cubit.close);

        await cubit.open(mediaId('a'));
        expect(cubit.state.isAbsent, isTrue);

        music
          ..similarityFailure = null
          ..relatedArtistList = [testArtist('b', name: 'John Coltrane')];
        await offline.setManual(false);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.items.single.name, 'John Coltrane');
      },
    );
  });

  group('SimilarAlbumsCubit (v0.3.5)', () {
    test('open surfaces similar albums, absent when there are none', () async {
      final music = FakeMusicLibraryRepository()
        ..similarAlbumList = [testAlbum('b', name: 'Milestones')];
      final cubit = SimilarAlbumsCubit(music, FakeOfflineMode());
      addTearDown(cubit.close);

      await cubit.open(mediaId('a'));
      expect(cubit.state.items.single.name, 'Milestones');

      final empty = SimilarAlbumsCubit(
        FakeMusicLibraryRepository(),
        FakeOfflineMode(),
      );
      addTearDown(empty.close);
      await empty.open(mediaId('a'));
      expect(empty.state.isAbsent, isTrue);
    });
  });
}
