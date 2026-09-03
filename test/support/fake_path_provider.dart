import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Points `path_provider` at a throwaway temp directory for the duration of
/// one test, and removes it afterwards.
///
/// Needed by any test that runs `configureDependencies()`: from v0.0.6 the
/// DI graph opens the local database (ADR-0010), which resolves its file
/// location through `path_provider`'s platform channel.
void useFakePathProvider() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tempDir = Directory.systemTemp.createTempSync('jellyfinity_di_test_');
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        // Every path_provider getter returns the same scratch directory;
        // the tests here only care that it is a real, writable location.
        return tempDir.path;
      });

  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });
}
