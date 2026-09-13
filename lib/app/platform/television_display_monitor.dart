import 'package:flutter/services.dart';

/// Reports the Android host's display power state.
///
/// Television standby does not reliably pause the Flutter `Activity` the
/// way backgrounding a phone does — the app can stay `resumed` with the
/// screen simply dark — so `AppLifecycleState` alone cannot see a
/// television going to sleep. The host forwards `ACTION_SCREEN_ON`/
/// `ACTION_SCREEN_OFF` instead, which `ConnectedPlaybackLink` reconciles
/// against so an asleep television expires promptly as a connected-
/// playback target (v0.5.9).
///
/// A missing or failing host just never emits: callers only ever hear
/// about a real display transition, never a synthesized one.
abstract final class TelevisionDisplayMonitor {
  static const EventChannel _channel = EventChannel(
    'io.nachbar.jellyfinity/device/display',
  );

  static Stream<bool> get screenOnChanges => _channel
      .receiveBroadcastStream()
      .cast<bool>()
      .handleError(
        (Object _) {},
        test: (error) =>
            error is MissingPluginException || error is PlatformException,
      );
}
