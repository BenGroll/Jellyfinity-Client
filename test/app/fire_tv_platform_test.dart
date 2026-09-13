import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android manifest exposes one APK to mobile and TV launchers', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.intent.category.LEANBACK_LAUNCHER'));
    expect(
      manifest,
      contains(
        'android:name="android.software.leanback" android:required="false"',
      ),
    );
    expect(
      manifest,
      contains(
        'android:name="android.hardware.touchscreen" android:required="false"',
      ),
    );
    expect(
      manifest,
      contains(
        'android:name="android.hardware.faketouch" android:required="false"',
      ),
    );
    expect(manifest, contains('android:banner="@drawable/tv_banner"'));
  });

  test('TV launcher banner has the required 320 by 180 pixels', () async {
    final bytes = await File(
      'android/app/src/main/res/drawable-xhdpi/tv_banner.png',
    ).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    expect(frame.image.width, 320);
    expect(frame.image.height, 180);

    frame.image.dispose();
    codec.dispose();
  });

  test('Android host detects both standard TV mode and Fire TV', () {
    final activity = File(
      'android/app/src/main/kotlin/io/nachbar/jellyfinity/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, contains('UI_MODE_TYPE_TELEVISION'));
    expect(activity, contains('amazon.hardware.fire_tv'));
    expect(activity, contains('"isTelevision"'));
  });

  test(
    'Android host forwards display sleep/wake for connected-playback '
    'reconciliation (v0.5.9)',
    () {
      final activity = File(
        'android/app/src/main/kotlin/io/nachbar/jellyfinity/MainActivity.kt',
      ).readAsStringSync();

      expect(activity, contains('io.nachbar.jellyfinity/device/display'));
      expect(activity, contains('Intent.ACTION_SCREEN_ON'));
      expect(activity, contains('Intent.ACTION_SCREEN_OFF'));
      // Registered only while Dart is listening, not in the manifest —
      // these are protected broadcasts Android will not deliver to a
      // manifest-declared receiver.
      expect(activity, contains('registerReceiver(displayStateReceiver'));
      expect(activity, contains('unregisterReceiver(displayStateReceiver)'));
    },
  );

  test(
    'Android launch surface is dark and the adaptive icon expands its mark',
    () {
      final splash = File(
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ).readAsStringSync();
      final adaptiveIcon = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();
      final foreground = File(
        'android/app/src/main/res/drawable/ic_launcher_foreground_expanded.xml',
      ).readAsStringSync();

      expect(splash, contains('@color/splash_background'));
      expect(splash, contains('@mipmap/ic_launcher_foreground'));
      expect(
        adaptiveIcon,
        contains('@drawable/ic_launcher_foreground_expanded'),
      );
      expect(foreground, contains('android:insetLeft="-28dp"'));
    },
  );
}
