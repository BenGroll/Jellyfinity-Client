import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../domain/session/account_store.dart';
import '../../domain/session/jellyfin_account.dart';
import 'database/app_database.dart';
import 'key_value_store.dart';

/// [AccountStore] backed by the `saved_accounts` table, with the
/// active-account pointer kept in `KeyValueStore` (ADR-0010).
///
/// Replaces v0.0.5's `FileAccountStore` behind the same contract. The
/// pointer lives in the key/value table rather than its own column because
/// it is a single app-wide value, not a per-row attribute.
@LazySingleton(as: AccountStore)
class DriftAccountStore implements AccountStore {
  DriftAccountStore(this._db, this._keyValue);

  final AppDatabase _db;
  final KeyValueStore _keyValue;

  static const _activeKey = 'session.active_account_id';

  @override
  Future<List<JellyfinAccount>> all() async {
    final rows = await (_db.select(
      _db.savedAccounts,
    )..orderBy([(t) => OrderingTerm(expression: t.addedAt)])).get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<JellyfinAccount>> forServer(String serverId) async {
    final rows =
        await (_db.select(_db.savedAccounts)
              ..where((t) => t.serverId.equals(serverId))
              ..orderBy([(t) => OrderingTerm(expression: t.addedAt)]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<JellyfinAccount?> byId(String id) async {
    final row = await (_db.select(
      _db.savedAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<JellyfinAccount?> byServerAndUser(
    String serverId,
    String userId,
  ) async {
    final row =
        await (_db.select(_db.savedAccounts)
              ..where(
                (t) => t.serverId.equals(serverId) & t.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(JellyfinAccount account) async {
    final existing = await (_db.select(
      _db.savedAccounts,
    )..where((t) => t.id.equals(account.id))).getSingleOrNull();
    await _db
        .into(_db.savedAccounts)
        .insertOnConflictUpdate(
          SavedAccountsCompanion(
            id: Value(account.id),
            serverId: Value(account.serverId),
            userId: Value(account.userId),
            username: Value(account.username),
            addedAt: Value(
              existing?.addedAt ?? DateTime.now().microsecondsSinceEpoch,
            ),
          ),
        );
  }

  @override
  Future<void> remove(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.savedAccounts)..where((t) => t.id.equals(id))).go();
      if (await activeAccountId() == id) {
        await _keyValue.remove(_activeKey);
      }
    });
  }

  @override
  Future<String?> activeAccountId() => _keyValue.getString(_activeKey);

  @override
  Future<void> setActiveAccountId(String? id) async {
    if (id == null) {
      await _keyValue.remove(_activeKey);
      return;
    }
    final exists = await (_db.select(
      _db.savedAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (exists == null) {
      throw ArgumentError.value(id, 'id', 'not a saved account');
    }
    await _keyValue.setString(_activeKey, id);
  }

  static JellyfinAccount _toDomain(SavedAccountRow row) => JellyfinAccount(
    id: row.id,
    serverId: row.serverId,
    userId: row.userId,
    username: row.username,
  );
}
