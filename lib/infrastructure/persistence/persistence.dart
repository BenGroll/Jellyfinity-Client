/// Jellyfinity's local-data layer (v0.0.6, ADR-0010).
///
/// SQLite via Drift ([AppDatabase]) is the foundation every later media
/// feature builds on. This milestone lands the schema, a forward-only
/// migration policy, the typed [KeyValueStore] for small non-sensitive
/// state, a persisted [DeviceIdentityStore], the database-backed
/// [ServerRegistry] / [AccountStore] that replace v0.0.5's interim JSON
/// files, and the one-time [LegacyJsonImporter].
///
/// Cache semantics and the local/remote repository-source conventions are
/// documented in ADR-0010; their concrete use arrives with the media
/// features in v0.0.7 and v0.0.8.
library;

export 'database/AppDatabase.dart';
export 'database/tables.dart';
export 'device_identity_store.dart';
export 'DriftAccountStore.dart';
export 'DriftServerRegistry.dart';
export 'key_value_store.dart';
export 'LegacyJsonImporter.dart';
