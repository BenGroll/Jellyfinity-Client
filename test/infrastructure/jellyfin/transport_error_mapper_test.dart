import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/infrastructure/jellyfin/http/transport_error_mapper.dart';

DioException _dio(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: '/System/Info/Public');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: status),
  );
}

void main() {
  const mapper = TransportErrorMapper();

  group('dio connection failures', () {
    test('timeouts map to RecoverableFailure', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(mapper.map(_dio(type)), isA<RecoverableFailure>());
      }
    });

    test(
      'connectionError (DNS / refused / host down) maps to RecoverableFailure',
      () {
        expect(
          mapper.map(_dio(DioExceptionType.connectionError)),
          isA<RecoverableFailure>(),
        );
      },
    );

    test('a bad TLS certificate maps to UnavailableFailure', () {
      expect(
        mapper.map(_dio(DioExceptionType.badCertificate)),
        isA<UnavailableFailure>(),
      );
    });

    test('a cancelled request maps to RecoverableFailure', () {
      expect(
        mapper.map(_dio(DioExceptionType.cancel)),
        isA<RecoverableFailure>(),
      );
    });
  });

  group('dio HTTP status responses', () {
    test('401 and 403 map to UnauthorizedFailure', () {
      expect(
        mapper.map(_dio(DioExceptionType.badResponse, status: 401)),
        isA<UnauthorizedFailure>(),
      );
      expect(
        mapper.map(_dio(DioExceptionType.badResponse, status: 403)),
        isA<UnauthorizedFailure>(),
      );
    });

    test('404 maps to UnavailableFailure', () {
      expect(
        mapper.map(_dio(DioExceptionType.badResponse, status: 404)),
        isA<UnavailableFailure>(),
      );
    });

    test('5xx maps to RecoverableFailure', () {
      expect(
        mapper.map(_dio(DioExceptionType.badResponse, status: 503)),
        isA<RecoverableFailure>(),
      );
    });

    test('an unexpected status maps to UnexpectedFailure', () {
      expect(
        mapper.map(_dio(DioExceptionType.badResponse, status: 418)),
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('non-dio errors', () {
    test('a FormatException maps to a "could not read" UnexpectedFailure', () {
      final failure = mapper.map(const FormatException('bad json'));
      expect(failure, isA<UnexpectedFailure>());
      expect(failure.message, contains('could not read'));
    });

    test('anything else maps to a generic UnexpectedFailure', () {
      expect(mapper.map(Exception('surprise')), isA<UnexpectedFailure>());
    });

    test('the original error is kept as the failure cause', () {
      final cause = Exception('surprise');
      expect(mapper.map(cause).cause, same(cause));
    });
  });
}
