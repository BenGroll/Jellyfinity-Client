import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/downloads/DiskSpaceStorageProbe.dart';

import '../../support/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('jellyfinity/storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    useFakePathProvider();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'Windows probes the download volume and preserves 64-bit bytes',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'availableBytes');
        expect(call.arguments, contains('jellyfinity_di_test_'));
        return 7 * 1024 * 1024 * 1024;
      });
      expect(await DiskSpaceStorageProbe().availableBytes(), 7516192768);
    },
  );

  test('a failed Windows probe remains unknown rather than full', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'storage_unavailable');
    });
    expect(await DiskSpaceStorageProbe().availableBytes(), isNull);
  });
}
