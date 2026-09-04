import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/session/AuthSession.dart';
import '../../infrastructure/jellyfin/server/JellyfinServerInfo.dart';
import 'AuthSessionManager.dart';
import 'SessionState.dart';
import 'session_status.dart';

/// The single source of navigational truth about the session, and the
/// router's `refreshListenable` source.
///
/// It is a thin orchestrator over [AuthSessionManager]: the manager does
/// the storage/credential/authentication work and returns values; this
/// cubit turns those into the [SessionState] the router and shell react
/// to. Feature cubits (server setup, login, accounts) call these methods
/// rather than touching the manager directly, so every top-level session
/// transition goes through one place.
///
/// Replaces the v0.0.3 stub referenced in ADR-0006; the router seam it
/// plugs into is unchanged.
@lazySingleton
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._sessions) : super(const SessionState.restoring());

  final AuthSessionManager _sessions;

  /// The active session, or `null` when signed out.
  AuthSession? get activeSession => state.session;

  /// Restores a saved session at startup. Does no network call, so it
  /// succeeds even if the last server is currently offline.
  Future<void> restore() async {
    emit(const SessionState.restoring());
    final restored = await _sessions.restore();
    emit(
      restored == null
          ? const SessionState.signedOut()
          : SessionState.signedIn(restored),
    );
  }

  /// Authenticates against an already-validated server and, on success,
  /// signs in. The [Result] is returned so the login screen can render
  /// the failure; the state change (and the router redirect) happens
  /// here.
  Future<Result<AuthSession>> logIn({
    required JellyfinServerInfo server,
    required String username,
    required String password,
  }) async {
    final result = await _sessions.logIn(
      validatedServer: server,
      username: username,
      password: password,
    );
    if (result case Ok<AuthSession>(:final value)) {
      emit(SessionState.signedIn(value));
    }
    return result;
  }

  /// Switches the active profile to an already-saved one.
  Future<Result<AuthSession>> switchTo(String accountId) async {
    final result = await _sessions.switchTo(accountId);
    if (result case Ok<AuthSession>(:final value)) {
      emit(SessionState.signedIn(value));
    }
    return result;
  }

  /// Signs out of the active profile (keeps it saved for next time).
  Future<void> signOut() async {
    await _sessions.logOut();
    emit(const SessionState.signedOut());
  }

  /// Called when a request comes back unauthorized: drops the session
  /// and routes back to sign-in, remembering the profile for a prefill.
  Future<void> handleUnauthorized() async {
    final accountId = state.session?.account.id;
    await _sessions.invalidateCurrent();
    emit(SessionState.signedOut(lastAccountId: accountId));
  }

  /// Removes a saved profile. Signs out first if it was the active one.
  Future<void> removeAccount(String accountId) async {
    final wasActive = state.session?.account.id == accountId;
    await _sessions.removeAccount(accountId);
    if (wasActive) emit(const SessionState.signedOut());
  }

  /// Removes a saved server and every profile on it. Signs out first if
  /// the active profile was one of them.
  Future<void> removeServer(String serverId) async {
    final wasActive = state.session?.server.id == serverId;
    await _sessions.removeServer(serverId);
    if (wasActive) emit(const SessionState.signedOut());
  }
}

/// Convenience for the router redirect and tests.
extension SessionCubitStatus on SessionCubit {
  SessionStatus get status => state.status;
}
