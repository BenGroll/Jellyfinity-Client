import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/downloads/DownloadsCubit.dart';
import 'package:jellyfinity/app/JellyfinityApp.dart';
import 'package:jellyfinity/app/navigation/MediaScopeCubit.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/design/design.dart';
import 'package:jellyfinity/domain/playback/LyricsResolver.dart';
import 'package:jellyfinity/domain/playback/TrackSourceInfoResolver.dart';

import 'download_fakes.dart';
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
/// hint (ADR-0015) shows; otherwise it stays hidden. Pass [lyricsResolver] to
/// control what the Lyrics view (v0.1.5) shows; otherwise it has none. Pass
/// [downloads] to drive or assert on the download system (v0.2.0);
/// otherwise a fake-backed cubit is built so track rows and album
/// headers have download state to read.
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
  DownloadsCubit? downloads,
  TrackSourceInfoResolver? trackSourceInfoResolver,
  LyricsResolver? lyricsResolver,
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
  final downloadsCubit = downloads ?? fakeDownloadsCubit();
  addTearDown(downloadsCubit.close);
  // NowPlayingPage is a root route the router builds with no constructor
  // args, reading TrackSourceInfoCubit straight from getIt — reachable
  // from every pumpApp test via the mini-player, so this is registered
  // unconditionally rather than only by tests that specifically care
  // about it (mirrors registerMusicCubits for the music detail cubits).
  registerTrackSourceInfoCubit(resolver: trackSourceInfoResolver);
  // LyricsPage is the same shape — a root route reading LyricsCubit
  // straight from getIt, reachable from every pumpApp test via Now
  // Playing's lyrics button.
  registerLyricsCubit(resolver: lyricsResolver);
  // Now Playing's favorite heart and artist/album links (v0.1.6) read
  // these straight from getIt too.
  registerNowPlayingDetailsCubit();
  registerFavoritesRepository();
  await tester.pumpWidget(
    JellyfinityApp(
      router: effectiveRouter.config,
      session: s.cubit,
      playback: playbackCubit,
      settings: settingsCubit,
      mediaScope: mediaScopeCubit,
      downloads: downloadsCubit,
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
///
/// [SessionCubit] and [DownloadsCubit] are provided unconditionally, for
/// the same reason `JellyfinityApp` provides them at the root: they are
/// cross-cutting app state that ordinary widgets (a track row's download
/// control, for one) read wherever they are shown. Pass [downloads] when
/// a test drives or asserts on download state.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  SessionCubit? session,
  DownloadsCubit? downloads,
}) async {
  final s = session ?? TestSessionScope().cubit;
  addTearDown(s.close);
  final downloadsCubit = downloads ?? fakeDownloadsCubit();
  addTearDown(downloadsCubit.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<SessionCubit>.value(value: s),
        BlocProvider<DownloadsCubit>.value(value: downloadsCubit),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: child),
      ),
    ),
  );
}
