import 'package:equatable/equatable.dart';

import 'StateRevision.dart';
import 'command_outcome.dart';

/// A target's answer to one command.
///
/// The arc requires targets to "acknowledge the resulting revision", and
/// that is the field doing the real work here: a controller that knows
/// which revision its command produced can compose the next structural
/// command immediately, without waiting for the snapshot to arrive
/// separately. Without it, every edit would cost a full round trip plus a
/// snapshot before the next one could be made, which is what makes a
/// remote queue screen feel broken.
///
/// An acknowledgement is sent for *every* command, including the ones
/// that were refused. Silence is indistinguishable from a lost message,
/// and the controller's only response to silence is a timeout — so a
/// target that quietly ignores what it will not do turns an instant,
/// explainable refusal into fifteen seconds of nothing.
class CommandAcknowledgement extends Equatable {
  const CommandAcknowledgement({
    required this.commandId,
    required this.sessionId,
    required this.outcome,
    required this.revision,
    this.message,
  });

  /// Accepted, carrying the revision the target is now at.
  factory CommandAcknowledgement.applied({
    required String commandId,
    required String sessionId,
    required StateRevision revision,
  }) => CommandAcknowledgement(
    commandId: commandId,
    sessionId: sessionId,
    outcome: CommandOutcome.applied,
    revision: revision,
  );

  /// Refused, carrying the revision the target is *actually* at — which
  /// is the whole point of answering a stale command rather than dropping
  /// it. The controller learns what it got wrong in the same message that
  /// tells it that it got something wrong.
  factory CommandAcknowledgement.refused({
    required String commandId,
    required String sessionId,
    required CommandOutcome outcome,
    required StateRevision revision,
    String? message,
  }) {
    assert(!outcome.isAccepted, 'refused() needs a refusing outcome');
    return CommandAcknowledgement(
      commandId: commandId,
      sessionId: sessionId,
      outcome: outcome,
      revision: revision,
      message: message,
    );
  }

  final String commandId;

  /// The session answering. A controller checks it: an acknowledgement
  /// from a session it is no longer talking to is history, not news.
  final String sessionId;

  final CommandOutcome outcome;

  /// The target's revision after processing — the new one when applied,
  /// the unchanged current one when refused.
  final StateRevision revision;

  /// A short, user-presentable explanation for a refusal. Never contains
  /// credentials or tokens, the same rule `Failure.message` carries.
  final String? message;

  bool get isAccepted => outcome.isAccepted;

  /// The envelope payload form.
  Map<String, Object?> toPayload() => {
    'commandId': commandId,
    'session': sessionId,
    'outcome': outcome.name,
    'revision': revision.value,
    if (message != null) 'message': message,
  };

  /// Reverses [toPayload]. Returns `null` for a payload missing anything
  /// required, and for an outcome this build does not know — a newer peer
  /// refusing for a reason that did not exist yet is indistinguishable
  /// from silence here, and silence is what the controller's timeout
  /// already handles correctly.
  static CommandAcknowledgement? tryDecode(Map<String, Object?> payload) {
    final commandId = payload['commandId'];
    final sessionId = payload['session'];
    final revision = StateRevision.tryParse(payload['revision']);
    final outcomeName = payload['outcome'];
    if (commandId is! String || commandId.isEmpty) return null;
    if (sessionId is! String || sessionId.isEmpty) return null;
    if (revision == null || outcomeName is! String) return null;
    CommandOutcome? outcome;
    for (final candidate in CommandOutcome.values) {
      if (candidate.name == outcomeName) outcome = candidate;
    }
    if (outcome == null) return null;
    final message = payload['message'];
    return CommandAcknowledgement(
      commandId: commandId,
      sessionId: sessionId,
      outcome: outcome,
      revision: revision,
      message: message is String && message.isNotEmpty ? message : null,
    );
  }

  @override
  List<Object?> get props => [commandId, sessionId, outcome, revision, message];
}
