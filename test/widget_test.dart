import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/home/presentation/HomePage.dart';
import 'package:jellyfinity/features/onboarding/presentation/WelcomePage.dart';

import 'support/pump_app.dart';
import 'support/session_fakes.dart';

void main() {
  testWidgets('an unauthenticated launch lands on the welcome screen', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('a restored session lands straight in the app shell', (
    tester,
  ) async {
    final scope = TestSessionScope();
    await scope.signIn();
    await pumpApp(tester, scope: scope);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
  });

  testWidgets('signing out returns to welcome', (tester) async {
    final scope = await pumpApp(tester);
    await scope.signIn();
    await tester.pumpAndSettle();

    await scope.cubit.signOut();
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsOneWidget);
  });
}
