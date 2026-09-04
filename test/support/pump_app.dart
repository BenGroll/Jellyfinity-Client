import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/JellyfinityApp.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/design/design.dart';

import 'playback_fakes.dart';
import 'session_fakes.dart';

/// Pumps the full app (router + themes + session + playback) for
/// navigation/shell tests, wired to in-memory fakes throughout.
///
/// Returns the [TestSessionScope] so a test can seed storage or drive the
/// session (`scope.signIn()`, `scope.cubit.signOut()`, ...). Pass
/// [playback] when a test needs to drive or assert on playback itself;
/// otherwise a fake-backed cubit is built so the shell's mini-player has
/// something to read.
Future<TestSessionScope> pumpApp(
  WidgetTester tester, {
  TestSessionScope? scope,
  PlaybackCubit? playback,
}) async {
  final s = scope ?? TestSessionScope();
  addTearDown(s.cubit.close);
  registerAuthCubits(s);
  final router = AppRouter(s.cubit);
  final playbackCubit = playback ?? fakePlaybackCubit();
  addTearDown(playbackCubit.close);
  await tester.pumpWidget(
    JellyfinityApp(
      router: router.config,
      session: s.cubit,
      playback: playbackCubit,
    ),
  );
  await s.cubit.restore();
  await tester.pumpAndSettle();
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
