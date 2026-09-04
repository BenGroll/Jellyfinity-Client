import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/app/settings/ShellNavigationMode.dart';

import '../../support/settings_fakes.dart';

void main() {
  test('defaults to mediaPills when nothing is stored', () async {
    final store = InMemoryKeyValueStore();

    final initial = await SettingsCubit.loadInitialNavigationMode(store);

    expect(initial, ShellNavigationMode.mediaPills);
  });

  test('loads a previously saved mode', () async {
    final store = InMemoryKeyValueStore();
    await store.setString('settings.navigationMode', 'unified');

    final initial = await SettingsCubit.loadInitialNavigationMode(store);

    expect(initial, ShellNavigationMode.unified);
  });

  test('ignores an unparseable saved value and falls back', () async {
    final store = InMemoryKeyValueStore();
    await store.setString('settings.navigationMode', 'not-a-real-mode');

    final initial = await SettingsCubit.loadInitialNavigationMode(store);

    expect(initial, ShellNavigationMode.mediaPills);
  });

  test('setNavigationMode persists and emits the new mode', () async {
    final store = InMemoryKeyValueStore();
    final cubit = SettingsCubit(store, ShellNavigationMode.mediaPills);
    addTearDown(cubit.close);

    await cubit.setNavigationMode(ShellNavigationMode.unified);

    expect(cubit.state.navigationMode, ShellNavigationMode.unified);
    expect(
      await SettingsCubit.loadInitialNavigationMode(store),
      ShellNavigationMode.unified,
    );
  });

  test('setNavigationMode to the current mode is a no-op', () async {
    final store = InMemoryKeyValueStore();
    final cubit = SettingsCubit(store, ShellNavigationMode.mediaPills);
    addTearDown(cubit.close);

    final states = <SettingsState>[];
    final sub = cubit.stream.listen(states.add);
    addTearDown(sub.cancel);

    await cubit.setNavigationMode(ShellNavigationMode.mediaPills);

    expect(states, isEmpty);
  });
}
