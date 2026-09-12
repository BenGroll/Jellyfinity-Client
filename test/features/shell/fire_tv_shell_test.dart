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
      tester.getRect(find.byKey(const Key('television-navigation'))).left,
      0,
    );
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

  testWidgets(
    'rail gives the remote a Search action and a way back to Browse',
    (tester) async {
      registerMusicCubits(music: FakeMusicLibraryRepository());
      final scope = await pumpApp(
        tester,
        televisionMode: true,
        viewportSize: const Size(1280, 720),
      );
      await scope.signIn();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('television-search')), findsOneWidget);
      expect(
        find.byKey(const Key('television-primary-navigation')),
        findsOneWidget,
      );

      // Home has initial focus. One step up reaches Search on the rail.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(InlineMusicSearch), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // The visible Browse control returns focus to the current rail section.
      await tester.tap(find.byKey(const Key('television-primary-navigation')));
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'TV current destination',
      );
    },
  );

  testWidgets('Up opens Search at Library’s top focus edge', (tester) async {
    registerMusicCubits(music: FakeMusicLibraryRepository());
    final scope = await pumpApp(
      tester,
      televisionMode: true,
      viewportSize: const Size(1280, 720),
    );
    await scope.signIn();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('television-destination-Library')),
    );
    await tester.pumpAndSettle();

    // The common Library header is at the shell's top focus edge.
    final search = tester.widget<InkWell>(
      find.byKey(const Key('shell-search')),
    );
    search.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.byType(InlineMusicSearch), findsOneWidget);
  });

  testWidgets('rail exposes and activates Now Playing for an active queue', (
    tester,
  ) async {
    final currentDestination = FocusNode();
    addTearDown(currentDestination.dispose);
    var openedNowPlaying = false;

    await pumpThemed(
      tester,
      Scaffold(
        body: SizedBox(
          height: 720,
          child: TelevisionNavigationRail(
            currentIndex: 0,
            currentDestinationFocusNode: currentDestination,
            hasNowPlaying: true,
            onSelected: (_) {},
            onMenu: () {},
            onSearch: () {},
            onNowPlaying: () => openedNowPlaying = true,
          ),
        ),
      ),
    );

    final action = find.byKey(const Key('television-now-playing'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(openedNowPlaying, isTrue);
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

  testWidgets('Up and Down leave the Now Playing timeline without seeking', (
    tester,
  ) async {
    final playback = fakePlaybackCubit();
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
        name: 'Timeline song',
        duration: const Duration(minutes: 3),
      ),
    ], startIndex: 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Timeline song'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    final sliderFocus = slider.focusNode!;
    sliderFocus.requestFocus();
    await tester.pump();
    final initialPosition = playback.state.position;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(sliderFocus.hasFocus, isFalse);
    expect(playback.state.position, initialPosition);

    // Prevent the active-playback timer from outliving the widget test.
    await playback.togglePlayPause();
  });
}
