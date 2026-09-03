import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A [HttpClientAdapter] that answers requests from a supplied handler
/// instead of hitting the network, so transport code can be tested
/// deterministically (ADR-0008: "do not require a live Jellyfin server").
class FakeDioAdapter implements HttpClientAdapter {
  FakeDioAdapter(this.handler);

  /// Builds one canned response per request. Throw a [DioException] from
  /// here to simulate a transport failure.
  final Future<ResponseBody> Function(RequestOptions options) handler;

  /// Every request that reached the adapter, in order.
  final List<RequestOptions> requests = [];

  int get callCount => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON [ResponseBody] with the content-type `dio` needs to decode it
/// into a `Map`.
ResponseBody jsonResponseBody(Object? body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// A raw-text [ResponseBody] (e.g. to simulate an HTML error page where
/// JSON was expected).
ResponseBody textResponseBody(String body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['text/plain'],
    },
  );
}
