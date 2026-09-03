import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../domain/session/jellyfin_server.dart';
import '../../domain/session/server_registry.dart';
import 'database/app_database.dart';

/// [ServerRegistry] backed by the `saved_servers` table (ADR-0010).
///
/// Replaces v0.0.5's `FileServerRegistry` behind the same contract —
/// nothing above this interface changed. Rows are returned in the order
/// they were first saved (`addedAt`).
@LazySingleton(as: ServerRegistry)
class DriftServerRegistry implements ServerRegistry {
  DriftServerRegistry(this._db);

  final AppDatabase _db;

  @override
  Future<List<JellyfinServer>> all() async {
    final rows = await (_db.select(
      _db.savedServers,
    )..orderBy([(t) => OrderingTerm(expression: t.addedAt)])).get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<JellyfinServer?> byId(String id) async {
    final row = await (_db.select(
      _db.savedServers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<JellyfinServer?> byBaseUrl(String baseUrl) async {
    final row =
        await (_db.select(_db.savedServers)
              ..where((t) => t.baseUrl.equals(baseUrl))
              ..orderBy([(t) => OrderingTerm(expression: t.addedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(JellyfinServer server) async {
    final existing = await (_db.select(
      _db.savedServers,
    )..where((t) => t.id.equals(server.id))).getSingleOrNull();
    await _db
        .into(_db.savedServers)
        .insertOnConflictUpdate(
          SavedServersCompanion(
            id: Value(server.id),
            baseUrl: Value(server.baseUrl),
            name: Value(server.name),
            reportedVersion: Value(server.reportedVersion),
            serverId: Value(server.serverId),
            addedAt: Value(
              existing?.addedAt ?? DateTime.now().microsecondsSinceEpoch,
            ),
          ),
        );
  }

  @override
  Future<void> remove(String id) async {
    await (_db.delete(_db.savedServers)..where((t) => t.id.equals(id))).go();
  }

  static JellyfinServer _toDomain(SavedServerRow row) => JellyfinServer(
    id: row.id,
    baseUrl: row.baseUrl,
    name: row.name,
    reportedVersion: row.reportedVersion,
    serverId: row.serverId,
  );
}
