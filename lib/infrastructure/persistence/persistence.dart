/// Jellyfinity's local-data layer (v0.0.6, ADR-0010).
///
/// SQLite via Drift ([AppDatabase]) is the foundation every later media
/// feature builds on. This milestone lands the schema, a forward-only
/// migration policy, the typed [KeyValueStore] for small non-sensitive
/// state, a persisted [DeviceIdentityStore], the database-backed
/// [ServerRegistry] / [AccountStore] that replace v0.0.5's interim JSON
/// files, and the one-time [LegacyJsonImporter].
///
/// v0.0.8 adds the media metadata cache ([MediaCacheStore], schema v2):
/// the local half of the read-through repositories ADR-0010 specified,
/// and what keeps a browsed music library browsable when the server stops
/// answering.
library;

export 'database/AppDatabase.dart';
export 'database/tables.dart';
export 'device_identity_store.dart';
export 'DriftAccountStore.dart';
export 'DriftServerRegistry.dart';
export 'key_value_store.dart';
export 'LegacyJsonImporter.dart';
export 'media/media_cache_store.dart';
export 'media/MediaCacheMapper.dart';
export 'media/MediaCollectionKey.dart';
