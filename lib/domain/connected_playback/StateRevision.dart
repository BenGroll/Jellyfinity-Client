import 'package:equatable/equatable.dart';

/// A monotonically increasing counter identifying one version of a
/// target's authoritative playback state.
///
/// This is the mechanism behind two of the arc's invariants at once.
///
/// *Reordering.* Messages arrive through a Jellyfin WebSocket and a REST
/// resync that have no shared ordering guarantee, so a controller can
/// receive yesterday's snapshot after today's. A controller therefore
/// never takes the newest message it received; it takes the highest
/// revision it has seen and drops anything below it.
///
/// *Serializing competing controllers.* A structural command names the
/// revision it was composed against. Two controllers reacting to the same
/// snapshot both say "remove track 4 from revision 12"; the first is
/// applied and produces revision 13, the second no longer matches and is
/// rejected as stale. The second controller resynchronizes and decides
/// again with the truth in front of it, which is the only way "remove
/// track 4" does not silently become "remove whatever is now in slot 4".
///
/// The counter belongs to the target session and resets with it. It is
/// never compared across sessions, so there is no need for it to be
/// globally unique or to survive a restart — a new session starts at
/// [initial] and every controller learns the new baseline from its first
/// snapshot.
class StateRevision extends Equatable implements Comparable<StateRevision> {
  const StateRevision(this.value) : assert(value >= 0);

  /// The revision a freshly started target session reports.
  static const StateRevision initial = StateRevision(0);

  final int value;

  StateRevision get next => StateRevision(value + 1);

  bool operator >(StateRevision other) => value > other.value;

  bool operator <(StateRevision other) => value < other.value;

  bool operator >=(StateRevision other) => value >= other.value;

  bool operator <=(StateRevision other) => value <= other.value;

  /// Parses the wire form. Returns `null` for anything that is not a
  /// non-negative integer.
  static StateRevision? tryParse(Object? value) {
    if (value is int) return value < 0 ? null : StateRevision(value);
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed == null || parsed < 0) return null;
      return StateRevision(parsed);
    }
    return null;
  }

  @override
  int compareTo(StateRevision other) => value.compareTo(other.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'r$value';
}
