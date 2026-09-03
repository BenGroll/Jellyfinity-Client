import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/di/service_locator.dart';
import 'package:jellyfinity/core/logging/logger.dart';

void main() {
  group('configureDependencies', () {
    tearDown(() async {
      await getIt.reset();
    });

    test('registers a resolvable Logger', () async {
      await configureDependencies();

      expect(getIt.isRegistered<Logger>(), isTrue);
      expect(getIt<Logger>(), isA<Logger>());
    });

    test('resolves the same lazy singleton on repeated lookups', () async {
      await configureDependencies();

      expect(identical(getIt<Logger>(), getIt<Logger>()), isTrue);
    });
  });
}
