import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/connectivity/PersistedOfflineMode.dart';

import '../../support/download_fakes.dart';
import '../../support/settings_fakes.dart';

void main() {
  test('starts online, then restores the saved switch and the connection', () async {
    final store = InMemoryKeyValueStore();
    await store.setBool('offline.manual', true);
    final network = FakeNetworkCondition(state: NetworkState.unmetered);

    final mode = PersistedOfflineMode(network, store);
    addTearDown(mode.dispose);

    // Optimistic seed before the async restore lands.
    expect(mode.status.isOffline, isFalse);

    await Future<void>.delayed(Duration.zero);
    expect(mode.status.isManual, isTrue);
    expect(mode.status.isConnected, isTrue);
    expect(mode.status.isOffline, isTrue);
  });

  test('losing the connection forces offline and is announced', () async {
    final network = FakeNetworkCondition(state: NetworkState.unmetered);
    final mode = PersistedOfflineMode(network, InMemoryKeyValueStore());
    addTearDown(mode.dispose);
    await Future<void>.delayed(Duration.zero);

    final seen = <bool>[];
    final sub = mode.changes().listen((s) => seen.add(s.isOffline));
    addTearDown(sub.cancel);

    network.moveTo(NetworkState.none);
    await Future<void>.delayed(Duration.zero);

    expect(mode.status.isOffline, isTrue);
    expect(mode.status.isForcedByConnection, isTrue);
    expect(seen, contains(true));
  });

  test('setManual persists across a rebuild', () async {
    final store = InMemoryKeyValueStore();
    final network = FakeNetworkCondition();

    final first = PersistedOfflineMode(network, store);
    await Future<void>.delayed(Duration.zero);
    await first.setManual(true);
    first.dispose();

    final second = PersistedOfflineMode(network, store);
    addTearDown(second.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(second.status.isManual, isTrue);
  });
}
