import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/Track.dart';
import 'package:jellyfinity/features/home/presentation/HomePage.dart';
import 'package:jellyfinity/features/music/presentation/search/InlineMusicSearch.dart';
import 'package:jellyfinity/features/shell/presentation/app_shell.dart';
import 'package:jellyfinity/features/shell/presentation/ShellDestination.dart';

import '../../support/connected_playback/connected_playback_fixtures.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('Ctrl+F opens search and Escape closes it', (tester) async {
    registerMusicCubits(music: FakeMusicLibraryRepository());
    final scope = await pumpApp(tester);
    await scope.signIn();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(InlineMusicSearch), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(InlineMusicSearch), findsNothing);
  });
  testWidgets('the shell wraps the authenticated section', (tester) async {
    final scope = await pumpApp(tester);
    await scope.signIn();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('shows a navigation bar once there is a second section', (
    tester,
  ) async {
    // v0.0.3 shipped Home alone and deliberately hid the bar; v0.0.8's
    // Music section (renamed Library in v0.0.10, ADR-0014) is what makes
    // it appear. v0.3.4 (ADR-0028) added Favorites between them, and
    // v0.6.0 added Remote after Library.
    expect(shellDestinations.map((d) => d.label), [
      'Home',
      'Favorites',
      'Library',
      'Remote',
    ]);

    final scope = await pumpApp(tester);
    await scope.signIn();
    await tester.pumpAndSettle();

    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    for (final destination in shellDestinations) {
      expect(
        find.descendant(of: bar, matching: find.text(destination.label)),
        findsOneWidget,
      );
    }
  });

  group('explicit takeover (v0.6.0)', () {
    Track track(String id) => Track(
      id: MediaId(serverId: 's1', itemId: id),
      name: 'Track $id',
      duration: const Duration(minutes: 3),
    );

    testWidgets(
      'starting local playback while controlling another device asks '
      'before doing anything, no matter which screen pressed play',
      (tester) async {
        final ownership = FakeRemotePlaybackOwnership()
          ..controlledDevice = device(name: 'Living Room TV');
        final playback = fakePlaybackCubit(remoteOwnership: ownership);
        addTearDown(playback.close);
        final scope = await pumpApp(tester, playback: playback);
        await scope.signIn();
        await tester.pumpAndSettle();

        unawaited(playback.playNow([track('a')], startIndex: 0));
        await tester.pumpAndSettle();

        expect(find.text('Play here instead?'), findsOneWidget);
        expect(playback.state.hasQueue, isFalse);

        await tester.tap(find.text('Play here'));
        await tester.pumpAndSettle();

        expect(ownership.releaseCalls, 1);
        expect(playback.state.hasQueue, isTrue);

        // Cleanup only — FakePlaybackEngine's periodic position-save timer
        // (started by _onStatus while playing) has nothing to stop it in
        // this harness the way a real audio completion would; unrelated
        // to what this test is verifying.
        await playback.pause();
        await tester.pump();
      },
    );

    testWidgets('cancelling leaves the other device alone', (tester) async {
      final ownership = FakeRemotePlaybackOwnership()
        ..controlledDevice = device(name: 'Living Room TV');
      final playback = fakePlaybackCubit(remoteOwnership: ownership);
      addTearDown(playback.close);
      final scope = await pumpApp(tester, playback: playback);
      await scope.signIn();
      await tester.pumpAndSettle();

      unawaited(playback.playNow([track('a')], startIndex: 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(ownership.releaseCalls, 0);
      expect(playback.state.hasQueue, isFalse);
      expect(find.text('Play here instead?'), findsNothing);
    });
  });
}
