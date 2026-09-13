import '../../core/result/result.dart';
import 'CommandAcknowledgement.dart';
import 'ConnectedPlaybackEnvelope.dart';
import 'ConnectedPlaybackScope.dart';
import 'RemoteCommand.dart';
import 'RemotePlaybackSnapshot.dart';

/// Delivery of connected-playback messages between two sessions.
///
/// Narrow on purpose, for the same reason `PlaybackEngine` is narrow
/// (ADR-0013): this is the seam a second transport would have to satisfy,
/// and everything above it — arbitration, revisions, handoff — is
/// Jellyfinity's own logic sitting on top, not something a transport
/// reimplements. A transport moves envelopes and says whether it managed
/// to; it has no opinion about what they mean.
///
/// The implementations that matter are the Jellyfin session transport
/// (v0.5.2) and the in-memory fake the contract tests drive. That the
/// fake can satisfy this without pretending to be a WebSocket is the test
/// of whether the seam is in the right place.
abstract class ConnectedPlaybackTransport {
  /// Every envelope arriving for [scope], already filtered: out-of-scope,
  /// incompatible, self-sent and unreadable messages never reach here
  /// (see [ConnectedPlaybackEnvelope.decode]).
  ///
  /// Delivery is at-least-once and unordered. That is not a deficiency to
  /// be fixed in an implementation — it is the honest description of a
  /// WebSocket that can reconnect and replay — and it is why commands
  /// carry ids and states carry revisions.
  Stream<ConnectedPlaybackEnvelope> envelopes(ConnectedPlaybackScope scope);

  /// This session's id on the server, or `null` before one exists.
  ///
  /// Ephemeral: it changes when the socket reconnects, which is why it is
  /// read rather than stored by callers.
  String? get localSessionId;

  /// Sends [envelope] to one session.
  ///
  /// An [Ok] means the server accepted it for delivery — never that the
  /// target processed it. Only a [CommandAcknowledgement] means that.
  Future<Result<void>> send(
    ConnectedPlaybackEnvelope envelope, {
    required String targetSessionId,
  });

  /// Sends [command] and waits for the target's acknowledgement, or
  /// `ConnectedPlaybackLimits.acknowledgementTimeout`, whichever comes
  /// first. A timeout is an [Err], never a silent success.
  Future<Result<CommandAcknowledgement>> sendCommand(RemoteCommand command);

  /// Publishes [snapshot] to every controller watching this session.
  Future<Result<void>> publishSnapshot(RemotePlaybackSnapshot snapshot);

  /// Re-reads everything after an interruption, before structural
  /// commands are accepted again.
  ///
  /// The arc requires a full reconciliation after every reconnect rather
  /// than resuming mid-conversation, because the one thing a dropped
  /// socket guarantees is that both sides' idea of the revision is
  /// unverified.
  Future<Result<void>> resynchronize(ConnectedPlaybackScope scope);
}
