import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackTargetLink.dart';
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
void registerDevicePickerCubit({
  required SessionCubit session,
  required PlaybackCubit playback,
  DevicePresenceSource? presence,
}) {
  final getIt = GetIt.instance;
  if (getIt.isRegistered<DevicePickerCubit>()) return;

  final effectivePresence = presence ?? FakeDevicePresenceSource();
  final transport = FakeConnectedPlaybackTransport(
    network: FakeConnectedPlaybackNetwork(),
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

  getIt.registerFactory<DevicePickerCubit>(
    () => DevicePickerCubit(effectivePresence, session, playback, handoff),
  );
  addTearDown(() async {
    await handoff.stop();
    getIt.reset();
  });
}
