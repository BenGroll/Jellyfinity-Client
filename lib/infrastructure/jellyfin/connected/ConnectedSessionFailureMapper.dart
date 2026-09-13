import 'dart:io';

import '../../../core/result/failure.dart';
import '../../../domain/connected_playback/ConnectedPlaybackFailures.dart';
import '../../../domain/connected_playback/connection_state.dart';

/// What one failed attempt to reach the connected-playback channel was.
///
/// Five members because the arc requires five answers to stay separate,
/// and because each has a different next step for the listener: wait,
/// sign in again, ask the server's owner, fix the server or the proxy in
/// front of it, or report a bug. Collapsing any two of them produces the
/// device picker that says "something went wrong" and helps nobody.
enum ConnectedSessionProblem {
  /// The server could not be reached. Local playback is unaffected.
  offline,

  /// The session's own credentials were rejected.
  unauthenticated,

  /// Reached and refused: this profile may not control sessions.
  notPermitted,

  /// Reached, authenticated, and structurally unable to carry the
  /// conversation — too old, or behind something that will not forward a
  /// WebSocket upgrade.
  unsupported,

  /// Something nobody anticipated.
  unexpected,
}

/// The result of classifying a failure: what it was, how to describe it,
/// and what it means for the link.
typedef ConnectedSessionDiagnosis = ({
  ConnectedSessionProblem problem,
  Failure failure,
  ConnectedPlaybackConnection link,
});

/// Normalizes everything that can go wrong on the way to another device
/// into the five answers above.
///
/// One classifier for both halves of the transport, because they see the
/// same problems through different windows and have to agree about them.
/// REST gives a status code, which is the better witness: 401 and 403
/// both surface as `UnauthorizedFailure` from the HTTP layer and mean
/// opposite things here — "sign in again" versus "signing in again is the
/// one thing that cannot help".
///
/// A socket gives far less. `WebSocket.connect` throws the same
/// `WebSocketException` for an upgrade a proxy refused, a 401 and a
/// server that has no socket at all, so guessing between them from the
/// exception is not possible. What *is* available is whether this session
/// ever had a working socket, and that answers the question the listener
/// actually has: a socket that has worked and dropped is a network
/// interruption to reconnect from, while a socket that has never worked
/// against a server whose REST API answers fine is a proxy that does not
/// forward upgrades. That is the single most common way a self-hosted
/// Jellyfin looks healthy and still cannot do this.
class ConnectedSessionFailureMapper {
  const ConnectedSessionFailureMapper();

  /// Classifies a failure from the REST half.
  ConnectedSessionDiagnosis fromHttp(Failure failure) {
    // An already-normalized verdict — the server-version floor is checked
    // before any request goes out — is not re-derived from a status it
    // never had.
    if (failure is UnsupportedServerFailure) {
      return _diagnosis(ConnectedSessionProblem.unsupported, failure);
    }

    final status = _statusOf(failure);
    if (status == 403) {
      return _diagnosis(
        ConnectedSessionProblem.notPermitted,
        ConnectedPlaybackFailures.notPermitted(),
      );
    }
    if (status == 401) {
      return _diagnosis(
        ConnectedSessionProblem.unauthenticated,
        ConnectedPlaybackFailures.unauthenticated(),
      );
    }
    if (status == 404 || status == 405) {
      return _diagnosis(
        ConnectedSessionProblem.unsupported,
        ConnectedPlaybackFailures.transportUnsupported(
          'This server does not offer the session controls Jellyfinity needs '
          'to find your other devices.',
        ),
      );
    }
    if (failure is UnauthorizedFailure) {
      // No status to read — a request refused before it was sent, because
      // nobody is signed in.
      return _diagnosis(ConnectedSessionProblem.unauthenticated, failure);
    }
    if (failure is RecoverableFailure || failure is UnavailableFailure) {
      return _diagnosis(
        ConnectedSessionProblem.offline,
        ConnectedPlaybackFailures.offline(),
      );
    }
    return _diagnosis(ConnectedSessionProblem.unexpected, failure);
  }

  /// Classifies a socket failure.
  ///
  /// [everConnected] is this session's history, not this attempt's: see
  /// the class comment for why it is the deciding fact rather than the
  /// exception type.
  ConnectedSessionDiagnosis fromSocket(
    Object error, {
    required bool everConnected,
  }) {
    if (everConnected) {
      return _diagnosis(
        ConnectedSessionProblem.offline,
        ConnectedPlaybackFailures.offline(),
      );
    }
    if (error is WebSocketException || error is HttpException) {
      return _diagnosis(
        ConnectedSessionProblem.unsupported,
        ConnectedPlaybackFailures.transportUnsupported(),
      );
    }
    if (error is SocketException || error is HandshakeException) {
      // The address itself could not be opened. On a server whose REST
      // API has just answered, that is a proxy or firewall in front of
      // the socket rather than a connection that comes and goes.
      return _diagnosis(
        ConnectedSessionProblem.unsupported,
        ConnectedPlaybackFailures.transportUnsupported(),
      );
    }
    return _diagnosis(
      ConnectedSessionProblem.unexpected,
      ConnectedPlaybackFailures.transportUnsupported(),
    );
  }

  ConnectedSessionDiagnosis _diagnosis(
    ConnectedSessionProblem problem,
    Failure failure,
  ) => (problem: problem, failure: failure, link: linkStateFor(problem));

  /// What the listener's own device shows while this problem stands.
  ///
  /// [ConnectedSessionProblem.unexpected] deliberately reads as
  /// `offline`: an unclassified failure is still a failure to reach the
  /// channel, and "your server could not be reached, your music is
  /// unaffected" is both true and useful, where a fourth mystery state
  /// would be neither.
  ConnectedPlaybackConnection linkStateFor(ConnectedSessionProblem problem) =>
      switch (problem) {
        ConnectedSessionProblem.offline || ConnectedSessionProblem.unexpected =>
          ConnectedPlaybackConnection.offline,
        ConnectedSessionProblem.unauthenticated =>
          ConnectedPlaybackConnection.idle,
        ConnectedSessionProblem.notPermitted =>
          ConnectedPlaybackConnection.notPermitted,
        ConnectedSessionProblem.unsupported =>
          ConnectedPlaybackConnection.unsupported,
      };

  /// Whether waiting and trying again could change the answer.
  ///
  /// The three that cannot are the three that need a person to do
  /// something: sign in, be granted permission, or change the server.
  /// Retrying those forever would be a busy loop that never reports what
  /// is actually wrong.
  bool isRetryable(ConnectedSessionProblem problem) =>
      problem == ConnectedSessionProblem.offline ||
      problem == ConnectedSessionProblem.unexpected;

  /// Whether [failure] is a delivery that found no such session.
  ///
  /// Asked only of a message addressed to one peer, where 404 is the
  /// server saying "that session is gone" — a fact about that device.
  /// [fromHttp] reads the same status as [ConnectedSessionProblem
  /// .unsupported], which is right for a route that should exist and
  /// wrong for a session that need not, and the two callers must not
  /// share an answer: one dead peer would otherwise declare the whole
  /// server unable to carry connected playback.
  bool isMissingTarget(Failure failure) => _statusOf(failure) == 404;

  int? _statusOf(Failure failure) {
    final cause = failure.cause;
    // Read structurally rather than importing `dio` here: the HTTP client
    // already owns that dependency, and a second import of it would be a
    // second place a transport swap has to touch.
    try {
      final status = (cause as dynamic)?.response?.statusCode;
      return status is int ? status : null;
    } catch (_) {
      return null;
    }
  }
}
