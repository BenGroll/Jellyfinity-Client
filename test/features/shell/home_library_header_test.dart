import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/settings/ShellNavigationMode.dart';
import 'package:jellyfinity/features/auth/presentation/accounts/accounts_page.dart';
import 'package:jellyfinity/features/settings/presentation/SettingsPage.dart';

import '../../support/pump_app.dart';
import '../../support/settings_fakes.dart';
import '../../support/session_fakes.dart';

void main() {
  testWidgets('the media pill row shows in mediaPills mode', (tester) async {
    final scope = TestSessionScope();
    final s = await pumpApp(
      tester,
      scope: scope,
      settings: fakeSettingsCubit(mode: ShellNavigationMode.mediaPills),
    );
    await s.signIn();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Music'), findsOneWidget);
  });

  testWidgets('the media pill row is absent in unified mode', (tester) async {
    final scope = TestSessionScope();
    final s = await pumpApp(
      tester,
      scope: scope,
      settings: fakeSettingsCubit(mode: ShellNavigationMode.unified),
    );
    await s.signIn();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Music'), findsNothing);
  });

  testWidgets('the menu button opens the sidebar', (tester) async {
    final scope = TestSessionScope();
    final s = await pumpApp(tester, scope: scope);
    await s.signIn();
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('the sidebar leads to Accounts and Settings', (tester) async {
    final scope = TestSessionScope();
    final s = await pumpApp(tester, scope: scope);
    await s.signIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountsPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
