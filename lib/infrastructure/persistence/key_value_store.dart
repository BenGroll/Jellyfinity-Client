import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import 'database/app_database.dart';

/// Structured persistent storage for small, non-sensitive application
/// state: user preferences, the stable device id, the active-account
/// pointer (ADR-0010).
///
/// Values are typed at this boundary and stored as text underneath. This
/// is deliberately not a general settings framework — it is the one
/// primitive those concerns share. Secrets never go here (that is
/// `CredentialStore` / secure storage); large or relational data gets its
/// own table.
abstract class KeyValueStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<bool?> getBool(String key);

  Future<void> setBool(String key, bool value);

  Future<int?> getInt(String key);

  Future<void> setInt(String key, int value);

  Future<double?> getDouble(String key);

  Future<void> setDouble(String key, double value);

  /// Removes [key] if present. Safe to call when it is absent.
  Future<void> remove(String key);
}

/// [KeyValueStore] backed by the `key_value_entries` table.
@LazySingleton(as: KeyValueStore)
class DriftKeyValueStore implements KeyValueStore {
  DriftKeyValueStore(this._db);

  final AppDatabase _db;

  Future<String?> _read(String key) async {
    final row = await (_db.select(
      _db.keyValueEntries,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) {
    return _db
        .into(_db.keyValueEntries)
        .insert(
          KeyValueEntriesCompanion.insert(
            key: key,
            value: value,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          onConflict: DoUpdate(
            (_) => KeyValueEntriesCompanion.custom(
              value: Variable(value),
              updatedAt: Variable(DateTime.now().millisecondsSinceEpoch),
            ),
            target: [_db.keyValueEntries.key],
          ),
        );
  }

  @override
  Future<String?> getString(String key) => _read(key);

  @override
  Future<void> setString(String key, String value) => _write(key, value);

  @override
  Future<bool?> getBool(String key) async {
    final raw = await _read(key);
    return raw == null ? null : raw == 'true';
  }

  @override
  Future<void> setBool(String key, bool value) => _write(key, '$value');

  @override
  Future<int?> getInt(String key) async {
    final raw = await _read(key);
    return raw == null ? null : int.tryParse(raw);
  }

  @override
  Future<void> setInt(String key, int value) => _write(key, '$value');

  @override
  Future<double?> getDouble(String key) async {
    final raw = await _read(key);
    return raw == null ? null : double.tryParse(raw);
  }

  @override
  Future<void> setDouble(String key, double value) => _write(key, '$value');

  @override
  Future<void> remove(String key) async {
    await (_db.delete(
      _db.keyValueEntries,
    )..where((t) => t.key.equals(key))).go();
  }
}
