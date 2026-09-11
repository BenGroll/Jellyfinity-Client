import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../core/logging/Logger.dart';
import '../../domain/connectivity/OfflineMode.dart';
import '../../infrastructure/jellyfin/identity/JellyfinSessionContext.dart';
import '../../infrastructure/jellyfin/media/JellyfinFavoritesRepository.dart';
import '../../infrastructure/persistence/media/media_cache_store.dart';
import '../session/SessionCubit.dart';
import '../session/SessionState.dart';
import '../session/session_status.dart';
import 'FavoritesRevisionCubit.dart';

/// Replays a profile's offline favorite/unfavorite intents against the
/// server once it can be reached again (v0.4.3, ADR-0033).
///
/// `CachedFavoritesRepository` is the write side: offline, it records what
/// the user asked for in `pending_favorite_intents` (and mirrors it into
/// `cached_favorites` so every offline-facing read already agrees) instead
/// of attempting a request that can only fail. This is the other half —
/// started once at composition root (`bootstrap.dart`), it has no UI and
/// nothing calls it directly.
///
/// Two triggers, either of which can be the one that matters:
/// - [OfflineMode] flipping from offline to online — the ordinary "the
///   connection came back" case.
/// - [SessionCubit] reaching [SessionStatus.authenticated] — covers
///   restoring a session that was already online (no offline-to-online
///   transition ever fires), and switching to a different profile that
///   has its own pending intents.
///
/// Reconciliation only ever reads and writes the *currently active*
/// profile's intents (`JellyfinSessionContext`, re-read on every
/// iteration): switching accounts mid-flush stops the flush rather than
/// finishing it against the wrong session, so nothing here can leak a
/// change to a profile or server it was not meant for.
///
/// A failed replay (the server still rejects it, or the connection drops
/// again mid-flush) leaves the intent exactly where it was — retried on
/// the next trigger, and still reflected in `cached_favorites` in the
/// meantime, so the heart never goes back to lying about what the user
/// asked for.
@lazySingleton
class PendingFavoritesSync {
  PendingFavoritesSync(
    this._remote,
    this._cache,
    this._offline,
    this._context,
    this._session,
    this._revision,
    this._logger,
  );

  final JellyfinFavoritesRepository _remote;
  final MediaCacheStore _cache;
  final OfflineMode _offline;
  final JellyfinSessionContext _context;
  final SessionCubit _session;
  final FavoritesRevisionCubit _revision;
  final Logger _logger;

  StreamSubscription<OfflineStatus>? _offlineSub;
  StreamSubscription<SessionState>? _sessionSub;
  bool _reconciling = false;

  /// Wires the two triggers and attempts an immediate reconcile — the
  /// "app was already online when it restored a session with something
  /// still pending" case, which neither trigger's own transition covers.
  void start() {
    unawaited(_reconcile());
    _offlineSub = _offline.changes().listen((status) {
      if (!status.isOffline) unawaited(_reconcile());
    });
    _sessionSub = _session.stream.listen((state) {
      if (state.status == SessionStatus.authenticated) {
        unawaited(_reconcile());
      }
    });
  }

  Future<void> _reconcile() async {
    if (_reconciling) return;
    _reconciling = true;
    try {
      if (_offline.status.isOffline) return;
      final accountKey = _accountKey;
      if (accountKey == null) return;

      final pending = await _cache.pendingFavorites(accountKey);
      var reconciledAny = false;
      for (final intent in pending) {
        // Connectivity dropped, or the active profile changed, partway
        // through this batch: stop rather than keep writing against a
        // session this batch was never scoped to. The rest stay pending
        // for the next trigger.
        if (_offline.status.isOffline || _accountKey != accountKey) break;

        final result = await _remote.setFavorite(
          intent.id,
          favorite: intent.favorite,
          kind: intent.kind,
        );
        if (result.isOk) {
          await _cache.clearPendingFavorite(accountKey, intent.id);
          reconciledAny = true;
        } else {
          _logger.warning(
            'Could not sync a pending favorite; it remains pending: '
            '${result.failureOrNull?.message}',
          );
        }
      }
      if (reconciledAny) _revision.bump();
    } finally {
      _reconciling = false;
    }
  }

  /// `server_id/user_id`, or `null` with nobody signed in — see
  /// `CachedMusicLibraryRepository._accountKey`.
  String? get _accountKey {
    final serverId = _context.serverId;
    final userId = _context.userId;
    if (serverId == null || userId == null) return null;
    return '$serverId/$userId';
  }

  /// Cancels both triggers. `bootstrap.dart` never calls this — the
  /// singleton lives for the app's process, same as every other
  /// composition-root singleton started there — but a test that builds
  /// several of these in one run needs a way to stop an old one from
  /// still reacting.
  @visibleForTesting
  void dispose() {
    unawaited(_offlineSub?.cancel());
    unawaited(_sessionSub?.cancel());
  }
}
