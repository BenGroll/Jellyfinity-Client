import 'package:dio/dio.dart';

import '../../../core/logging/logger.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../identity/auth_token_provider.dart';
import '../identity/jellyfin_client_identity.dart';
import 'jellyfin_interceptors.dart';
import 'transport_error_mapper.dart';

/// A `dio`-backed HTTP client bound to one Jellyfin server.
///
/// Everything the transport milestone needs sits here: a base URL,
/// timeouts, the identity/auth header, request tracing, bounded retry, and
/// — crucially — a request surface that returns `Result<T>` and never lets
/// a `DioException` escape (ADR-0004 / ADR-0008).
///
/// It is created per server (the base URL is fixed at construction), so it
/// is not a DI singleton; `JellyfinServerProbe` builds one for a probe and
/// v0.0.5 will build a session-scoped one after login. Tests pass their
/// own [dio] with a fake adapter, so no real network is required.
class JellyfinHttpClient {
  JellyfinHttpClient({
    required String baseUrl,
    required JellyfinClientIdentity identity,
    required AuthTokenProvider authTokenProvider,
    required Logger logger,
    Dio? dio,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 20),
    int maxRetries = 2,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = connectTimeout
      ..receiveTimeout = receiveTimeout
      ..responseType = ResponseType.json;
    _dio.interceptors.addAll([
      JellyfinAuthorizationInterceptor(identity, authTokenProvider),
      CorrelationInterceptor(logger),
      RetryInterceptor(dio: _dio, logger: logger, maxRetries: maxRetries),
    ]);
  }

  final Dio _dio;
  final TransportErrorMapper _errorMapper = const TransportErrorMapper();

  /// GETs [path] and decodes the JSON object body with [parse].
  ///
  /// Returns `Err` for any transport failure, a non-object body, or a
  /// [parse] that throws on an unexpected shape — the caller only ever
  /// sees a `Result`.
  Future<Result<T>> getJson<T>(
    String path, {
    required T Function(Map<String, dynamic> json) parse,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } catch (error, stackTrace) {
      return Result.err(_errorMapper.map(error, stackTrace));
    }

    final body = response.data;
    if (body is! Map<String, dynamic>) {
      return const Result.err(
        UnexpectedFailure(
          'The server sent a response Jellyfinity could not read.',
        ),
      );
    }
    try {
      return Result.ok(parse(body));
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'The server sent a response Jellyfinity could not read.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Releases the underlying `dio` connections.
  void close({bool force = false}) => _dio.close(force: force);
}
