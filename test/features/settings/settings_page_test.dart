import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';
import '../../support/session_fakes.dart';
import '../../support/settings_fakes.dart';

void main() {
  testWidgets('selecting Unified switches the navigation mode', (tester) async {
    final scope = TestSessionScope();
    final s = await pumpApp(
      tester,
      scope: scope,
      settings: fakeSettingsCubit(),
    );
    await s.signIn();
    await tester.pumpAndSettle();

    // Starts in the default mode, so the pill row is up.
    expect(find.widgetWithText(ChoiceChip, 'Music'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unified'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // The pill row is gone from the shell now that Unified is active.
    expect(find.widgetWithText(ChoiceChip, 'Music'), findsNothing);
  });
}
