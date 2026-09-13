import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/connected_playback/connection_state.dart';
import 'package:jellyfinity/infrastructure/jellyfin/connected/ConnectedSessionFailureMapper.dart';

/// A `Failure` carrying the `dio` exception the HTTP layer would have
/// attached, which is where the status code survives.
Failure httpFailure(int status) => UnauthorizedFailure(
  'whatever the HTTP layer said',
  cause: DioException(
    requestOptions: RequestOptions(path: '/Sessions'),
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/Sessions'),
      statusCode: status,
    ),
  ),
);

void main() {
  const mapper = ConnectedSessionFailureMapper();

  group('the four doors a REST failure arrives through', () {
    test('401 is authentication, and signing in again is the answer', () {
      final diagnosis = mapper.fromHttp(httpFailure(401));

      expect(diagnosis.problem, ConnectedSessionProblem.unauthenticated);
      expect(diagnosis.link, ConnectedPlaybackConnection.idle);
      expect(diagnosis.failure, isA<UnauthorizedFailure>());
      expect(mapper.isRetryable(diagnosis.problem), isFalse);
    });

    test('403 is permission, which signing in again cannot fix', () {
      final diagnosis = mapper.fromHttp(httpFailure(403));

      expect(diagnosis.problem, ConnectedSessionProblem.notPermitted);
      expect(diagnosis.link, ConnectedPlaybackConnection.notPermitted);
      expect(
        diagnosis.failure.message,
        contains('not allowed to control other devices'),
      );
      expect(mapper.isRetryable(diagnosis.problem), isFalse);
    });

    test('a missing endpoint is a server that cannot do this at all', () {
      final diagnosis = mapper.fromHttp(httpFailure(404));

      expect(diagnosis.problem, ConnectedSessionProblem.unsupported);
      expect(diagnosis.link, ConnectedPlaybackConnection.unsupported);
      expect(mapper.isRetryable(diagnosis.problem), isFalse);
    });

    test('a transport problem is the network, and is worth retrying', () {
      final diagnosis = mapper.fromHttp(
        const RecoverableFailure('could not reach the server'),
      );

      expect(diagnosis.problem, ConnectedSessionProblem.offline);
      expect(diagnosis.link, ConnectedPlaybackConnection.offline);
      expect(
        diagnosis.failure.message,
        contains('Playback on this device is unaffected'),
      );
      expect(mapper.isRetryable(diagnosis.problem), isTrue);
    });

    test('a version verdict reached before any request is kept', () {
      const tooOld = UnsupportedServerFailure('needs a newer server');

      final diagnosis = mapper.fromHttp(tooOld);

      expect(diagnosis.problem, ConnectedSessionProblem.unsupported);
      expect(diagnosis.failure, same(tooOld));
    });

    test('signing out before the request went anywhere reads as auth', () {
      final diagnosis = mapper.fromHttp(
        const UnauthorizedFailure('Sign in to see your other devices.'),
      );

      expect(diagnosis.problem, ConnectedSessionProblem.unauthenticated);
    });

    test('an unclassifiable failure still says the link is down', () {
      final diagnosis = mapper.fromHttp(const UnexpectedFailure('who knows'));

      expect(diagnosis.problem, ConnectedSessionProblem.unexpected);
      expect(diagnosis.link, ConnectedPlaybackConnection.offline);
      expect(mapper.isRetryable(diagnosis.problem), isTrue);
    });
  });

  group('a socket failure', () {
    test(
      'on a session that never had one is a proxy that will not upgrade',
      () {
        final diagnosis = mapper.fromSocket(
          const WebSocketException('not upgraded to websocket'),
          everConnected: false,
        );

        expect(diagnosis.problem, ConnectedSessionProblem.unsupported);
        expect(diagnosis.link, ConnectedPlaybackConnection.unsupported);
        expect(diagnosis.failure.message, contains('reverse proxy'));
        expect(mapper.isRetryable(diagnosis.problem), isFalse);
      },
    );

    test(
      'on a session that has had one is an interruption to recover from',
      () {
        final diagnosis = mapper.fromSocket(
          const WebSocketException('connection reset'),
          everConnected: true,
        );

        expect(diagnosis.problem, ConnectedSessionProblem.offline);
        expect(mapper.isRetryable(diagnosis.problem), isTrue);
      },
    );

    test('an address that cannot be opened at all is the same verdict', () {
      final diagnosis = mapper.fromSocket(
        const SocketException('connection refused'),
        everConnected: false,
      );

      expect(diagnosis.problem, ConnectedSessionProblem.unsupported);
    });
  });
}
