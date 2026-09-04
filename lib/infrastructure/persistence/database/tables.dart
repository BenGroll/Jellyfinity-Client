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

/// Media metadata Jellyfinity has already read from a server, kept so a
/// library the user has browsed stays browsable when the server does not
/// answer (ADR-0010's "persisted metadata" category, ROADMAP v0.0.8's
/// cached-browsing requirement).
///
/// One polymorphic table with a [kind] discriminator, mirroring how
/// Jellyfin models items and how `MediaItem` models them: per-type tables
/// would repeat the same six identity columns eight times and still need
/// a join to answer "what is this id". Columns a given kind does not have
/// stay null — a track has no production year, an artist has no duration.
///
/// Keyed by the pair `(server_id, item_id)`, because a Jellyfin item id
/// means nothing without the server that issued it (`MediaId`).
@DataClassName('CachedMediaItemRow')
class CachedMediaItems extends Table {
  /// Jellyfinity's local id for the server the item came from.
  TextColumn get serverId => text()();

  /// The item's id on that server.
  TextColumn get itemId => text()();

  /// `MediaKind.name` — how a row is turned back into the right entity.
  TextColumn get kind => text()();

  TextColumn get name => text()();

  /// `MediaAvailability.name` as the server reported it when the row was
  /// written. Preserves marks the server made (a missing episode); the
  /// "you are offline" downgrade is applied at read time, not stored.
  TextColumn get availability => text()();

  /// The artwork pointer, flattened. `image_item_id` is the item that
  /// *owns* the image, which for a song is its album.
  TextColumn get imageItemId => text().nullable()();
  TextColumn get imageKind => text().nullable()();
  TextColumn get imageTag => text().nullable()();
  RealColumn get imageAspectRatio => real().nullable()();

  /// Artist credits as a JSON array of `{name, id?}` objects.
  ///
  /// Credits are a display list read only with the item that owns them,
  /// never queried across items, so a join table would buy nothing and
  /// cost a query per row on a 130k-row table.
  TextColumn get artistsJson => text().nullable()();

  /// The album a track belongs to, kept as id *and* name so a cached
  /// track row renders without a second lookup.
  TextColumn get albumItemId => text().nullable()();
  TextColumn get albumName => text().nullable()();

  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();

  /// Running time in microseconds.
  IntColumn get durationMicros => integer().nullable()();

  IntColumn get productionYear => integer().nullable()();

  /// An album's track count or a playlist's item count, as reported.
  IntColumn get childCount => integer().nullable()();

  /// When this row was last written (milliseconds since epoch).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, itemId};
}

/// One collection Jellyfinity has read a window of — "this server's
/// albums", "that artist's tracks" — identified by [collectionKey], the
/// stable description of the query that produced it.
///
/// Holds what a cached read cannot reconstruct from the entries alone:
/// how long the collection is on the server, so paging out of the cache
/// ends where the real collection ends instead of where the cache does.
@DataClassName('CachedCollectionRow')
class CachedCollections extends Table {
  TextColumn get serverId => text()();

  /// The query in one string, e.g. `albums` or `tracks:album=<item id>`.
  TextColumn get collectionKey => text()();

  IntColumn get totalCount => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, collectionKey};
}

/// The order of a cached collection: which item sits at which index.
///
/// Ordering lives here rather than being recomputed from the items,
/// because the order is the *server's* (sort name, production year, disc
/// and track number, or a playlist's own arrangement) and Jellyfinity
/// must not invent its own version of it offline.
///
/// A row the server sent but Jellyfinity could not map keeps its place
/// with an [unavailableReason] instead of an item: dropping it would
/// shift every following track number by one.
@DataClassName('CachedCollectionEntryRow')
class CachedCollectionEntries extends Table {
  TextColumn get serverId => text()();
  TextColumn get collectionKey => text()();

  /// The entry's index within the whole collection, not within a window.
  IntColumn get position => integer()();

  /// The `CachedMediaItems` row this position points at.
  TextColumn get itemId => text()();

  /// Set when this position could not be turned into an item.
  TextColumn get unavailableReason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, collectionKey, position};
}
