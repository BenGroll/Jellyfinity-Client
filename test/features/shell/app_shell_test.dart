import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/features/home/presentation/HomePage.dart';
import 'package:jellyfinity/features/music/presentation/search/InlineMusicSearch.dart';
import 'package:jellyfinity/features/shell/presentation/app_shell.dart';
import 'package:jellyfinity/features/shell/presentation/ShellDestination.dart';

import '../../support/pump_app.dart';
import '../../support/music_fakes.dart';

void main() {
  testWidgets('Ctrl+F opens search and Escape closes it', (tester) async {
    registerMusicCubits(music: FakeMusicLibraryRepository());
    final scope = await pumpApp(tester);
    await scope.signIn();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(InlineMusicSearch), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(InlineMusicSearch), findsNothing);
  });
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
    // Music section (renamed Library in v0.0.10, ADR-0014) is what makes
    // it appear. v0.3.4 (ADR-0028) added Favorites between them.
    expect(shellDestinations.map((d) => d.label), [
      'Home',
      'Favorites',
      'Library',
    ]);

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
