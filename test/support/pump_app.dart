import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/JellyfinityApp.dart';
import 'package:jellyfinity/app/navigation/MediaScopeCubit.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/design/design.dart';
import 'package:jellyfinity/domain/playback/TrackSourceInfoResolver.dart';

import 'playback_fakes.dart';
import 'session_fakes.dart';
import 'settings_fakes.dart';

/// Pumps the full app (router + themes + session + playback + settings)
/// for navigation/shell tests, wired to in-memory fakes throughout.
///
/// Returns the [TestSessionScope] so a test can seed storage or drive the
/// session (`scope.signIn()`, `scope.cubit.signOut()`, ...). Pass
/// [playback]/[settings]/[mediaScope] when a test needs to drive or assert
/// on one of them directly; otherwise fake-backed cubits are built so the
/// shell (mini-player, header, sidebar) has something to read. Pass
/// [trackSourceInfoResolver] to control what Now Playing's source-quality
/// hint (ADR-0015) shows; otherwise it stays hidden.
///
/// [restore] defaults to `true` (the ordinary post-sign-in-restore state
/// every other test wants); pass `false` for a test that specifically
/// exercises the startup window before a saved session has been read
/// (`SessionStatus.unknown`, the splash screen).
///
/// Pass [router] when a test needs to drive navigation directly
/// (`router.config.go(...)`) — build it from the same `scope.cubit` and
/// hand it in, so the instance under test is the one actually wired into
/// the pumped widget tree rather than an unrelated duplicate.
Future<TestSessionScope> pumpApp(
  WidgetTester tester, {
  TestSessionScope? scope,
  AppRouter? router,
  PlaybackCubit? playback,
  SettingsCubit? settings,
  MediaScopeCubit? mediaScope,
  TrackSourceInfoResolver? trackSourceInfoResolver,
  bool restore = true,
}) async {
  // The default flutter_test surface (800x600, wider than tall) has too
  // little height for a real phone screen once the persistent header
  // (search + pills), mini-player and bottom nav are all present —
  // enough to leave a deep-navigation row geometrically off the visible
  // area even though `find` still locates it, producing a `tap()` that
  // silently lands on the wrong widget. A realistic phone viewport is
  // what every one of these screens is actually built for.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final s = scope ?? TestSessionScope();
  addTearDown(s.cubit.close);
  registerAuthCubits(s);
  final effectiveRouter = router ?? AppRouter(s.cubit);
  final playbackCubit = playback ?? fakePlaybackCubit();
  addTearDown(playbackCubit.close);
  final settingsCubit = settings ?? fakeSettingsCubit();
  addTearDown(settingsCubit.close);
  final mediaScopeCubit = mediaScope ?? fakeMediaScopeCubit();
  addTearDown(mediaScopeCubit.close);
  // NowPlayingPage is a root route the router builds with no constructor
  // args, reading TrackSourceInfoCubit straight from getIt — reachable
  // from every pumpApp test via the mini-player, so this is registered
  // unconditionally rather than only by tests that specifically care
  // about it (mirrors registerMusicCubits for the music detail cubits).
  registerTrackSourceInfoCubit(resolver: trackSourceInfoResolver);
  await tester.pumpWidget(
    JellyfinityApp(
      router: effectiveRouter.config,
      session: s.cubit,
      playback: playbackCubit,
      settings: settingsCubit,
      mediaScope: mediaScopeCubit,
    ),
  );
  if (restore) {
    await s.cubit.restore();
    await tester.pumpAndSettle();
  }
  return s;
}

/// Pumps a single widget inside the real [AppTheme] (dark) so
/// `context.tokens` resolves. Use for isolated design-component tests.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  SessionCubit? session,
}) async {
  final s = session ?? TestSessionScope().cubit;
  addTearDown(s.close);
  await tester.pumpWidget(
    BlocProvider<SessionCubit>.value(
      value: s,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: child),
      ),
    ),
  );
}
