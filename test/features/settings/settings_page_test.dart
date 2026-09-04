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

  testWidgets('selecting a streaming quality updates the selected option', (
    tester,
  ) async {
    final scope = TestSessionScope();
    await pumpApp(tester, scope: scope, settings: fakeSettingsCubit());
    await scope.signIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Starts on Lossless — the default quality (StreamQuality.original).
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Lossless'),
        matching: find.byIcon(Icons.radio_button_checked_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'High'),
        matching: find.byIcon(Icons.radio_button_checked_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Lossless'),
        matching: find.byIcon(Icons.radio_button_checked_rounded),
      ),
      findsNothing,
    );
  });
}
