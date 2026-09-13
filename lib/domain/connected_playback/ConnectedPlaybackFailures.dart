import '../../core/result/failure.dart';
import 'CommandAcknowledgement.dart';
import 'command_outcome.dart';

/// The one place a connected-playback problem becomes a [Failure].
///
/// `CONTEXT.md` requires normalized failures and forbids raw exceptions
/// reaching the UI. A control channel makes that harder than an HTTP call
/// does, because the same user-visible outcome — "that did not happen" —
/// arrives through four different doors: a socket error, an
/// acknowledgement carrying a refusal, a timeout with no answer at all,
/// and a peer that was never compatible to begin with.
///
/// Centralizing the translation is what keeps the answers consistent
/// across those doors, and what keeps the retry decision in one place:
/// every message below is paired with a [Failure] subtype whose category
/// already tells the UI whether a retry is honest.
abstract final class ConnectedPlaybackFailures {
  /// The refusal carried by [acknowledgement], as a [Failure].
  ///
  /// Only call this for an acknowledgement that actually refused;
  /// [CommandOutcome.applied] and [CommandOutcome.duplicate] are
  /// successes and have no failure to build.
  static Failure fromAcknowledgement(CommandAcknowledgement acknowledgement) {
    final message = acknowledgement.message;
    return switch (acknowledgement.outcome) {
      CommandOutcome.applied || CommandOutcome.duplicate => UnexpectedFailure(
        message ?? 'A successful command was reported as a failure.',
      ),
      CommandOutcome.stale => RecoverableFailure(
        message ?? 'That device has moved on. Refreshing and trying again.',
      ),
      CommandOutcome.expired => RecoverableFailure(
        message ?? 'That took too long to reach the device. Try again.',
      ),
      CommandOutcome.unsupported => const IncompatibleClientFailure(
        'That device is running an older version of Jellyfinity that does '
        'not support this control.',
      ),
      CommandOutcome.incompatible => incompatibleProtocol(),
      CommandOutcome.outOfScope => const UnavailableFailure(
        'That device is no longer signed in to this profile.',
      ),
      CommandOutcome.wrongTarget => const UnavailableFailure(
        'That device reconnected. Reselect it to keep controlling it.',
      ),
      CommandOutcome.notPermitted => const UnauthorizedFailure(
        'This account is not allowed to control that device.',
      ),
      CommandOutcome.tooLarge => UnavailableFailure(
        message ?? 'That queue is too long to send to another device.',
      ),
      CommandOutcome.rejected => UnavailableFailure(
        message ?? 'That device could not carry out that request.',
      ),
    };
  }

  /// No acknowledgement arrived within
  /// `ConnectedPlaybackLimits.acknowledgementTimeout`.
  ///
  /// Recoverable rather than unavailable: the command may well have been
  /// applied and only the answer lost, which is exactly why the caller's
  /// next step is a resync rather than a blind resend.
  static Failure timedOut() => const RecoverableFailure(
    'That device did not answer. Checking what it is playing.',
  );

  /// The local session cannot reach the server, so there is no relay.
  ///
  /// Deliberately worded to keep local playback out of it: offline
  /// playback continues, only connected playback stops (`Roadmap to
  /// v0.6.md`).
  static Failure offline() => const UnavailableFailure(
    'Connecting to other devices needs your server. Playback on this device '
    'is unaffected.',
  );

  /// The server is reachable but cannot carry this conversation.
  ///
  /// Its own category because the listener's next step is completely
  /// different from every other failure here: not "try again", not "sign
  /// in", but "change something about your server or the proxy in front
  /// of it". A reverse proxy that terminates HTTPS without forwarding
  /// the WebSocket upgrade is the common case, and it looks exactly like
  /// a working server until a client needs a socket.
  static Failure transportUnsupported([String? detail]) =>
      UnsupportedServerFailure(
        detail ??
            'Your server is reachable but will not open the live connection '
                'Jellyfinity needs to see your other devices. A reverse proxy '
                'in front of it may not be forwarding WebSocket connections.',
      );

  /// The server is older than the minimum this conversation needs.
  ///
  /// Distinct from [transportUnsupported] even though both are
  /// [UnsupportedServerFailure]s, because "upgrade your server" and
  /// "fix your proxy" are different jobs and a single message that
  /// suggested both would help with neither.
  static Failure serverTooOld(String reportedVersion) =>
      UnsupportedServerFailure(
        'Playing on another device needs a newer Jellyfin server than '
        '$reportedVersion.',
      );

  /// Reached and refused: this profile may not see or control other
  /// sessions on this server.
  ///
  /// Not an authentication problem, and saying so matters — signing in
  /// again is the one thing that cannot help, and it is the first thing
  /// a listener will try if the message is vague.
  static Failure notPermitted() => const UnauthorizedFailure(
    'This account is not allowed to control other devices on this server. '
    'Ask the server owner to enable remote control for it.',
  );

  /// The session's own credentials were rejected.
  static Failure unauthenticated() => const UnauthorizedFailure(
    'Your session is no longer valid. Please sign in again.',
  );

  /// The peer speaks a different protocol major version.
  static Failure incompatibleProtocol() => const IncompatibleClientFailure(
    'That device is running a version of Jellyfinity that cannot connect to '
    'this one. Update both to continue.',
  );

  /// The device is visible but command delivery is not working — presence
  /// without a control channel.
  static Failure notReachable() => const UnavailableFailure(
    'That device is visible but not responding to controls right now.',
  );

  /// A queue or payload exceeded an agreed bound. [detail] says which, in
  /// the listener's terms, and must never carry an identifier or token.
  static Failure tooLarge(String detail) => UnavailableFailure(detail);

  /// An envelope could not be understood at all — malformed JSON, a
  /// missing required field, a payload over the byte bound.
  ///
  /// Never surfaced to the listener on its own: a garbled message from
  /// one peer is a log line, not a screen. It exists so the decoder has
  /// something to return instead of throwing.
  static Failure malformedMessage(String detail) =>
      UnexpectedFailure('Unreadable connected-playback message: $detail');
}
