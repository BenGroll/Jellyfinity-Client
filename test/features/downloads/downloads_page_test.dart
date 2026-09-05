import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/downloads/presentation/DownloadsPage.dart';

import '../../support/download_fakes.dart';
import '../../support/music_fakes.dart';
import '../../support/pump_app.dart';
import '../../support/session_fakes.dart';
import '../../support/settings_fakes.dart';

TrackDownload _record(
  String item, {
  required DownloadState state,
  required DownloadOwner owner,
  String? albumName,
  int? totalBytes,
}) => TrackDownload(
  id: mediaId(item),
  title: 'Song $item',
  state: state,
  owners: {owner},
  requestedAt: DateTime.utc(2026, 1, 1),
  albumName: albumName,
  totalBytes: totalBytes,
  receivedBytes: state == DownloadState.completed ? (totalBytes ?? 0) : 0,
);

Future<void> _openDownloads(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Downloads'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state when nothing is downloaded', (tester) async {
    final downloads = fakeDownloadsCubit();
    await downloads.restore();

    final scope = TestSessionScope();
    await pumpApp(tester, scope: scope, downloads: downloads);
    await scope.signIn();
    await tester.pumpAndSettle();

    await _openDownloads(tester);

    expect(find.text('Nothing downloaded yet'), findsOneWidget);
  });

  testWidgets('shows storage in use, a collection and its progress', (
    tester,
  ) async {
    final store = InMemoryDownloadStore();
    final album = DownloadOwner.album(mediaId('al-1'));
    for (final record in [
      _record(
        't1',
        state: DownloadState.completed,
        owner: album,
        albumName: 'Kind of Blue',
        totalBytes: 3_000_000,
      ),
      _record(
        't2',
        state: DownloadState.failed,
        owner: album,
        albumName: 'Kind of Blue',
      ),
    ]) {
      store.records[record.id] = record;
    }
    final downloads = fakeDownloadsCubit(store: store);
    await downloads.restore();

    final scope = TestSessionScope();
    await pumpApp(tester, scope: scope, downloads: downloads);
    await scope.signIn();
    await tester.pumpAndSettle();

    await _openDownloads(tester);

    expect(find.text('3 MB'), findsOneWidget);
    expect(find.text('Kind of Blue'), findsWidgets);
    // The failed member is named, not averaged away.
    expect(find.textContaining('1 failed'), findsWidgets);
    // And it surfaces in the attention section as its own row.
    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets('a waiting-for-network download reads as waiting, not failed', (
    tester,
  ) async {
    final settings = fakeSettingsCubit(downloadsWifiOnly: true);
    addTearDown(settings.close);
    final engine = FakeDownloadEngine();
    final downloads = fakeDownloadsCubit(
      engine: engine,
      settings: settings,
      network: FakeNetworkCondition(state: NetworkState.metered),
    );
    addTearDown(downloads.close);
    await downloads.restore();

    // Rendered directly (no router) so a single pump chain settles the
    // worker into the held state — Wi-Fi-only on, connection metered.
    await pumpThemed(tester, const DownloadsPage(), downloads: downloads);
    await tester.pumpAndSettle();
    await downloads.downloadTrack(testTrack('t1'));
    await tester.pumpAndSettle();

    expect(
      downloads.state.stateOf(mediaId('t1')),
      DownloadState.waitingForNetwork,
    );
    expect(engine.fetched, isEmpty);
    expect(find.byTooltip('Waiting for Wi-Fi'), findsOneWidget);
  });
}
