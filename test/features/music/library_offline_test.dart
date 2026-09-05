import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connectivity/OfflineCubit.dart';
import 'package:jellyfinity/app/downloads/DownloadsCubit.dart';
import 'package:jellyfinity/domain/connectivity/OfflineLibraryScope.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/library/LibraryPage.dart';
import 'package:jellyfinity/features/music/presentation/widgets/downloaded_marker.dart';
import 'package:jellyfinity/features/music/presentation/widgets/MediaArtwork.dart';
import 'package:jellyfinity/features/music/presentation/widgets/music_rows.dart';

import '../../support/download_fakes.dart';
import '../../support/music_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/pump_app.dart';
import '../../support/settings_fakes.dart';

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required FakeMusicLibraryRepository music,
  required FakeDownloadsLibrarySource downloads,
  required bool offline,
  OfflineLibraryScope scope = OfflineLibraryScope.unlimited,
  DownloadsCubit? downloadsCubit,
}) async {
  final offlineMode = FakeOfflineMode(manual: offline);
  await pumpThemed(
    tester,
    LibraryPage(
      artists: ArtistsCubit(music, downloads, offlineMode),
      albums: AlbumsCubit(music, downloads, offlineMode),
      songs: SongsCubit(music, downloads, offlineMode),
      playlists: PlaylistsCubit(
        FakePlaylistRepository(),
        downloads,
        offlineMode,
      ),
    ),
    offline: OfflineCubit(offlineMode),
    settings: fakeSettingsCubit(offlineLibraryScope: scope),
    downloads: downloadsCubit,
  );
}

void main() {
  setUp(() {
    MediaArtwork.imageBuilderOverride = (_, _) => const SizedBox.shrink();
  });
  tearDown(() => MediaArtwork.imageBuilderOverride = null);

  testWidgets(
    'offline with the Downloads-only scope shows only downloaded music (v0.2.3)',
    (tester) async {
      final music = FakeMusicLibraryRepository()
        ..trackList = [testTrack('server-1', name: 'Server Song')];
      final downloads = FakeDownloadsLibrarySource()
        ..trackList = [testTrack('kept-1', name: 'Kept Song')];

      await _pumpLibrary(
        tester,
        music: music,
        downloads: downloads,
        offline: true,
        scope: OfflineLibraryScope.limited,
      );
      await tester.pumpAndSettle();

      // The offline line lives in the shared header now, not the library
      // page — see home_library_header_test.

      await tester.tap(find.text('Songs'));
      await tester.pumpAndSettle();

      expect(find.text('Kept Song'), findsOneWidget);
      expect(find.text('Server Song'), findsNothing);
    },
  );

  testWidgets('online, the Downloads-only scope does nothing (v0.2.3)', (
    tester,
  ) async {
    final music = FakeMusicLibraryRepository()
      ..trackList = [testTrack('server-1', name: 'Server Song')];

    await _pumpLibrary(
      tester,
      music: music,
      downloads: FakeDownloadsLibrarySource(),
      offline: false,
      scope: OfflineLibraryScope.limited,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Offline'), findsNothing);

    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();

    expect(find.text('Server Song'), findsOneWidget);
  });

  testWidgets('a downloaded album carries a marker in the grid (v0.2.3)', (
    tester,
  ) async {
    const albumId = MediaId(serverId: 'server-1', itemId: 'al1');
    final music = FakeMusicLibraryRepository()
      ..albumList = [testAlbum('al1', name: 'Kind of Blue')];

    final store = InMemoryDownloadStore();
    final engine = FakeDownloadEngine();
    const trackId = MediaId(serverId: 'server-1', itemId: 't1');
    store.records[trackId] = downloadRecord(
      trackId,
      state: DownloadState.completed,
      owners: {DownloadOwner.album(albumId)},
      totalBytes: 1000,
      receivedBytes: 1000,
    );
    engine.stored[trackId] = Uri.file('/tmp/t1');
    final downloadsCubit = fakeDownloadsCubit(store: store, engine: engine);
    addTearDown(downloadsCubit.close);
    await downloadsCubit.restore();

    await _pumpLibrary(
      tester,
      music: music,
      downloads: FakeDownloadsLibrarySource(),
      offline: false,
      downloadsCubit: downloadsCubit,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlbumTile),
        matching: find.byType(DownloadedMarker),
      ),
      findsOneWidget,
    );
  });
}
