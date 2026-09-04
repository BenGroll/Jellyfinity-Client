import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/Logger.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../domain/session/session.dart';
import '../../infrastructure/jellyfin/server/JellyfinServerInfo.dart';

/// Mints the local ids Jellyfinity assigns to saved servers and profiles.
typedef LocalIdGenerator = String Function();

/// Owns the lifecycle of the active Jellyfin session: restore on startup,
/// log in, switch profile, log out, and forget saved identities.
///
/// It joins the three stores — [ServerRegistry] (non-secret),
/// [AccountStore] (non-secret + the active pointer), [CredentialStore]
/// (secure) — with the [JellyfinAuthenticator], and exposes the resolved
/// [AuthSession] for the current profile. Presentation talks to
/// `SessionCubit`, which drives this; the transport layer reads
/// [currentToken] through the `AuthTokenProvider` seam.
///
/// Deliberately holds no `Cubit`/stream itself — it is plain async logic
/// so it can be unit-tested without a widget tree, and so `SessionCubit`
/// stays the single source of navigational truth.
@lazySingleton
class AuthSessionManager {
  AuthSessionManager(
    this._servers,
    this._accounts,
    this._credentials,
    this._authenticator,
    this._logger,
  );

  final ServerRegistry _servers;
  final AccountStore _accounts;
  final CredentialStore _credentials;
  final JellyfinAuthenticator _authenticator;
  final Logger _logger;

  /// How new local ids are minted. A settable seam (like
  /// `JellyfinServerProbe.httpClientFactory`) so tests get deterministic
  /// ids without a DI-registered `Uuid`.
  @visibleForTesting
  LocalIdGenerator newId = () => const Uuid().v4();

  AuthSession? _current;

  /// The resolved session for the active profile, or `null` if signed
  /// out. Synchronous so the token provider can read it cheaply on every
  /// request.
  AuthSession? get current => _current;

  /// The active profile's access token, or `null`. The value the
  /// transport layer's `AuthTokenProvider` returns.
  String? get currentToken => _current?.accessToken;

  /// Rebuilds the active session from storage at startup.
  ///
  /// Does **no network call**: a stored token is trusted until a request
  /// actually comes back unauthorized (then [invalidateCurrent] runs).
  /// This is what lets the app launch straight into the shell even when
  /// the last server is currently offline.
  ///
  /// Returns the restored session, or `null` if there is no active
  /// profile or its data is incomplete (in which case the active pointer
  /// is cleared).
  Future<AuthSession?> restore() async {
    final activeId = await _accounts.activeAccountId();
    if (activeId == null) return null;

    final account = await _accounts.byId(activeId);
    final server = account == null
        ? null
        : await _servers.byId(account.serverId);
    final token = account == null
        ? null
        : await _credentials.readToken(account.id);

    if (account == null || server == null || token == null || token.isEmpty) {
      _logger.warning(
        'Active profile could not be fully restored; signing out.',
      );
      await _accounts.setActiveAccountId(null);
      _current = null;
      return null;
    }

    _current = AuthSession(
      account: account,
      server: server,
      accessToken: token,
    );
    return _current;
  }

  /// Authenticates [username]/[password] against a server the caller has
  /// already validated with `JellyfinServerProbe` (hence the transport
  /// [JellyfinServerInfo]), then persists the server, the profile, and
  /// the token, and makes it active.
  Future<Result<AuthSession>> logIn({
    required JellyfinServerInfo validatedServer,
    required String username,
    required String password,
  }) async {
    // Reuse the saved server entry for this address if there is one,
    // otherwise mint a fresh local id for it.
    final existingServer = await _servers.byBaseUrl(validatedServer.baseUrl);
    final server =
        (existingServer ??
                JellyfinServer(
                  id: newId(),
                  baseUrl: validatedServer.baseUrl,
                  name: _serverName(validatedServer),
                  reportedVersion: validatedServer.version.toString(),
                  serverId: validatedServer.serverId,
                ))
            .copyWith(
              name: _serverName(validatedServer),
              reportedVersion: validatedServer.version.toString(),
              serverId: validatedServer.serverId,
            );

    final authResult = await _authenticator.authenticate(
      server: server,
      username: username,
      password: password,
    );

    if (authResult case Err<AuthenticatedUser>(:final failure)) {
      return Result.err(failure);
    }
    final authed = (authResult as Ok<AuthenticatedUser>).value;

    await _servers.save(server);

    final existingAccount = await _accounts.byServerAndUser(
      server.id,
      authed.userId,
    );
    final account =
        existingAccount?.copyWith(username: authed.username) ??
        JellyfinAccount(
          id: newId(),
          serverId: server.id,
          userId: authed.userId,
          username: authed.username,
        );

    await _accounts.save(account);
    await _credentials.writeToken(account.id, authed.accessToken);
    await _accounts.setActiveAccountId(account.id);

    _current = AuthSession(
      account: account,
      server: server,
      accessToken: authed.accessToken,
    );
    return Result.ok(_current!);
  }

  /// Makes the already-saved profile [accountId] the active one, loading
  /// its token from secure storage.
  Future<Result<AuthSession>> switchTo(String accountId) async {
    final account = await _accounts.byId(accountId);
    final server = account == null
        ? null
        : await _servers.byId(account.serverId);
    final token = account == null
        ? null
        : await _credentials.readToken(account.id);

    if (account == null || server == null || token == null || token.isEmpty) {
      return const Result.err(
        UnavailableFailure('That profile is no longer available.'),
      );
    }

    await _accounts.setActiveAccountId(account.id);
    _current = AuthSession(
      account: account,
      server: server,
      accessToken: token,
    );
    return Result.ok(_current!);
  }

  /// Signs out of the active profile: clears the active pointer and
  /// deletes its stored token, but keeps the saved server and profile so
  /// signing back in only needs the password.
  Future<void> logOut() async {
    final account = _current?.account ?? await _activeAccount();
    if (account != null) {
      await _credentials.deleteToken(account.id);
    }
    await _accounts.setActiveAccountId(null);
    _current = null;
  }

  /// Drops the in-memory session without touching storage — used when a
  /// request comes back unauthorized, so the router sends the user back
  /// to sign in while the saved profile (for a prefilled username) stays.
  Future<void> invalidateCurrent() async {
    final account = _current?.account;
    if (account != null) {
      await _credentials.deleteToken(account.id);
    }
    await _accounts.setActiveAccountId(null);
    _current = null;
  }

  /// Removes a saved profile and its token. If it was active, signs out.
  Future<void> removeAccount(String accountId) async {
    await _credentials.deleteToken(accountId);
    await _accounts.remove(accountId);
    if (_current?.account.id == accountId) _current = null;
  }

  /// Removes a saved server, every profile on it, and their tokens. If
  /// the active profile was on that server, signs out.
  Future<void> removeServer(String serverId) async {
    for (final account in await _accounts.forServer(serverId)) {
      await _credentials.deleteToken(account.id);
      await _accounts.remove(account.id);
      if (_current?.account.id == account.id) _current = null;
    }
    await _servers.remove(serverId);
  }

  Future<JellyfinAccount?> _activeAccount() async {
    final id = await _accounts.activeAccountId();
    return id == null ? null : _accounts.byId(id);
  }

  /// A display name for a validated server: its self-reported name, or the
  /// host from its address as a fallback.
  static String _serverName(JellyfinServerInfo info) {
    final reported = info.serverName?.trim();
    if (reported != null && reported.isNotEmpty) return reported;
    return Uri.tryParse(info.baseUrl)?.host ?? info.baseUrl;
  }
}
