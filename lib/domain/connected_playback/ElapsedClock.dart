/// A monotonic, local elapsed-time source — the only clock connected
/// playback is allowed to make decisions with.
///
/// `Roadmap to v0.6.md` requires "clock-independent expiry", and it means
/// independent of the *wall* clock. Two Jellyfinity devices sharing a
/// self-hosted server have no reason to agree on the time of day: a Fire
/// TV that has been unplugged for a week comes back with a wrong date, a
/// phone crosses a timezone, a desktop corrects itself by NTP mid-session.
/// A command that carried "expires at 14:32:10" would be either
/// permanently expired or never expiring on such a peer, and the failure
/// would look like a network problem rather than a clock problem.
///
/// So a command carries a *lifetime* — a duration — and nothing else.
/// The receiver stamps arrival against its own [elapsed] and expires the
/// command from there. Both ends only ever compare two readings of their
/// own monotonic clock, which is the one comparison that stays true
/// across a clock correction, a timezone change and a device that thinks
/// it is 1970.
///
/// The cost is that a command's lifetime is measured from *arrival*
/// rather than from sending, so a message delayed in transit gets its
/// full budget at the target. That is the right trade for the thing
/// lifetimes protect against, which is a controller waiting forever on an
/// acknowledgement that is never coming; the controller applies its own
/// timeout against its own clock for that.
abstract class ElapsedClock {
  /// Time elapsed since an arbitrary fixed point in this process. Only
  /// differences between two readings are meaningful, and readings never
  /// go backwards.
  Duration get elapsed;
}

/// The production [ElapsedClock]: a [Stopwatch] started when the process
/// first needs one.
///
/// [Stopwatch] is backed by the platform's monotonic timer on every
/// target Jellyfinity supports, which is exactly the guarantee this seam
/// exists to state.
class StopwatchElapsedClock implements ElapsedClock {
  StopwatchElapsedClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;
}
