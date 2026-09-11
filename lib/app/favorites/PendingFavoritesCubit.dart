import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../infrastructure/jellyfin/identity/JellyfinSessionContext.dart';
import '../../infrastructure/persistence/media/media_cache_store.dart';

/// How many of the active profile's favorite toggles are still waiting to
/// reach the server (v0.4.3, ADR-0033).
class PendingFavoritesState extends Equatable {
  const PendingFavoritesState({this.count = 0});

  final int count;

  bool get hasPending => count > 0;

  @override
  List<Object?> get props => [count];
}

/// Backs the Favorites destination's "still syncing" note.
///
/// `CachedFavoritesRepository` and `PendingFavoritesSync` are the ones that
/// actually write and replay `pending_favorite_intents`; this only reads
/// its count, so a favorite toggled offline is never a silent, unexplained
/// promise (`CONTEXT.md`'s "never leave users guessing"). It refreshes on
/// [FavoritesRevisionCubit]'s bump — the same signal that already means
/// "something about favorites changed" for every other Favorites-adjacent
/// view.
@injectable
class PendingFavoritesCubit extends Cubit<PendingFavoritesState> {
  PendingFavoritesCubit(this._cache, this._context)
    : super(const PendingFavoritesState());

  final MediaCacheStore _cache;
  final JellyfinSessionContext _context;

  Future<void> refresh() async {
    final accountKey = _accountKey;
    if (accountKey == null) {
      emit(const PendingFavoritesState());
      return;
    }
    final pending = await _cache.pendingFavorites(accountKey);
    if (isClosed) return;
    emit(PendingFavoritesState(count: pending.length));
  }

  String? get _accountKey {
    final serverId = _context.serverId;
    final userId = _context.userId;
    if (serverId == null || userId == null) return null;
    return '$serverId/$userId';
  }
}
