import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/logging/Logger.dart';
import '../identity/auth_token_provider.dart';
import '../identity/JellyfinClientIdentity.dart';

/// Attaches Jellyfinity's identity (and the session token, once there is
/// one) to every outgoing request as the single `Authorization` header
/// Jellyfin expects.
///
/// This is the only cross-cutting header concern the transport has right
/// now; per ADR-0008 middleware is added only for genuinely cross-cutting
/// transport concerns, and only this and light request tracing qualify.
class JellyfinAuthorizationInterceptor extends Interceptor {
  JellyfinAuthorizationInterceptor(this._identity, this._tokenProvider);

  final JellyfinClientIdentity _identity;
  final AuthTokenProvider _tokenProvider;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenProvider.currentToken();
    options.headers[JellyfinClientIdentity.authorizationHeader] = _identity
        .authorizationHeaderValue(token: token);
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }
}

/// Tags each request with a short correlation id and logs its lifecycle at
/// debug level, so a failing request can be followed through the logs.
///
/// Only the method and path are logged — never headers, never the query
/// string — so the `Authorization` header and any future token stay out of
/// the logs (the privacy rule on `Logger`).
class CorrelationInterceptor extends Interceptor {
  CorrelationInterceptor(this._logger);

  final Logger _logger;
  final Random _random = Random();

  static const String correlationIdKey = 'jellyfinityCorrelationId';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = _random.nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0');
    options.extra[correlationIdKey] = id;
    _logger.debug('[$id] → ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final id = response.requestOptions.extra[correlationIdKey];
    _logger.debug(
      '[$id] ← ${response.statusCode} ${response.requestOptions.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final id = err.requestOptions.extra[correlationIdKey];
    _logger.debug(
      '[$id] ✕ ${err.type.name} ${err.requestOptions.path}'
      '${err.response?.statusCode != null ? ' (${err.response!.statusCode})' : ''}',
    );
    handler.next(err);
  }
}

/// Retries transient network failures on safe (idempotent) requests, with
/// a small linear backoff, up to [maxRetries] times.
///
/// Deliberately narrow: only GET/HEAD, only connection/timeout errors —
/// never a request that reached the server and got an HTTP response, and
/// never a write. This is the "carefully bounded retry behavior" ADR-0008
/// allows in middleware; anything smarter belongs in a repository.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    required this.logger,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 300),
  });

  final Dio dio;
  final Logger logger;
  final int maxRetries;
  final Duration baseDelay;

  static const String _attemptKey = 'jellyfinityRetryAttempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;
    if (!_isRetryable(err) || attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    final nextAttempt = attempt + 1;
    await Future<void>.delayed(baseDelay * nextAttempt);
    logger.debug(
      'Retrying ${err.requestOptions.method} ${err.requestOptions.path} '
      '(attempt $nextAttempt/$maxRetries)',
    );

    final options = err.requestOptions..extra[_attemptKey] = nextAttempt;
    try {
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isRetryable(DioException err) {
    final method = err.requestOptions.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD') return false;
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
  }
}
