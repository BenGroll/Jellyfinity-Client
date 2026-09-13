import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../../core/logging/Logger.dart';
import '../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../infrastructure/jellyfin/connected/JellyfinSessionTransport.dart';
import '../platform/television_mode.dart';
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
  ConnectedPlaybackLink(this._transport, this._session, this._logger);

  final JellyfinSessionTransport _transport;
  final SessionCubit _session;
  final Logger _logger;

  StreamSubscription<SessionState>? _sessionUpdates;
  ConnectedPlaybackScope? _scope;
  bool _started = false;

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
    }
    // What this build actually executes when driven remotely (v0.5.3) —
    // see SupportedRemoteCommands for why it is narrower than
    // DeviceCapabilities.fullPlayer().
    _transport.capabilities = supportedRemoteCommands;

    WidgetsBinding.instance.addObserver(this);
    _sessionUpdates = _session.stream.listen(_onSession);
    await _apply(connectedPlaybackScopeOf(_session.state));
  }

  /// Releases both triggers and the link itself.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    await _sessionUpdates?.cancel();
    _sessionUpdates = null;
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
        // that is open.
        unawaited(_transport.resume());
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_transport.suspend());
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
