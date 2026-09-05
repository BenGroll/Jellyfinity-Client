import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/domain/playback/CrossfadeSettings.dart';

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

  testWidgets('turning crossfade on reveals the length control and updates '
      'the setting', (tester) async {
    final scope = TestSessionScope();
    final settings = fakeSettingsCubit();
    await pumpApp(tester, scope: scope, settings: settings);
    await scope.signIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byType(SwitchListTile), 200);
    await tester.pumpAndSettle();

    // Off by default, so there is nothing to set a length on yet.
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(settings.state.crossfade.enabled, isTrue);

    await tester.scrollUntilVisible(find.byType(Slider), 200);
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(
      find.text(
        'Crossfade length: ${CrossfadeSettings.defaultDuration.inSeconds}s',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.byType(SwitchListTile), -200);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(settings.state.crossfade.enabled, isFalse);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('the length slider persists one value when the drag ends', (
    tester,
  ) async {
    final scope = TestSessionScope();
    final settings = fakeSettingsCubit(
      crossfade: const CrossfadeSettings(
        enabled: true,
        duration: Duration(seconds: 2),
      ),
    );
    await pumpApp(tester, scope: scope, settings: settings);
    await scope.signIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byType(Slider), 200);
    await tester.pumpAndSettle();

    final states = <SettingsState>[];
    final sub = settings.stream.listen(states.add);
    addTearDown(sub.cancel);

    // Drag the thumb to the far right: the maximum supported length.
    await tester.drag(find.byType(Slider), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(settings.state.crossfade.duration, CrossfadeSettings.maximumDuration);
    // One write per adjustment, not one per pixel of the drag.
    expect(states, hasLength(1));
  });
}
