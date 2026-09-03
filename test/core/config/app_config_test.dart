import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('fromEnvironment defaults to development with no dart-define', () {
      final config = AppConfig.fromEnvironment();

      expect(config.environment, AppEnvironment.development);
      expect(config.isDevelopment, isTrue);
      expect(config.isProduction, isFalse);
    });

    test('isProduction is true only for the production environment', () {
      const config = AppConfig(environment: AppEnvironment.production);

      expect(config.isProduction, isTrue);
      expect(config.isDevelopment, isFalse);
    });
  });
}
