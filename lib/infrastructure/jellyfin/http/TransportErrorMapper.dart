import 'package:dio/dio.dart';

import '../../../core/result/failure.dart';

/// Translates raw transport errors — `dio` exceptions, JSON/format
/// errors, anything else thrown while talking to a server — into
/// Jellyfinity's `Failure` model (ADR-0004).
///
/// This is the enforcement point for "raw exceptions should not escape
/// into normal presentation code": every path out of the HTTP layer goes
/// through here, so `DioException` never reaches a Bloc or a widget.
class TransportErrorMapper {
  const TransportErrorMapper();

  Failure map(Object error, [StackTrace? stackTrace]) {
    if (error is DioException) {
      return _mapDio(error, stackTrace);
    }
    if (error is FormatException || error is TypeError) {
      return UnexpectedFailure(
        'The server sent a response Jellyfinity could not read.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedFailure(
      'Something went wrong while talking to the server.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  Failure _mapDio(DioException error, StackTrace? stackTrace) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return RecoverableFailure(
          'The server took too long to respond.',
          cause: error,
          stackTrace: stackTrace,
        );
      case DioExceptionType.connectionError:
        return RecoverableFailure(
          'Jellyfinity could not reach the server. '
          'Check the address and your connection.',
          cause: error,
          stackTrace: stackTrace,
        );
      case DioExceptionType.badCertificate:
        return UnavailableFailure(
          "The server's security certificate could not be verified.",
          cause: error,
          stackTrace: stackTrace,
        );
      case DioExceptionType.cancel:
        return RecoverableFailure(
          'The request was cancelled.',
          cause: error,
          stackTrace: stackTrace,
        );
      case DioExceptionType.badResponse:
        return _mapStatus(error, stackTrace);
      case DioExceptionType.unknown:
        return UnexpectedFailure(
          'Something went wrong while talking to the server.',
          cause: error,
          stackTrace: stackTrace,
        );
    }
  }

  Failure _mapStatus(DioException error, StackTrace? stackTrace) {
    final status = error.response?.statusCode ?? 0;
    return switch (status) {
      401 => UnauthorizedFailure(
        'Your session is no longer valid. Please sign in again.',
        cause: error,
        stackTrace: stackTrace,
      ),
      403 => UnauthorizedFailure(
        "You don't have permission to do that on this server.",
        cause: error,
        stackTrace: stackTrace,
      ),
      404 => UnavailableFailure(
        'That was not found on the server.',
        cause: error,
        stackTrace: stackTrace,
      ),
      >= 500 => RecoverableFailure(
        'The server reported an error. Try again in a moment.',
        cause: error,
        stackTrace: stackTrace,
      ),
      _ => UnexpectedFailure(
        'The server returned an unexpected response ($status).',
        cause: error,
        stackTrace: stackTrace,
      ),
    };
  }
}
