import 'package:drift/drift.dart';

/// The Jellyfin servers the user has saved (non-secret: an address and a
/// name). Mirrors `JellyfinServer` in the session domain; the mapping
/// lives in `DriftServerRegistry`.
@DataClassName('SavedServerRow')
class SavedServers extends Table {
  /// Jellyfinity's local id for the server (a UUID string).
  TextColumn get id => text()();

  /// The normalized base URL, as produced by `JellyfinServerUrl`.
  TextColumn get baseUrl => text()();

  /// Display name.
  TextColumn get name => text()();

  /// The Jellyfin version string seen at connection time.
  TextColumn get reportedVersion => text().withDefault(const Constant(''))();

  /// The server's self-reported Jellyfin id, if it gave one.
  TextColumn get serverId => text().nullable()();

  /// Monotonic insertion marker (microseconds since epoch at save time),
  /// so `all()` can return rows in the order they were first saved.
  IntColumn get addedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The saved profiles: one Jellyfin user signed in on one saved server.
/// Mirrors `JellyfinAccount`. Holds no token — that is the
/// `CredentialStore`'s job (secure storage), keyed by [id].
@DataClassName('SavedAccountRow')
class SavedAccounts extends Table {
  /// Jellyfinity's local id for the profile (a UUID string). Also the
  /// credential-store key for this account's token.
  TextColumn get id => text()();

  /// The local id of the `SavedServers` row this profile belongs to.
  ///
  /// Not a database foreign key: `AuthSessionManager` already orchestrates
  /// cascading removal (it also has to delete the token from secure
  /// storage, which the database cannot see), and a DB-level cascade would
  /// only duplicate that. Indexed for `forServer` lookups.
  TextColumn get serverId => text()();

  /// The Jellyfin user's id on that server.
  TextColumn get userId => text()();

  /// The Jellyfin username, shown in the account switcher.
  TextColumn get username => text()();

  /// Monotonic insertion marker; see [SavedServers.addedAt].
  IntColumn get addedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A small typed key/value table for structured non-sensitive application
/// state that does not warrant its own table: the stable device id, the
/// active-account pointer, and user preferences. Read through
/// `KeyValueStore` / `DeviceIdentityStore`, never directly by features.
@DataClassName('KeyValueRow')
class KeyValueEntries extends Table {
  TextColumn get key => text()();

  /// The value, always stored as text. Typed accessors on `KeyValueStore`
  /// encode/decode bools, ints and doubles.
  TextColumn get value => text()();

  /// When this entry was last written (milliseconds since epoch).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
