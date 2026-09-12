import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/favorites/presentation/FavoritesPage.dart';
import 'package:jellyfinity/features/music/presentation/search/InlineMusicSearch.dart';
import 'package:jellyfinity/features/shell/presentation/TelevisionNavigationRail.dart';

import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('TV mode uses a readable rail and D-pad navigation', (
    tester,
  ) async {
    registerMusicCubits(music: FakeMusicLibraryRepository());
    final scope = await pumpApp(
      tester,
      televisionDetector: () async => true,
      viewportSize: const Size(1280, 720),
    );
    await scope.signIn();
    await tester.pumpAndSettle();

    expect(find.byType(TelevisionNavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('television-navigation')), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey('television-destination-Home')),
          )
          .autofocus,
      isTrue,
    );
    expect(
      Theme.of(
        tester.element(find.byType(TelevisionNavigationRail)),
      ).textTheme.bodyLarge?.fontSize,
      18,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.byType(FavoritesPage), findsOneWidget);
  });

  testWidgets('Fire TV Menu opens the app sidebar', (tester) async {
    final scope = await pumpApp(
      tester,
      televisionMode: true,
      viewportSize: const Size(1280, 720),
    );
    await scope.signIn();
    await tester.pumpAndSettle();

    final scaffoldFinder = find.ancestor(
      of: find.byKey(const Key('television-navigation')),
      matching: find.byType(Scaffold),
    );
    final scaffold = tester.state<ScaffoldState>(scaffoldFinder.first);
    expect(scaffold.isDrawerOpen, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();

    expect(scaffold.isDrawerOpen, isTrue);
  });

  testWidgets('remote Back closes inline search before leaving the app', (
    tester,
  ) async {
    registerMusicCubits(music: FakeMusicLibraryRepository());
    final scope = await pumpApp(
      tester,
      televisionMode: true,
      viewportSize: const Size(1280, 720),
    );
    await scope.signIn();
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(InlineMusicSearch), findsOneWidget);

    final shellShortcuts = tester
        .widgetList<CallbackShortcuts>(find.byType(CallbackShortcuts))
        .singleWhere(
          (shortcuts) => shortcuts.bindings.containsKey(
            const SingleActivator(LogicalKeyboardKey.contextMenu),
          ),
        );
    shellShortcuts.bindings[const SingleActivator(
      LogicalKeyboardKey.goBack,
    )]!();
    await tester.pumpAndSettle();

    expect(find.byType(InlineMusicSearch), findsNothing);
    expect(find.byKey(const Key('television-navigation')), findsOneWidget);
  });

  testWidgets('remote media buttons control the shared playback queue', (
    tester,
  ) async {
    final engine = FakePlaybackEngine();
    final playback = fakePlaybackCubit(engine: engine);
    final scope = await pumpApp(
      tester,
      playback: playback,
      televisionMode: true,
      viewportSize: const Size(1280, 720),
    );
    await scope.signIn();
    await playback.playNow([
      Track(
        id: const MediaId(serverId: 'server', itemId: 'song'),
        name: 'Remote song',
        duration: const Duration(minutes: 3),
      ),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    expect(playback.state.isPlaying, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();
    expect(engine.calls, contains('pause'));

    engine.emitPosition(const Duration(seconds: 45));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaFastForward);
    await tester.pump();
    expect(engine.calls, contains('seek(0:00:55.000000)'));
  });
}
