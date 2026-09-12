import 'package:jellyfinity/domain/connected_playback/ElapsedClock.dart';

/// A monotonic clock the test moves by hand.
///
/// Everything in connected playback that depends on time — command
/// expiry, handoff step timeouts — is measured against an [ElapsedClock]
/// precisely so it can be tested like this: deterministically, in
/// microseconds, with no `Future.delayed` and no flake.
class FakeElapsedClock implements ElapsedClock {
  FakeElapsedClock([this._elapsed = Duration.zero]);

  Duration _elapsed;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration by) {
    assert(!by.isNegative, 'a monotonic clock never goes backwards');
    _elapsed += by;
  }
}
