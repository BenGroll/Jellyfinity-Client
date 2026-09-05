import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connectivity/OfflineCubit.dart';
import 'package:jellyfinity/features/shell/presentation/AppSidebar.dart';

import '../../support/offline_fakes.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('the Work offline switch reflects and drives the offline mode', (
    tester,
  ) async {
    final offline = fakeOfflineCubit();
    addTearDown(offline.close);

    await pumpThemed(tester, const AppSidebar(), offline: offline);
    await tester.pumpAndSettle();

    final switchFinder = find.widgetWithText(SwitchListTile, 'Work offline');
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(offline.state.isOffline, isTrue);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
  });

  testWidgets('with no connection the switch is on and cannot be changed', (
    tester,
  ) async {
    final mode = FakeOfflineMode(connected: false);
    final offline = OfflineCubit(mode);
    addTearDown(offline.close);
    addTearDown(mode.dispose);

    await pumpThemed(tester, const AppSidebar(), offline: offline);
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Work offline'),
    );
    expect(tile.value, isTrue);
    expect(tile.onChanged, isNull);
    expect(find.textContaining('No connection'), findsOneWidget);
  });
}
