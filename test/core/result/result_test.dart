import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';

void main() {
  group('Result', () {
    test('Ok reports isOk and exposes its value', () {
      const result = Result<int>.ok(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Err reports isErr and exposes its failure', () {
      const failure = UnavailableFailure('server unreachable');
      const result = Result<int>.err(failure);

      expect(result.isErr, isTrue);
      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('when() invokes the matching branch exactly', () {
      const ok = Result<int>.ok(1);
      const err = Result<int>.err(UnexpectedFailure('boom'));

      expect(ok.when(ok: (value) => 'ok:$value', err: (_) => 'err'), 'ok:1');
      expect(
        err.when(ok: (_) => 'ok', err: (failure) => 'err:${failure.message}'),
        'err:boom',
      );
    });

    test('map() transforms an Ok value and leaves Err untouched', () {
      const ok = Result<int>.ok(2);
      const failure = RecoverableFailure('timed out');
      const err = Result<int>.err(failure);

      expect(ok.map((value) => value * 10).valueOrNull, 20);
      expect(err.map((value) => value * 10).failureOrNull, failure);
    });

    test('two Ok results with equal values are equal', () {
      expect(const Result<int>.ok(1), const Result<int>.ok(1));
    });

    test('two Err results with equal failures are equal', () {
      expect(
        const Result<int>.err(UnexpectedFailure('x')),
        const Result<int>.err(UnexpectedFailure('x')),
      );
    });
  });
}
