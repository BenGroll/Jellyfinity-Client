import 'package:equatable/equatable.dart';

/// A parsed Jellyfin server version.
///
/// Jellyfin reports versions as dotted numbers — usually three parts
/// (`10.11.6`), occasionally four (`10.11.6.0`). Only the numeric prefix
/// is interpreted; anything after it is ignored so an unexpected suffix
/// never makes a version unparseable.
class ServerVersion extends Equatable implements Comparable<ServerVersion> {
  const ServerVersion(this.major, this.minor, this.patch, [this.revision = 0]);

  /// Parses [raw], returning `null` if it does not start with at least
  /// `MAJOR.MINOR`.
  static ServerVersion? tryParse(String raw) {
    final match = RegExp(
      r'^\s*(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?',
    ).firstMatch(raw);
    if (match == null) return null;
    return ServerVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3) ?? '0'),
      int.parse(match.group(4) ?? '0'),
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int revision;

  @override
  int compareTo(ServerVersion other) {
    for (final pair in [
      [major, other.major],
      [minor, other.minor],
      [patch, other.patch],
      [revision, other.revision],
    ]) {
      final diff = pair[0].compareTo(pair[1]);
      if (diff != 0) return diff;
    }
    return 0;
  }

  bool operator >=(ServerVersion other) => compareTo(other) >= 0;
  bool operator >(ServerVersion other) => compareTo(other) > 0;
  bool operator <=(ServerVersion other) => compareTo(other) <= 0;
  bool operator <(ServerVersion other) => compareTo(other) < 0;

  @override
  List<Object?> get props => [major, minor, patch, revision];

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    return revision == 0 ? base : '$base.$revision';
  }
}
