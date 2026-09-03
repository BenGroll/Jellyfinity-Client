import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/app.dart';
import 'package:jellyfinity/app/router/app_router.dart';
import 'package:jellyfinity/app/router/route_paths.dart';
import 'package:jellyfinity/app/session/session_cubit.dart';
import 'package:jellyfinity/app/session/session_status.dart';
import 'package:jellyfinity/features/home/presentation/home_page.dart';
import 'package:jellyfinity/features/onboarding/presentation/welcome_page.dart';
import 'package:jellyfinity/features/shell/presentation/not_found_page.dart';
import 'package:jellyfinity/features/shell/presentation/splash_page.dart';

void main() {
  Future<AppRouter> pump(WidgetTester tester, SessionCubit session) async {
    addTearDown(session.close);
    final router = AppRouter(session);
    await tester.pumpWidget(
      JellyfinityApp(router: router.config, session: session),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('unauthenticated is redirected to welcome from any location', (
    tester,
  ) async {
    final router = await pump(tester, SessionCubit());

    router.config.go(RoutePaths.home);
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('authenticated is redirected off welcome to the shell', (
    tester,
  ) async {
    final session = SessionCubit()..signInForDevelopment();
    final router = await pump(tester, session);

    router.config.go(RoutePaths.welcome);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('the router follows session changes with no manual navigation', (
    tester,
  ) async {
    final session = SessionCubit();
    await pump(tester, session);
    expect(find.byType(WelcomePage), findsOneWidget);

    session.signInForDevelopment();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    session.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('an unmatched location shows the not-found page', (tester) async {
    final session = SessionCubit()..signInForDevelopment();
    final router = await pump(tester, session);

    router.config.go('/no/such/place');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundPage), findsOneWidget);
    expect(find.text('Go home'), findsOneWidget);
  });

  testWidgets('an unknown session status is held on the splash screen', (
    tester,
  ) async {
    final session = _UnknownSession();
    addTearDown(session.close);
    final router = AppRouter(session);
    await tester.pumpWidget(
      JellyfinityApp(router: router.config, session: session),
    );
    // The splash spinner animates forever, so pump a few frames rather than
    // settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
  });
}

/// A session stuck in [SessionStatus.unknown] — the startup "still
/// restoring" window that v0.0.5 will produce for real.
class _UnknownSession extends SessionCubit {
  @override
  SessionStatus get state => SessionStatus.unknown;
}
