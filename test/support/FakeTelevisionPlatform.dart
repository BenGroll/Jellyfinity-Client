import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stubs the Android host's television-detection method channel and
/// display-power event channel — what `TelevisionModeDetector` and
/// `TelevisionDisplayMonitor` talk to — so a test can drive a television's
/// sleep/wake transitions without a device (v0.5.9).
///
/// Install in `setUp` and [dispose] in `tearDown`; the real channels stay
/// unstubbed for every other test, which is what keeps them exercising the
/// "no host answers" fallback both detectors already have.
class FakeTelevisionPlatform {
  FakeTelevisionPlatform() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _deviceChannel,
          (call) async => call.method == 'isTelevision' ? true : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          _displayChannel,
          MockStreamHandler.inline(
            onListen: (arguments, events) => _sink = events,
            onCancel: (arguments) => _sink = null,
          ),
        );
  }

  static const MethodChannel _deviceChannel = MethodChannel(
    'io.nachbar.jellyfinity/device',
  );
  static const EventChannel _displayChannel = EventChannel(
    'io.nachbar.jellyfinity/device/display',
  );

  MockStreamHandlerEventSink? _sink;

  void screenOn() => _sink?.success(true);
  void screenOff() => _sink?.success(false);

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_deviceChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(_displayChannel, null);
  }
}
