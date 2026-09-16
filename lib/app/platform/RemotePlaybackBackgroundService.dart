import 'dart:io';

import 'package:flutter/services.dart';

/// Keeps the connected-playback process eligible for background execution on
/// Android while the app is acting as a remote target or controller.
abstract final class RemotePlaybackBackgroundService {
  static const MethodChannel _channel = MethodChannel(
    'io.nachbar.jellyfinity/device',
  );

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setRemotePlaybackService', enabled);
    } on MissingPluginException {
      // A host without the optional service integration remains usable; its
      // socket simply follows the platform's ordinary background policy.
    } on PlatformException {
      // Lifecycle transitions must never take down playback if the service
      // cannot be started.
    }
  }
}
