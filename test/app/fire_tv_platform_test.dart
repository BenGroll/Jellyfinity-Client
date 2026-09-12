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
}
