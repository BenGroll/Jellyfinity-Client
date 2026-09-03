import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/app.dart';
import 'package:jellyfinity/app/router/app_router.dart';
import 'package:jellyfinity/app/session/session_cubit.dart';
import 'package:jellyfinity/design/design.dart';

/// Pumps the full app (router + themes + session) for navigation/shell
/// tests. Returns the [SessionCubit] so a test can drive session state.
Future<SessionCubit> pumpApp(
  WidgetTester tester, {
  SessionCubit? session,
}) async {
  final s = session ?? SessionCubit();
  addTearDown(s.close);
  final router = AppRouter(s);
  await tester.pumpWidget(JellyfinityApp(router: router.config, session: s));
  await tester.pumpAndSettle();
  return s;
}

/// Pumps a single widget inside the real [AppTheme] (dark) so `context.tokens`
/// resolves. Use for isolated design-component tests.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  SessionCubit? session,
}) async {
  final s = session ?? SessionCubit();
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
