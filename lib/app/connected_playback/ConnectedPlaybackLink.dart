import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../../core/logging/Logger.dart';
import '../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../infrastructure/jellyfin/connected/JellyfinSessionTransport.dart';
import '../platform/television_display_monitor.dart';
import '../platform/television_mode.dart';
import '../playback/PlaybackCubit.dart';
import '../playback/PlaybackUiState.dart';
import '../session/SessionCubit.dart';
import '../session/SessionState.dart';
import 'ConnectedPlaybackScopeOf.dart';
import 'SupportedRemoteCommands.dart';

/// Keeps the connected-playback link in step with the two things that
/// decide whether there should be one: who is signed in, and whether this
/// app is running.
///
/// It lives in `lib/app` rather than beside the transport because both
/// triggers do — `SessionCubit` is the single source of truth about the
/// active profile, and `AppLifecycleState` is Flutter's, and the
/// infrastructure layer may depend on neither. Started once at the
/// composition root, like `PendingFavoritesSync`; nothing calls it
/// directly and it has no UI of its own.
///
/// The session rule is the one that carries the isolation invariant. A
/// profile change is never a reconfiguration of the existing link: the
/// old scope is torn down, including everything known about its devices,
/// before the new one is advertised. Logging out, switching accounts and
/// removing the server all arrive here as the same event — the active
/// scope changed — which is what keeps them from being three chances to
/// forget one of them.
@lazySingleton
class ConnectedPlaybackLink with WidgetsBindingObserver {
  ConnectedPlaybackLink(
    this._transport,
    this._session,
    this._playback,
    this._logger,
  );

  final JellyfinSessionTransport _transport;
  final SessionCubit _session;
  final PlaybackCubit _playback;
  final Logger _logger;

  StreamSubscription<SessionState>? _sessionUpdates;
  StreamSubscription<PlaybackUiState>? _playbackUpdates;
  StreamSubscription<bool>? _televisionDisplayUpdates;
  ConnectedPlaybackScope? _scope;
  bool _started = false;

  /// Mirrors `AppLifecycleState`, not `_transport`'s own suspended flag:
  /// this device may stay backgrounded and playing (Android's foreground
  /// service, ADR-0013) for a long time, and [_onPlaybackChanged] needs
  /// to know whether a status change happened while backgrounded without
  /// asking the transport to infer it from its own connection state.
  /// Whether the Android host's display just reported itself off.
  ///
  /// Only ever set on a television (ADR-0036): a television going to
  /// sleep does not reliably change `AppLifecycleState` the way
  /// backgrounding a phone does, so this is a second, independent signal
  /// `_reconcileBackgroundConnection` checks first — an asleep television
  /// expires as a target regardless of whether it is
  /// still playing (v0.5.9).
  bool _televisionAsleep = false;

  /// Wires both triggers and links the profile that is already active.
  ///
  /// Safe to call more than once; a second call is a no-op rather than a
  /// second observer.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // A television is a capability of the Android host (ADR-0036), not
    // something the transport can work out from `dart:io`, and it is the
    // distinction most worth showing beside two devices the listener gave
    // the same name.
    if (await TelevisionModeDetector.detect()) {
      _transport.platformName = 'Fire TV';
      // Only a television needs its display's power state watched: a
      // phone or desktop backgrounding is already what
      // `didChangeAppLifecycleState` reconciles against (v0.5.9).
      _televisionDisplayUpdates = TelevisionDisplayMonitor.screenOnChanges
          .listen(_onTelevisionDisplayChanged);
    }
    // What this build actually executes when driven remotely (v0.5.3) —
    // see SupportedRemoteCommands for why it is narrower than
    // DeviceCapabilities.fullPlayer().
    _transport.capabilities = supportedRemoteCommands;

    WidgetsBinding.instance.addObserver(this);
    _sessionUpdates = _session.stream.listen(_onSession);
    _playbackUpdates = _playback.stream.listen(_onPlaybackChanged);
    await _apply(connectedPlaybackScopeOf(_session.state));
  }

  /// Releases both triggers and the link itself.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    await _sessionUpdates?.cancel();
    _sessionUpdates = null;
    await _playbackUpdates?.cancel();
    _playbackUpdates = null;
    await _televisionDisplayUpdates?.cancel();
    _televisionDisplayUpdates = null;
    final scope = _scope;
    _scope = null;
    if (scope != null) await _transport.clear(scope);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Returning to the foreground always re-establishes rather than
        // assuming the socket survived: the app may have been away for a
        // day, and a socket that is open but dead looks exactly like one
        // that is open. A no-op when playback kept it alive in the
        // background (below): [JellyfinSessionTransport.resume] only acts
        // on a suspended or missing socket. Skipped while an asleep
        // television's own signal still says it is asleep — a `resumed`
        // callback racing or preceding `ACTION_SCREEN_ON` must not
        // reconnect a target that is still dark (v0.5.9).
        if (!_televisionAsleep) unawaited(_transport.resume());
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _reconcileBackgroundConnection();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Transient on both required platforms — a notification shade, a
        // window losing focus — and dropping the socket for either would
        // cost a reconnect for nothing.
        break;
    }
  }

  void _onSession(SessionState state) =>
      unawaited(_apply(connectedPlaybackScopeOf(state)));

  /// Reconciles a television's own display power state (v0.5.9).
  ///
  /// A television going to sleep does not reliably pause the Flutter
  /// `Activity` the way backgrounding a phone does — the app can stay
  /// `resumed` with the screen simply dark — so `_backgrounded` alone
  /// would never notice. Falling asleep expires this device as a target
  /// immediately, regardless of `_backgrounded` or whether it is still
  /// playing: nobody is watching or listening to an asleep television, so
  /// unlike a phone (v0.5.8) there is no case where staying reachable
  /// while asleep is the right call.
  ///
  /// Waking does not imply the app also came back to the foreground, so
  /// it defers to whichever rule already applies rather than always
  /// calling [JellyfinSessionTransport.resume] itself: doing both would
  /// race resume's asynchronous reconnect against a reconcile that might
  /// decide to suspend again, and either could win. Backgrounded defers
  /// to [_reconcileBackgroundConnection] (its own playing check decides);
  /// still in the foreground resumes directly, the same call
  /// [didChangeAppLifecycleState]'s `resumed` case makes.
  void _onTelevisionDisplayChanged(bool screenOn) {
    _televisionAsleep = !screenOn;
    if (_televisionAsleep) {
      unawaited(_transport.suspend());
    } else {
      unawaited(_transport.resume());
    }
  }

  /// Keeps a signed-in device reachable as a remote target while it is
  /// backgrounded. Selecting another device to browse the Remote screen
  /// must not make this idle target disappear behind a presence-only row.
  ///
  /// A television whose display is asleep remains the one exception: it is
  /// deliberately unavailable until the display wakes.
  void _reconcileBackgroundConnection() {
    if (_televisionAsleep) unawaited(_transport.suspend());
  }

  void _onPlaybackChanged(PlaybackUiState state) =>
      _reconcileBackgroundConnection();

  Future<void> _apply(ConnectedPlaybackScope? scope) async {
    if (scope == _scope) return;
    final previous = _scope;
    _scope = scope;
    if (previous != null) await _transport.clear(previous);
    if (scope == null) return;

    final result = await _transport.advertise(scope);
    if (result.isErr) {
      // Not surfaced here: a picker that nobody has opened has nowhere to
      // show this, and the link state the transport publishes already
      // says what happened for the screens that will (v0.5.5).
      _logger.info(
        'Connected playback is not available yet: '
        '${result.failureOrNull!.message}',
      );
    }
  }
}
