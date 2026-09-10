import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/logging/Logger.dart';
import '../../core/result/result.dart';
import '../../domain/downloads/DownloadStore.dart';
import '../../domain/session/AuthSession.dart';
import '../../infrastructure/downloads/DownloadStorage.dart';
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
  SessionCubit(
    this._sessions,
    this._downloadStore,
    this._downloadStorage,
    this._logger,
  ) : super(const SessionState.restoring());

  final AuthSessionManager _sessions;

  /// Removing a saved profile or server reclaims its downloaded files
  /// (v0.3.6): records and files that name an identity the app no longer
  /// has are dead storage nothing can reach or play. Lives here rather
  /// than in [AuthSessionManager] because the store reads the session
  /// context, and that context reads the manager — a DI cycle.
  final DownloadStore _downloadStore;
  final DownloadStorage _downloadStorage;
  final Logger _logger;

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

  /// Removes a saved profile. Signs out first if it was the active one,
  /// and reclaims its downloaded files (v0.3.6).
  Future<void> removeAccount(String accountId) async {
    final wasActive = state.session?.account.id == accountId;
    final removed = await _sessions.removeAccount(accountId);
    if (wasActive) emit(const SessionState.signedOut());
    if (removed != null) {
      await _reclaimAccountDownloads(removed.serverId, removed.userId);
    }
  }

  /// Removes a saved server and every profile on it. Signs out first if
  /// the active profile was one of them, and reclaims every download for
  /// that server (v0.3.6).
  Future<void> removeServer(String serverId) async {
    final wasActive = state.session?.server.id == serverId;
    await _sessions.removeServer(serverId);
    if (wasActive) emit(const SessionState.signedOut());
    await _reclaimServerDownloads(serverId);
  }

  /// Forgets one removed profile's download records and deletes any file
  /// no surviving profile on the same server still keeps — the file
  /// directory is shared per server, not per profile.
  Future<void> _reclaimAccountDownloads(String serverId, String userId) async {
    final purged = await _downloadStore.purgeProfile(
      serverId: serverId,
      userId: userId,
    );
    switch (purged) {
      case Ok(:final value):
        for (final id in value) {
          await _downloadStorage.discard(id);
        }
      case Err(:final failure):
        _logger.warning(
          "Could not fully reclaim a removed profile's downloads: "
          '${failure.message}',
        );
    }
  }

  /// Forgets every download record for a removed server and deletes its
  /// files wholesale — no reference counting, since every profile on the
  /// server went with it.
  Future<void> _reclaimServerDownloads(String serverId) async {
    final purged = await _downloadStore.purgeServer(serverId);
    if (purged case Err(:final failure)) {
      _logger.warning(
        "Could not clear a removed server's download records: "
        '${failure.message}',
      );
    }
    await _downloadStorage.discardServer(serverId);
  }
}

/// Convenience for the router redirect and tests.
extension SessionCubitStatus on SessionCubit {
  SessionStatus get status => state.status;
}
