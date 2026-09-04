import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/home/presentation/HomePage.dart';
import 'package:jellyfinity/features/shell/presentation/app_shell.dart';
import 'package:jellyfinity/features/shell/presentation/ShellDestination.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('the shell wraps the authenticated section', (tester) async {
    final scope = await pumpApp(tester);
    await scope.signIn();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('shows a navigation bar once there is a second section', (
    tester,
  ) async {
    // v0.0.3 shipped Home alone and deliberately hid the bar; v0.0.8's
    // Music section is what makes it appear.
    expect(shellDestinations.map((d) => d.label), ['Home', 'Music']);

    final scope = await pumpApp(tester);
    await scope.signIn();
    await tester.pumpAndSettle();

    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    for (final destination in shellDestinations) {
      expect(
        find.descendant(of: bar, matching: find.text(destination.label)),
        findsOneWidget,
      );
    }
  });
}
