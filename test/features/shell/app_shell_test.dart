import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/home/presentation/home_page.dart';
import 'package:jellyfinity/features/shell/presentation/app_shell.dart';
import 'package:jellyfinity/features/shell/presentation/shell_destination.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('the shell wraps the authenticated section', (tester) async {
    final session = await pumpApp(tester);
    session.signInForDevelopment();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('with a single destination no navigation bar is shown', (
    tester,
  ) async {
    // Guards the "don't build empty future sections" decision: the bar only
    // appears once a second section is actually added.
    expect(shellDestinations, hasLength(1));

    final session = await pumpApp(tester);
    session.signInForDevelopment();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
  });
}
