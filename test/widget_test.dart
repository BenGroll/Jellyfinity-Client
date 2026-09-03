import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/home/presentation/home_page.dart';
import 'package:jellyfinity/features/onboarding/presentation/welcome_page.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('an unauthenticated launch lands on the welcome screen', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('continuing from welcome enters the app shell', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
  });

  testWidgets('signing out from home returns to welcome', (tester) async {
    final session = await pumpApp(tester);
    session.signInForDevelopment();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsOneWidget);
  });
}
