import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/minimum_server_version_policy.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/server_version.dart';

void main() {
  group('ServerVersion.tryParse', () {
    test('parses a three-part version', () {
      expect(ServerVersion.tryParse('10.11.6'), const ServerVersion(10, 11, 6));
    });

    test('parses a four-part version', () {
      expect(
        ServerVersion.tryParse('10.11.6.0'),
        const ServerVersion(10, 11, 6, 0),
      );
    });

    test('defaults a missing patch to zero', () {
      expect(ServerVersion.tryParse('10.11'), const ServerVersion(10, 11, 0));
    });

    test('ignores a trailing suffix', () {
      expect(
        ServerVersion.tryParse('10.11.6-beta1'),
        const ServerVersion(10, 11, 6),
      );
    });

    test('tolerates surrounding whitespace', () {
      expect(
        ServerVersion.tryParse('  10.11.6 '),
        const ServerVersion(10, 11, 6),
      );
    });

    test('returns null for a non-version string', () {
      expect(ServerVersion.tryParse('not-a-version'), isNull);
      expect(ServerVersion.tryParse(''), isNull);
      expect(ServerVersion.tryParse('10'), isNull);
    });
  });

  group('ServerVersion comparison', () {
    test('orders by each component in turn', () {
      expect(
        const ServerVersion(10, 11, 6) > const ServerVersion(10, 11, 5),
        isTrue,
      );
      expect(
        const ServerVersion(10, 11, 6) < const ServerVersion(10, 12, 0),
        isTrue,
      );
      expect(
        const ServerVersion(9, 99, 99) < const ServerVersion(10, 0, 0),
        isTrue,
      );
    });

    test('equal versions compare as >= and <=', () {
      const a = ServerVersion(10, 11, 6);
      const b = ServerVersion(10, 11, 6);
      expect(a >= b, isTrue);
      expect(a <= b, isTrue);
      expect(a > b, isFalse);
      expect(a, b);
    });

    test('toString round-trips the meaningful parts', () {
      expect(const ServerVersion(10, 11, 6).toString(), '10.11.6');
      expect(const ServerVersion(10, 11, 6, 2).toString(), '10.11.6.2');
    });
  });

  group('MinimumServerVersionPolicy', () {
    const policy = MinimumServerVersionPolicy.current;

    test('the shipped floor is 10.11.6', () {
      expect(policy.minimum, const ServerVersion(10, 11, 6));
    });

    test('accepts the exact minimum and anything newer', () {
      expect(policy.isSupported(const ServerVersion(10, 11, 6)), isTrue);
      expect(policy.isSupported(const ServerVersion(10, 11, 7)), isTrue);
      expect(policy.isSupported(const ServerVersion(10, 12, 0)), isTrue);
      expect(policy.isSupported(const ServerVersion(11, 0, 0)), isTrue);
    });

    test('rejects anything older than the minimum', () {
      expect(policy.isSupported(const ServerVersion(10, 11, 5)), isFalse);
      expect(policy.isSupported(const ServerVersion(10, 10, 9)), isFalse);
      expect(policy.isSupported(const ServerVersion(9, 0, 0)), isFalse);
    });
  });
}
