import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/PublicSystemInfoDto.dart';

void main() {
  group('PublicSystemInfoDto.fromJson', () {
    test('reads a full Jellyfin public-info payload', () {
      final dto = PublicSystemInfoDto.fromJson(const {
        'LocalAddress': 'http://192.168.1.5:8096',
        'ServerName': 'Home Media',
        'Version': '10.11.6',
        'ProductName': 'Jellyfin Server',
        'Id': 'a1b2c3',
        'StartupWizardCompleted': true,
      });

      expect(dto.serverName, 'Home Media');
      expect(dto.version, '10.11.6');
      expect(dto.productName, 'Jellyfin Server');
      expect(dto.id, 'a1b2c3');
      expect(dto.startupWizardCompleted, isTrue);
    });

    test('tolerates missing fields (all nullable)', () {
      final dto = PublicSystemInfoDto.fromJson(const {'Version': '10.11.6'});

      expect(dto.version, '10.11.6');
      expect(dto.serverName, isNull);
      expect(dto.productName, isNull);
      expect(dto.id, isNull);
    });

    test('throws on a wrongly-typed field so the caller can normalize it', () {
      expect(
        () => PublicSystemInfoDto.fromJson(const {'Version': 42}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
