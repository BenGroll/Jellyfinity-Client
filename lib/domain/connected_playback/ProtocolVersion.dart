import 'package:equatable/equatable.dart';

/// The version of the connected-playback conversation a client speaks.
///
/// Two Jellyfinity installs talking through a Jellyfin server are two
/// independently updated applications: the listener's phone updates from
/// a store, their Fire TV sideload does not, and their Windows build is
/// whatever they last downloaded. There is no deployment in which both
/// ends are guaranteed to be the same build, so the conversation is
/// versioned from its first release rather than after the first time a
/// mismatch breaks something.
///
/// Compatibility is the ordinary major/minor rule, stated here so both
/// sides apply it identically:
///
/// - Different [major] — incompatible. The peer is described as
///   incompatible in the UI and is never offered as a handoff target. It
///   is not an error state to recover from; one of the two installs has
///   to be updated.
/// - Same [major], any [minor] — compatible. A newer peer may send
///   commands or fields this build has never heard of; those are ignored
///   individually (see `ConnectedPlaybackEnvelope` and
///   `RemoteCommandKind.tryParse`) rather than failing the message. An
///   older peer simply never sends them.
///
/// That asymmetry is the whole point of separating the two numbers:
/// [minor] rises when something is *added* that an older build can safely
/// ignore, [major] rises when something an older build would get *wrong*
/// changes.
class ProtocolVersion extends Equatable implements Comparable<ProtocolVersion> {
  const ProtocolVersion(this.major, this.minor);

  /// The version this build of Jellyfinity speaks.
  ///
  /// v0.5.1 defines the vocabulary; v0.5.2-v0.6.0 fill in transport, UI
  /// and platforms without changing its meaning, so the whole arc ships
  /// as 1.0 unless a command's semantics actually change.
  static const ProtocolVersion current = ProtocolVersion(1, 0);

  final int major;
  final int minor;

  /// Whether this build can hold a conversation with [other].
  bool isCompatibleWith(ProtocolVersion other) => major == other.major;

  /// Whether [other] may be speaking about things this build does not
  /// know — true for a compatible peer that is ahead on [minor].
  ///
  /// Not a problem in itself; it is the reason unknown commands and
  /// payload fields must be ignored rather than treated as corruption.
  bool isAheadOf(ProtocolVersion other) =>
      isCompatibleWith(other) && minor > other.minor;

  /// Parses the `major.minor` wire form. Returns `null` for anything that
  /// is not well formed — including a three-part version from a future
  /// build — so a malformed advertisement reads as "incompatible peer"
  /// rather than crashing the client that received it.
  static ProtocolVersion? tryParse(String? value) {
    if (value == null) return null;
    final parts = value.split('.');
    if (parts.length != 2) return null;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    if (major == null || minor == null) return null;
    if (major < 0 || minor < 0) return null;
    return ProtocolVersion(major, minor);
  }

  @override
  int compareTo(ProtocolVersion other) {
    final byMajor = major.compareTo(other.major);
    return byMajor != 0 ? byMajor : minor.compareTo(other.minor);
  }

  @override
  List<Object?> get props => [major, minor];

  @override
  String toString() => '$major.$minor';
}
