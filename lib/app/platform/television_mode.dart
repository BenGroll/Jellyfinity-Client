import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android-host capability used to select Jellyfinity's 10-foot UI.
///
/// The host checks the device UI mode rather than guessing from screen size:
/// large Android tablets and desktop windows must keep their ordinary layouts.
abstract final class TelevisionModeDetector {
  static const MethodChannel _channel = MethodChannel(
    'io.nachbar.jellyfinity/device',
  );

  static Future<bool> detect() async {
    try {
      return await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Carries the host's form factor without coupling feature widgets to a method
/// channel or to Android APIs.
class TelevisionModeScope extends InheritedWidget {
  const TelevisionModeScope({
    super.key,
    required this.isTelevision,
    required super.child,
  });

  final bool isTelevision;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TelevisionModeScope>()
          ?.isTelevision ??
      false;

  @override
  bool updateShouldNotify(TelevisionModeScope oldWidget) =>
      isTelevision != oldWidget.isTelevision;
}
