import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/core/result/result.dart';

void main() {
  group('Partial', () {
    test('hasUnavailable is false when nothing is missing', () {
      const partial = Partial<String>(available: ['a', 'b']);

      expect(partial.hasUnavailable, isFalse);
    });

    test('hasUnavailable is true when some items are missing', () {
      const partial = Partial<String>(
        available: ['a'],
        unavailable: [UnavailableItem(id: 'track-2', reason: 'deleted')],
      );

      expect(partial.hasUnavailable, isTrue);
      expect(partial.available, ['a']);
      expect(partial.unavailable.single.id, 'track-2');
    });

    test('an otherwise-successful load with a missing item is Ok, not Err', () {
      // Mirrors the product rule: 1 of 12 tracks unavailable still
      // succeeds, with the gap visibly recorded rather than hidden.
      const result = Result<Partial<String>>.ok(
        Partial(
          available: ['t1', 't2'],
          unavailable: [UnavailableItem(id: 't3', reason: 'unavailable')],
        ),
      );

      expect(result.isOk, isTrue);
      final partial = result.valueOrNull!;
      expect(partial.available, hasLength(2));
      expect(partial.hasUnavailable, isTrue);
    });

    test('two Partial values with equal contents are equal', () {
      const a = Partial<String>(
        available: ['x'],
        unavailable: [UnavailableItem(id: '1', reason: 'r')],
      );
      const b = Partial<String>(
        available: ['x'],
        unavailable: [UnavailableItem(id: '1', reason: 'r')],
      );

      expect(a, b);
    });
  });

  group('Failure subtypes', () {
    test('carry a presentable message and an optional cause', () {
      final cause = Exception('inner');
      final failure = UnexpectedFailure('something broke', cause: cause);

      expect(failure.message, 'something broke');
      expect(failure.cause, cause);
    });
  });
}
