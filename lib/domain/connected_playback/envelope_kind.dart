/// What one connected-playback message is.
///
/// The wire form is the member's [wireName]; an unrecognized kind decodes
/// to `null` and the envelope is ignored rather than rejected. That is
/// the forward-compatibility rule the protocol's minor version exists
/// for: a newer peer may send message kinds this build has never heard
/// of, and the correct response is to carry on.
enum EnvelopeKind {
  /// A controller instructing a target.
  command,

  /// A target answering a command.
  acknowledgement,

  /// A target publishing its authoritative state.
  snapshot,

  /// A device advertising itself and its capabilities.
  presence,

  /// Step one of a handoff: the source asks whether the target can
  /// reproduce a queue. Nothing has stopped playing yet.
  transferOffer,

  /// Step one's answer: the target says whether it is ready, and names
  /// what it could not resolve if it is not.
  transferReadiness,

  /// Step two: the source yields ownership. This is the point of no
  /// return for the source's own playback.
  transferCommit,

  /// Step three: the target confirms it is playing and owns the queue.
  /// Until this arrives the source can still resume.
  transferResult;

  String get wireName => name;

  static EnvelopeKind? tryParse(Object? value) {
    if (value is! String) return null;
    for (final kind in EnvelopeKind.values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}
