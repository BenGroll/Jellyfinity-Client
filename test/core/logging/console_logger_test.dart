import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/logging/console_logger.dart';
import 'package:jellyfinity/core/logging/logger.dart';

void main() {
  group('ConsoleLogger', () {
    late Logger logger;

    setUp(() {
      logger = ConsoleLogger();
    });

    test('logs at every level without throwing', () {
      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(
        () => logger.error(
          'error message',
          error: Exception('boom'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });
  });

  group('redact', () {
    test('masks all but the visible prefix', () {
      expect(redact('supersecrettoken'), 'su**************');
    });

    test('respects a custom visible-prefix length', () {
      expect(redact('abcdef', visiblePrefixLength: 0), '******');
    });

    test('returns an empty string unchanged', () {
      expect(redact(''), '');
    });

    test('does not overflow when the value is shorter than the prefix', () {
      expect(redact('a', visiblePrefixLength: 5), 'a');
    });
  });
}
