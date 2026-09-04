import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/router/AppRouter.dart';
import 'package:jellyfinity/app/router/route_paths.dart';
import 'package:jellyfinity/features/auth/presentation/server_setup/server_setup_page.dart';
import 'package:jellyfinity/features/home/presentation/HomePage.dart';
import 'package:jellyfinity/features/onboarding/presentation/WelcomePage.dart';
import 'package:jellyfinity/features/shell/presentation/NotFoundPage.dart';
import 'package:jellyfinity/features/shell/presentation/SplashPage.dart';

import '../../support/pump_app.dart';
import '../../support/session_fakes.dart';

void main() {
  Future<(AppRouter, TestSessionScope)> pump(
    WidgetTester tester, {
    bool restore = true,
  }) async {
    final scope = TestSessionScope();
    final router = AppRouter(scope.cubit);
    await pumpApp(tester, scope: scope, router: router, restore: restore);
    return (router, scope);
  }

  testWidgets('unauthenticated is redirected to welcome from any location', (
    tester,
  ) async {
    final (router, _) = await pump(tester);

    router.config.go(RoutePaths.home);
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('an unauthenticated user may reach the connect flow', (
    tester,
  ) async {
    final (router, _) = await pump(tester);

    router.config.go(RoutePaths.connect);
    await tester.pumpAndSettle();

    expect(find.byType(ServerSetupPage), findsOneWidget);
  });

  testWidgets('authenticated is redirected off welcome to the shell', (
    tester,
  ) async {
    final (router, scope) = await pump(tester);
    await scope.signIn();
    await tester.pumpAndSettle();

    router.config.go(RoutePaths.welcome);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('completing sign-in from the connect flow lands in the shell', (
    tester,
  ) async {
    final (router, scope) = await pump(tester);

    router.config.go(RoutePaths.signIn, extra: fakeServerInfo());
    await tester.pumpAndSettle();

    await scope.signIn();
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('the router follows session changes with no manual navigation', (
    tester,
  ) async {
    final (_, scope) = await pump(tester);
    expect(find.byType(WelcomePage), findsOneWidget);

    await scope.signIn();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    await scope.cubit.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('an unmatched location shows the not-found page', (tester) async {
    final (router, scope) = await pump(tester);
    await scope.signIn();
    await tester.pumpAndSettle();

    router.config.go('/no/such/place');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundPage), findsOneWidget);
    expect(find.text('Go home'), findsOneWidget);
  });

  testWidgets('the app holds on the splash screen while a session restores', (
    tester,
  ) async {
    // Don't call restore(): the cubit stays in SessionStatus.unknown, the
    // startup "still restoring" window v0.0.5 produces for real.
    await pump(tester, restore: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
  });
}
