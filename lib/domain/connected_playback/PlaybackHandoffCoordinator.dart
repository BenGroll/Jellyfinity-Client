import '../../core/result/result.dart';
import 'ConnectedDevice.dart';
import 'PlaybackTransfer.dart';
import 'RemotePlaybackSnapshot.dart';

/// Moving playback from one device to another, in both directions.
///
/// Two methods because a handoff has two sides and they are genuinely
/// different jobs: the source risks its own playing music and needs
/// somewhere to resume from, while the target risks nothing until it
/// commits to starting. Collapsing them into one "transfer" method would
/// hide that asymmetry, which is the only reason a lost acknowledgement
/// is survivable.
abstract class PlaybackHandoffCoordinator {
  /// Hands the current local queue to [target], leaving this device a
  /// controller.
  ///
  /// Runs the full offer/readiness/commit/result conversation. Local
  /// playback continues untouched until the target has said it is ready;
  /// an [Err] therefore means the music is still playing here, and the
  /// failure carries an explanation of what the target could not do.
  Future<Result<TransferResult>> transferTo({
    required ConnectedDevice target,
    required RemotePlaybackSnapshot snapshot,
  });

  /// Answers an incoming [TransferOffer] by checking whether this device
  /// can reproduce the queue *in full*.
  ///
  /// Resolving is allowed to be slow — it may involve reading the server
  /// — which is exactly why this step exists before the source stops.
  /// Never partially ready: an offer this device can only half satisfy is
  /// refused with the entries it could not resolve.
  Future<TransferReadiness> prepare(TransferOffer offer);

  /// Takes ownership after the source has yielded it, and reports back.
  ///
  /// Reaching this point means the source has already stopped, so a
  /// failure here is the one case where nobody is playing. It must still
  /// be answered — a [TransferResult] that refuses is what lets the
  /// source resume.
  Future<TransferResult> accept(TransferCommit commit);
}
