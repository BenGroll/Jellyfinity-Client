import 'package:injectable/injectable.dart';

import '../../domain/connected_playback/ConnectedDevice.dart';
import '../../domain/connected_playback/RemotePlaybackOwnership.dart';
import 'PlaybackControlCubit.dart';

/// The app layer's implementation of [RemotePlaybackOwnership] (v0.6.0),
/// the same seam-over-a-cubit pattern `ActivePlaybackRouteAdapter`
/// already uses for `ActiveTransportRoute`: `PlaybackCubit` gets a
/// narrow, testable fact about `PlaybackControlCubit` without depending
/// on it directly.
@LazySingleton(as: RemotePlaybackOwnership)
class PlaybackControlOwnership implements RemotePlaybackOwnership {
  PlaybackControlOwnership(this._control);

  final PlaybackControlCubit _control;

  @override
  ConnectedDevice? get controlledDevice => _control.state.device;

  @override
  Future<void> releaseForTakeover() async {
    if (!_control.state.isControlling) return;
    // Best-effort — see this method's own domain doc. A target that
    // refuses or never answers the pause must not stop this device from
    // still detaching and starting local playback right after.
    await _control.pause();
    await _control.stop();
  }
}
