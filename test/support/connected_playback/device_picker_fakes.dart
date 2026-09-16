import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackTargetLink.dart';
import 'package:jellyfinity/app/connected_playback/PlaybackControlCubit.dart';
import 'package:jellyfinity/app/connected_playback/SyncPlayGroupCubit.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/domain/connected_playback/DevicePresenceSource.dart';
import 'package:jellyfinity/features/playback/presentation/device_picker_cubit.dart';

import '../TestLogger.dart';
import '../music_fakes.dart';
import 'connected_playback_fixtures.dart';
import 'FakeConnectedPlaybackNetwork.dart';
import 'FakeConnectedPlaybackTransport.dart';
import 'FakeDevicePresenceSource.dart';
import 'FakeSyncPlayTransport.dart';

/// Registers a fake [DevicePickerCubit] factory into the real `getIt` —
/// the same shape as `registerNowPlayingDetailsCubit` — because
/// [MiniPlayer]/[NowPlayingPage] now build a `DeviceActionButton` that
/// reads it straight from `getIt` (v0.5.5). [pumpApp] calls this
/// unconditionally so every existing mini-player/Now Playing test keeps
/// working without knowing connected playback exists.
///
/// [presence] defaults to a [FakeDevicePresenceSource] nothing ever
/// emits on — an empty, idle device list, the state a test that does not
/// care about connected playback should see. A [ConnectedPlaybackTargetLink]
/// is always built fresh, wired to [playback] and [session] so its
/// `localSnapshot` genuinely reflects them; it needs its own throwaway
/// transport and library only because its constructor does, not because
/// any test here exercises a transfer over them.
///
/// [network] defaults to a fresh [FakeConnectedPlaybackNetwork] this
/// device's transport is the only node on. Pass the same network a test
/// also builds a second (fake "TV") node on — matching this device's own
/// session id, `'test-device'`, in that node's `watchers` — to exercise
/// controlling another device (v0.5.6) through the real widget tree.
void registerDevicePickerCubit({
  required SessionCubit session,
  required PlaybackCubit playback,
  DevicePresenceSource? presence,
  FakeConnectedPlaybackNetwork? network,
}) {
  final getIt = GetIt.instance;
  if (getIt.isRegistered<DevicePickerCubit>()) return;

  final effectivePresence = presence ?? FakeDevicePresenceSource();
  final transport = FakeConnectedPlaybackTransport(
    network: network ?? FakeConnectedPlaybackNetwork(),
    sessionId: 'test-device',
    scope: testScope,
  );
  final handoff = ConnectedPlaybackTargetLink(
    playback,
    transport,
    session,
    FakeMusicLibraryRepository(),
    TestLogger(),
  );
  unawaited(handoff.start());

  // A true (lazy) singleton, mirroring the real `@lazySingleton`: MiniPlayer,
  // NowPlayingPage and QueuePage (v0.5.6) each resolve this straight from
  // `getIt` too, and all of them must share the one instance the picker
  // chooses a device through.
  getIt.registerLazySingleton<PlaybackControlCubit>(
    () => PlaybackControlCubit(transport, effectivePresence, session),
  );
  getIt.registerFactory<DevicePickerCubit>(
    () => DevicePickerCubit(
      effectivePresence,
      session,
      playback,
      handoff,
      getIt<PlaybackControlCubit>(),
      getIt<SyncPlayGroupCubit>(),
    ),
  );
  addTearDown(() async {
    await handoff.stop();
    if (getIt.isRegistered<PlaybackControlCubit>()) {
      await getIt<PlaybackControlCubit>().close();
    }
    getIt.reset();
  });
}

/// Registers a fake [SyncPlayGroupCubit] into the real `getIt` — the
/// Remote destination (v0.6.0) reads it straight from `getIt`, the same
/// convention [registerDevicePickerCubit] follows for `DevicePickerCubit`.
/// [transport] defaults to a fresh [FakeSyncPlayTransport] nothing ever
/// pushes an update on — a group-free Remote destination, the state a
/// test that does not care about group playback should see.
FakeSyncPlayTransport registerSyncPlayGroupCubit({
  required SessionCubit session,
  required PlaybackCubit playback,
  FakeSyncPlayTransport? transport,
  FakeMusicLibraryRepository? library,
}) {
  final getIt = GetIt.instance;
  final effectiveTransport = transport ?? FakeSyncPlayTransport();
  if (getIt.isRegistered<SyncPlayGroupCubit>()) return effectiveTransport;

  getIt.registerLazySingleton<SyncPlayGroupCubit>(
    () => SyncPlayGroupCubit(
      effectiveTransport,
      playback,
      library ?? FakeMusicLibraryRepository(),
      session,
    ),
  );
  addTearDown(() async {
    if (getIt.isRegistered<SyncPlayGroupCubit>()) {
      await getIt<SyncPlayGroupCubit>().close();
    }
    await effectiveTransport.dispose();
  });
  return effectiveTransport;
}
