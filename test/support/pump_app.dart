import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/JellyfinityApp.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/design/design.dart';

import 'session_fakes.dart';

/// Pumps the full app (router + themes + session) for navigation/shell
/// tests, wired to in-memory session fakes.
///
/// Returns the [TestSessionScope] so a test can seed storage or drive the
/// session (`scope.signIn()`, `scope.cubit.signOut()`, ...).
Future<TestSessionScope> pumpApp(
  WidgetTester tester, {
  TestSessionScope? scope,
}) async {
  final s = scope ?? TestSessionScope();
  addTearDown(s.cubit.close);
  registerAuthCubits(s);
  final router = AppRouter(s.cubit);
  await tester.pumpWidget(
    JellyfinityApp(router: router.config, session: s.cubit),
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
