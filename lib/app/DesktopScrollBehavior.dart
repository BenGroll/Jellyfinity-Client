import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets mouse users drag the horizontal shelves as well as use a trackpad
/// or Shift + wheel. Keep Flutter's platform scrollbars and keyboard scrolling.
class DesktopScrollBehavior extends MaterialScrollBehavior {
  const DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
