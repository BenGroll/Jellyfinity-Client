import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/app/settings/ShellNavigationMode.dart';
import 'package:jellyfinity/domain/playback/CrossfadeSettings.dart';
import 'package:jellyfinity/domain/playback/NormalizationSettings.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';

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
    final cubit = SettingsCubit(
      store,
      ShellNavigationMode.mediaPills,
      StreamQuality.original,
      StreamQuality.original,
      false,
      CrossfadeSettings.disabled,
      NormalizationSettings.disabled,
    );
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
    final cubit = SettingsCubit(
      store,
      ShellNavigationMode.mediaPills,
      StreamQuality.original,
      StreamQuality.original,
      false,
      CrossfadeSettings.disabled,
      NormalizationSettings.disabled,
    );
    addTearDown(cubit.close);

    final states = <SettingsState>[];
    final sub = cubit.stream.listen(states.add);
    addTearDown(sub.cancel);

    await cubit.setNavigationMode(ShellNavigationMode.mediaPills);

    expect(states, isEmpty);
  });

  test('defaults to original quality when nothing is stored', () async {
    final store = InMemoryKeyValueStore();

    final initial = await SettingsCubit.loadInitialStreamQuality(store);

    expect(initial, StreamQuality.original);
  });

  test('loads a previously saved quality', () async {
    final store = InMemoryKeyValueStore();
    await store.setString('settings.streamQuality', 'dataSaver');

    final initial = await SettingsCubit.loadInitialStreamQuality(store);

    expect(initial, StreamQuality.dataSaver);
  });

  test('ignores an unparseable saved quality and falls back', () async {
    final store = InMemoryKeyValueStore();
    await store.setString('settings.streamQuality', 'ultra-hd');

    final initial = await SettingsCubit.loadInitialStreamQuality(store);

    expect(initial, StreamQuality.original);
  });

  test('setStreamQuality persists and emits the new quality', () async {
    final store = InMemoryKeyValueStore();
    final cubit = SettingsCubit(
      store,
      ShellNavigationMode.mediaPills,
      StreamQuality.original,
      StreamQuality.original,
      false,
      CrossfadeSettings.disabled,
      NormalizationSettings.disabled,
    );
    addTearDown(cubit.close);

    await cubit.setStreamQuality(StreamQuality.high);

    expect(cubit.state.streamQuality, StreamQuality.high);
    expect(
      await SettingsCubit.loadInitialStreamQuality(store),
      StreamQuality.high,
    );
  });

  test('setStreamQuality to the current quality is a no-op', () async {
    final store = InMemoryKeyValueStore();
    final cubit = SettingsCubit(
      store,
      ShellNavigationMode.mediaPills,
      StreamQuality.original,
      StreamQuality.original,
      false,
      CrossfadeSettings.disabled,
      NormalizationSettings.disabled,
    );
    addTearDown(cubit.close);

    final states = <SettingsState>[];
    final sub = cubit.stream.listen(states.add);
    addTearDown(sub.cancel);

    await cubit.setStreamQuality(StreamQuality.original);

    expect(states, isEmpty);
  });

  group('crossfade', () {
    test(
      'defaults to off at the default duration when nothing is stored',
      () async {
        final store = InMemoryKeyValueStore();

        final initial = await SettingsCubit.loadInitialCrossfade(store);

        expect(initial, CrossfadeSettings.disabled);
        expect(initial.duration, CrossfadeSettings.defaultDuration);
      },
    );

    test('loads a previously saved enabled state and duration', () async {
      final store = InMemoryKeyValueStore();
      await store.setBool('settings.crossfadeEnabled', true);
      await store.setInt('settings.crossfadeSeconds', 8);

      final initial = await SettingsCubit.loadInitialCrossfade(store);

      expect(initial.enabled, isTrue);
      expect(initial.duration, const Duration(seconds: 8));
    });

    test('clamps a stored duration outside the supported range', () async {
      final store = InMemoryKeyValueStore();
      await store.setBool('settings.crossfadeEnabled', true);
      await store.setInt('settings.crossfadeSeconds', 600);

      final initial = await SettingsCubit.loadInitialCrossfade(store);

      // Still enabled: an unusable stored duration degrades to the
      // nearest supported one rather than turning the feature off.
      expect(initial.enabled, isTrue);
      expect(initial.duration, CrossfadeSettings.maximumDuration);
    });

    test(
      'a stored enabled state with no stored duration uses the default',
      () async {
        final store = InMemoryKeyValueStore();
        await store.setBool('settings.crossfadeEnabled', true);

        final initial = await SettingsCubit.loadInitialCrossfade(store);

        expect(initial.enabled, isTrue);
        expect(initial.duration, CrossfadeSettings.defaultDuration);
      },
    );

    test('setCrossfadeEnabled persists and emits', () async {
      final store = InMemoryKeyValueStore();
      final cubit = SettingsCubit(
        store,
        ShellNavigationMode.mediaPills,
        StreamQuality.original,
        StreamQuality.original,
        false,
        CrossfadeSettings.disabled,
        NormalizationSettings.disabled,
      );
      addTearDown(cubit.close);

      await cubit.setCrossfadeEnabled(true);

      expect(cubit.state.crossfade.enabled, isTrue);
      expect((await SettingsCubit.loadInitialCrossfade(store)).enabled, isTrue);
    });

    test('setCrossfadeDuration persists, emits, and clamps', () async {
      final store = InMemoryKeyValueStore();
      final cubit = SettingsCubit(
        store,
        ShellNavigationMode.mediaPills,
        StreamQuality.original,
        StreamQuality.original,
        false,
        CrossfadeSettings.disabled,
        NormalizationSettings.disabled,
      );
      addTearDown(cubit.close);

      await cubit.setCrossfadeDuration(const Duration(seconds: 9));
      expect(cubit.state.crossfade.duration, const Duration(seconds: 9));

      await cubit.setCrossfadeDuration(Duration.zero);
      expect(cubit.state.crossfade.duration, CrossfadeSettings.minimumDuration);

      final restored = await SettingsCubit.loadInitialCrossfade(store);
      expect(restored.duration, CrossfadeSettings.minimumDuration);
    });

    test(
      'a duration set while crossfade is off survives turning it on',
      () async {
        final store = InMemoryKeyValueStore();
        final cubit = SettingsCubit(
          store,
          ShellNavigationMode.mediaPills,
          StreamQuality.original,
          StreamQuality.original,
          false,
          CrossfadeSettings.disabled,
          NormalizationSettings.disabled,
        );
        addTearDown(cubit.close);

        await cubit.setCrossfadeDuration(const Duration(seconds: 10));
        await cubit.setCrossfadeEnabled(true);
        await cubit.setCrossfadeEnabled(false);
        await cubit.setCrossfadeEnabled(true);

        expect(
          await SettingsCubit.loadInitialCrossfade(store),
          const CrossfadeSettings(
            enabled: true,
            duration: Duration(seconds: 10),
          ),
        );
      },
    );

    test('setting the value already in state is a no-op', () async {
      final store = InMemoryKeyValueStore();
      final cubit = SettingsCubit(
        store,
        ShellNavigationMode.mediaPills,
        StreamQuality.original,
        StreamQuality.original,
        false,
        CrossfadeSettings.disabled,
        NormalizationSettings.disabled,
      );
      addTearDown(cubit.close);

      final states = <SettingsState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      await cubit.setCrossfadeEnabled(false);
      await cubit.setCrossfadeDuration(CrossfadeSettings.defaultDuration);

      expect(states, isEmpty);
    });
  });

  group('normalization', () {
    test('defaults to off when nothing is stored', () async {
      final store = InMemoryKeyValueStore();

      final initial = await SettingsCubit.loadInitialNormalization(store);

      expect(initial, NormalizationSettings.disabled);
    });

    test('loads a previously saved enabled state', () async {
      final store = InMemoryKeyValueStore();
      await store.setBool('settings.normalizationEnabled', true);

      final initial = await SettingsCubit.loadInitialNormalization(store);

      expect(initial.enabled, isTrue);
    });

    test('setNormalizationEnabled persists and emits', () async {
      final store = InMemoryKeyValueStore();
      final cubit = SettingsCubit(
        store,
        ShellNavigationMode.mediaPills,
        StreamQuality.original,
        StreamQuality.original,
        false,
        CrossfadeSettings.disabled,
        NormalizationSettings.disabled,
      );
      addTearDown(cubit.close);

      await cubit.setNormalizationEnabled(true);

      expect(cubit.state.normalization.enabled, isTrue);
      expect(
        (await SettingsCubit.loadInitialNormalization(store)).enabled,
        isTrue,
      );
    });

    test('setNormalizationEnabled to the current value is a no-op', () async {
      final store = InMemoryKeyValueStore();
      final cubit = SettingsCubit(
        store,
        ShellNavigationMode.mediaPills,
        StreamQuality.original,
        StreamQuality.original,
        false,
        CrossfadeSettings.disabled,
        NormalizationSettings.disabled,
      );
      addTearDown(cubit.close);

      final states = <SettingsState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      await cubit.setNormalizationEnabled(false);

      expect(states, isEmpty);
    });
  });

  group('download preferences (v0.2.2)', () {
    SettingsCubit build(InMemoryKeyValueStore store) {
      final cubit = SettingsCubit(
        store,
        ShellNavigationMode.mediaPills,
        StreamQuality.original,
        StreamQuality.original,
        false,
        CrossfadeSettings.disabled,
        NormalizationSettings.disabled,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('download quality defaults to lossless and is independent', () async {
      final store = InMemoryKeyValueStore();
      expect(
        await SettingsCubit.loadInitialDownloadQuality(store),
        StreamQuality.original,
      );

      final cubit = build(store);
      await cubit.setStreamQuality(StreamQuality.dataSaver);

      // Changing the streaming quality left the download quality alone.
      expect(cubit.state.downloadQuality, StreamQuality.original);
    });

    test('setDownloadQuality persists and emits', () async {
      final store = InMemoryKeyValueStore();
      final cubit = build(store);

      await cubit.setDownloadQuality(StreamQuality.high);

      expect(cubit.state.downloadQuality, StreamQuality.high);
      expect(
        await SettingsCubit.loadInitialDownloadQuality(store),
        StreamQuality.high,
      );
    });

    test('Wi-Fi-only defaults off and round-trips', () async {
      final store = InMemoryKeyValueStore();
      expect(await SettingsCubit.loadInitialDownloadsWifiOnly(store), isFalse);

      final cubit = build(store);
      await cubit.setDownloadsWifiOnly(true);

      expect(cubit.state.downloadsWifiOnly, isTrue);
      expect(await SettingsCubit.loadInitialDownloadsWifiOnly(store), isTrue);
    });

    test(
      'setting a download preference to its current value is a no-op',
      () async {
        final cubit = build(InMemoryKeyValueStore());
        final states = <SettingsState>[];
        final sub = cubit.stream.listen(states.add);
        addTearDown(sub.cancel);

        await cubit.setDownloadQuality(StreamQuality.original);
        await cubit.setDownloadsWifiOnly(false);

        expect(states, isEmpty);
      },
    );
  });
}
