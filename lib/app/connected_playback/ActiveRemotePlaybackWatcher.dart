import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../domain/connected_playback/ConnectedDevice.dart';
import '../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../domain/connected_playback/DevicePresenceSource.dart';
import '../../domain/connected_playback/device_reachability.dart';
import '../playback/PlaybackCubit.dart';
import '../session/SessionCubit.dart';
import '../session/SessionState.dart';
import 'ConnectedPlaybackScopeOf.dart';
import 'PlaybackControlCubit.dart';

/// Notices that another of this profile's devices is already playing, and
/// binds this app to it without the listener having to go and look
/// (v0.6.0).
///
/// The arc up to v0.5.9 could do everything except the first thing a
/// listener actually does: open the app somewhere else and expect it to
/// know what is going on. Control began at the device picker, so a phone
/// opened while the television was playing showed an empty player and a
/// sheet the listener had to think to open — the feature worked and was
/// invisible.
///
/// Deliberately a separate singleton rather than more behaviour inside
/// [PlaybackControlCubit]. That cubit's contract is "the device this app
/// is controlling, and the projection bound to it", and it follows
/// presence only for the device it already holds. Which device is *worth*
/// controlling is a different question, asked continuously and answered
/// from facts the cubit does not otherwise need — local playback, and the
/// whole roster. Keeping it out here also keeps it testable without a
/// widget: the rule is the class.
///
/// The rule, in full:
///
/// - Adopt only when this app is controlling nothing and playing nothing
///   itself. A listener with music coming out of the device in their hand
///   is not asking to be moved somewhere else.
/// - Adopt only a peer that is playing *and* ready — advertised, and
///   accepting commands. A device the server merely lists is not yet
///   something to bind a mini-player to.
/// - Adopt only when exactly one peer is playing. Two is a question the
///   listener has to answer, and picking one for them would be a guess
///   with a speaker attached.
/// - Never re-adopt a session the listener has already stopped
///   controlling. Their "no" holds for as long as that session keeps
///   playing; a new session, or that one stopping and starting again, is
///   a new question.
@lazySingleton
class ActiveRemotePlaybackWatcher {
  ActiveRemotePlaybackWatcher(
    this._presence,
    this._session,
    this._playback,
    this._control,
  );

  final DevicePresenceSource _presence;
  final SessionCubit _session;
  final PlaybackCubit _playback;
  final PlaybackControlCubit _control;

  StreamSubscription<SessionState>? _sessionUpdates;
  StreamSubscription<List<ConnectedDevice>>? _deviceUpdates;
  StreamSubscription<PlaybackControlState>? _controlUpdates;

  ConnectedPlaybackScope? _scope;
  bool _started = false;

  /// The session the listener stopped controlling, while it is still the
  /// one playing. Keyed by session rather than device so a peer that
  /// reconnects under a new session id asks again — the listener declined
  /// *that* playback, not that television for ever.
  String? _declinedSessionId;

  /// The session [PlaybackControlCubit] last reported controlling, so the
  /// moment controlling *ends* can be recognized — that transition is the
  /// listener's "no", and it is the only place it can be observed.
  String? _controlledSessionId;

  /// Wires the triggers and considers whatever is already there.
  ///
  /// Safe to call more than once, like [ConnectedPlaybackLink.start].
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _controlUpdates = _control.stream.listen(_onControlChanged);
    _sessionUpdates = _session.stream.listen(_onSession);
    _onSession(_session.state);
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _sessionUpdates?.cancel();
    _sessionUpdates = null;
    await _deviceUpdates?.cancel();
    _deviceUpdates = null;
    await _controlUpdates?.cancel();
    _controlUpdates = null;
    _scope = null;
    _declinedSessionId = null;
    _controlledSessionId = null;
  }

  void _onSession(SessionState state) {
    final scope = connectedPlaybackScopeOf(state);
    if (scope == _scope) return;
    _scope = scope;
    unawaited(_deviceUpdates?.cancel());
    _deviceUpdates = null;
    // A profile change is not a device the listener declined: the next
    // profile's devices have never been offered.
    _declinedSessionId = null;
    _controlledSessionId = null;
    if (scope == null) return;
    _deviceUpdates = _presence.devices(scope).listen(_onDevices);
  }

  /// Remembers a "no", so the next roster update does not immediately
  /// undo it.
  ///
  /// Controlling ending is the only observable form that "no" takes, and
  /// it means the same thing however the binding started: a listener who
  /// stops controlling the television — whether this watcher bound them
  /// to it or they chose it in the picker — is not asking to be bound
  /// straight back to the music that is still playing there.
  void _onControlChanged(PlaybackControlState state) {
    final previous = _controlledSessionId;
    _controlledSessionId = state.device?.sessionId;
    if (state.isControlling || previous == null) return;
    _declinedSessionId = previous;
  }

  void _onDevices(List<ConnectedDevice> devices) {
    final playing = devices
        .where((device) => !device.isThisDevice && device.isPlaying)
        .toList();

    // The listener's "no" expires with the playback it was about.
    final declined = _declinedSessionId;
    if (declined != null &&
        !playing.any((device) => device.sessionId == declined)) {
      _declinedSessionId = null;
    }

    if (_control.state.isControlling) return;
    if (_playback.state.isPlaying) return;
    if (playing.length != 1) return;

    final candidate = playing.single;
    if (candidate.sessionId == _declinedSessionId) return;
    if (candidate.reachability != DeviceReachability.ready) return;
    if (!candidate.capabilities.canPlay) return;

    unawaited(_control.control(candidate));
  }
}
