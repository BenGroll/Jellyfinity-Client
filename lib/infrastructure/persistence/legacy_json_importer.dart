import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/logger.dart';
import 'database/app_database.dart';
import 'key_value_store.dart';

/// One-time import of v0.0.5's interim `servers.json` / `accounts.json`
/// files into the v0.0.6 database (ADR-0009 → ADR-0010).
///
/// Runs once at startup, before session restore. If the database already
/// holds servers it does nothing (fresh install, or a previous import). On
/// a successful import the source files are renamed to `*.migrated` rather
/// than deleted, so a botched migration can still be recovered by hand.
@lazySingleton
class LegacyJsonImporter {
  LegacyJsonImporter(this._db, this._keyValue, this._logger);

  final AppDatabase _db;
  final KeyValueStore _keyValue;
  final Logger _logger;

  /// The directory the legacy files live in — `path_provider`'s
  /// application-support directory in production (matching where
  /// `FileJsonStore` wrote them). Overridable for tests.
  Future<Directory> Function() directoryProvider =
      getApplicationSupportDirectory;

  static const _activeKey = 'session.active_account_id';

  Future<void> run() async {
    try {
      final alreadyHasData =
          await (_db.select(_db.savedServers)..limit(1)).getSingleOrNull() !=
          null;
      if (alreadyHasData) return;

      final Directory dir;
      try {
        dir = await directoryProvider();
      } on MissingPluginException {
        return; // no platform storage (e.g. a plain unit test) — nothing to do
      }

      final serversFile = File('${dir.path}/servers.json');
      final accountsFile = File('${dir.path}/accounts.json');
      if (!await serversFile.exists() && !await accountsFile.exists()) return;

      final servers = _readList(await _readJson(serversFile), 'servers');
      final accountsDoc = await _readJson(accountsFile);
      final accounts = _readList(accountsDoc, 'accounts');
      final activeId = accountsDoc['activeAccountId'];

      if (servers.isEmpty && accounts.isEmpty) return;

      var marker = DateTime.now().microsecondsSinceEpoch;
      await _db.transaction(() async {
        for (final entry in servers) {
          await _db
              .into(_db.savedServers)
              .insert(
                SavedServersCompanion.insert(
                  id: entry['id'] as String,
                  baseUrl: entry['baseUrl'] as String,
                  name: entry['name'] as String,
                  reportedVersion: Value(
                    entry['reportedVersion'] as String? ?? '',
                  ),
                  serverId: Value(entry['serverId'] as String?),
                  addedAt: marker++,
                ),
              );
        }
        for (final entry in accounts) {
          await _db
              .into(_db.savedAccounts)
              .insert(
                SavedAccountsCompanion.insert(
                  id: entry['id'] as String,
                  serverId: entry['serverId'] as String,
                  userId: entry['userId'] as String,
                  username: entry['username'] as String,
                  addedAt: marker++,
                ),
              );
        }
      });

      if (activeId is String && accounts.any((a) => a['id'] == activeId)) {
        await _keyValue.setString(_activeKey, activeId);
      }

      await _renameIfPresent(serversFile);
      await _renameIfPresent(accountsFile);

      _logger.info(
        'Imported ${servers.length} server(s) and ${accounts.length} '
        'profile(s) from the v0.0.5 JSON store.',
      );
    } catch (error, stackTrace) {
      // A failed import must never block startup — the user can re-add the
      // server. Leave the source files in place so it can be retried.
      _logger.warning(
        'Could not import the legacy JSON store; leaving it untouched.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, dynamic>> _readJson(File file) async {
    if (!await file.exists()) return const {};
    final raw = (await file.readAsString()).trim();
    if (raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  List<Map<String, dynamic>> _readList(Map<String, dynamic> doc, String key) {
    final raw = doc[key];
    return <Map<String, dynamic>>[
      if (raw is List)
        for (final entry in raw)
          if (entry is Map<String, dynamic>) entry,
    ];
  }

  Future<void> _renameIfPresent(File file) async {
    if (await file.exists()) await file.rename('${file.path}.migrated');
  }
}
