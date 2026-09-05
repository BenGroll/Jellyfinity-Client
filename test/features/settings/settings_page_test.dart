import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/domain/playback/CrossfadeSettings.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';

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

  testWidgets('selecting a streaming quality from the dropdown updates the '
      'description shown beneath it', (tester) async {
    final scope = TestSessionScope();
    await pumpApp(tester, scope: scope, settings: fakeSettingsCubit());
    await scope.signIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // The streaming-quality dropdown is the first of the two
    // StreamQuality dropdowns on the screen (the second is the v0.2.2
    // download-quality one).
    final streamingDropdown = find.byType(DropdownButton<StreamQuality>).first;

    // Starts on Lossless — the default quality (StreamQuality.original).
    expect(
      find.descendant(of: streamingDropdown, matching: find.text('Lossless')),
      findsOneWidget,
    );
    expect(
      find.text(
        'The original file, exactly as stored on your server. No '
        'transcoding, largest downloads.',
      ),
      findsOneWidget,
    );

    await tester.tap(streamingDropdown);
    await tester.pumpAndSettle();
    // Two "High" texts now exist: the closed field and the open menu
    // item: The menu entry is the last one added to the tree.
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: streamingDropdown, matching: find.text('High')),
      findsOneWidget,
    );
    expect(
      find.text('Transcodes to AAC at 320 kbps when needed.'),
      findsOneWidget,
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

    final crossfadeSwitch = find.widgetWithText(SwitchListTile, 'Crossfade');
    await tester.scrollUntilVisible(crossfadeSwitch, 200);
    await tester.pumpAndSettle();

    // Off by default, so there is nothing to set a length on yet.
    expect(find.byType(Slider), findsNothing);

    await tester.tap(crossfadeSwitch);
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

    await tester.scrollUntilVisible(crossfadeSwitch, -200);
    await tester.pumpAndSettle();
    await tester.tap(crossfadeSwitch);
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

    expect(
      settings.state.crossfade.duration,
      CrossfadeSettings.maximumDuration,
    );
    // One write per adjustment, not one per pixel of the drag.
    expect(states, hasLength(1));
  });

  testWidgets('turning volume normalization on updates the setting', (
    tester,
  ) async {
    final scope = TestSessionScope();
    final settings = fakeSettingsCubit();
    await pumpApp(tester, scope: scope, settings: settings);
    await scope.signIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final normalizationSwitch = find.widgetWithText(
      SwitchListTile,
      'Volume normalization',
    );
    await tester.scrollUntilVisible(normalizationSwitch, 200);
    await tester.pumpAndSettle();

    expect(settings.state.normalization.enabled, isFalse);

    await tester.tap(normalizationSwitch);
    await tester.pumpAndSettle();

    expect(settings.state.normalization.enabled, isTrue);
  });

  testWidgets('turning on Wi-Fi-only downloads updates the setting (v0.2.2)', (
    tester,
  ) async {
    final scope = TestSessionScope();
    final settings = fakeSettingsCubit();
    await pumpApp(tester, scope: scope, settings: settings);
    await scope.signIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final wifiSwitch = find.widgetWithText(
      SwitchListTile,
      'Download on Wi-Fi only',
    );
    await tester.scrollUntilVisible(wifiSwitch, 200);
    await tester.pumpAndSettle();

    expect(settings.state.downloadsWifiOnly, isFalse);

    await tester.tap(wifiSwitch);
    await tester.pumpAndSettle();

    expect(settings.state.downloadsWifiOnly, isTrue);
  });
}
