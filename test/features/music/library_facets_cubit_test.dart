import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/features/music/presentation/library/library_facets_cubit.dart';

import '../../support/music_fakes.dart';
import '../../support/offline_fakes.dart';

void main() {
  group('LibraryFacetsCubit (v0.4.4)', () {
    test('load surfaces both shelves independently', () async {
      final music = FakeMusicLibraryRepository()
        ..genreList = ['Jazz', 'Rock']
        ..decadeList = [2020, 1990];
      final cubit = LibraryFacetsCubit(music, FakeOfflineMode());
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.genres, ['Jazz', 'Rock']);
      expect(cubit.state.decades, [2020, 1990]);
      expect(cubit.state.genresLoading, isFalse);
      expect(cubit.state.decadesLoading, isFalse);
      expect(cubit.state.genresFailure, isNull);
      expect(cubit.state.decadesFailure, isNull);
    });

    test('load is safe to call again once already loaded', () async {
      final music = FakeMusicLibraryRepository()..genreList = ['Jazz'];
      final cubit = LibraryFacetsCubit(music, FakeOfflineMode());
      addTearDown(cubit.close);

      await cubit.load();
      music.genreList = ['Rock'];
      await cubit.load();

      // The second call did not re-ask the server.
      expect(cubit.state.genres, ['Jazz']);
    });

    test(
      'a server that only supports one facet still shows the other',
      () async {
        final music = FakeMusicLibraryRepository()
          ..genreList = ['Jazz']
          ..decadesFailure = const UnavailableFailure(
            'no /Years on this server',
          );
        final cubit = LibraryFacetsCubit(music, FakeOfflineMode());
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.genres, ['Jazz']);
        expect(cubit.state.genresFailure, isNull);
        expect(cubit.state.decades, isEmpty);
        expect(cubit.state.decadesFailure, isA<UnavailableFailure>());
      },
    );

    test('working offline, both shelves report their failure honestly', () async {
      final music = FakeMusicLibraryRepository()
        ..facetFailure = const RecoverableFailure('You are offline.');
      final cubit = LibraryFacetsCubit(music, FakeOfflineMode());
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.genresFailure, isA<RecoverableFailure>());
      expect(cubit.state.decadesFailure, isA<RecoverableFailure>());
    });

    test('coming back online re-reads shelves that failed offline', () async {
      final music = FakeMusicLibraryRepository()
        ..facetFailure = const RecoverableFailure('offline');
      final offline = FakeOfflineMode(manual: true);
      final cubit = LibraryFacetsCubit(music, offline);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.genresFailure, isNotNull);

      music
        ..facetFailure = null
        ..genreList = ['Jazz']
        ..decadeList = [2020];
      await offline.setManual(false);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.genres, ['Jazz']);
      expect(cubit.state.decades, [2020]);
      expect(cubit.state.genresFailure, isNull);
    });
  });
}
