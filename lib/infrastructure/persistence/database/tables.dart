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

/// Jellyfinity's own playback queue (ADR-0013), schema v3.
///
/// Unlike [CachedCollectionEntries] this does not join against
/// [CachedMediaItems]: a queued track is not guaranteed to have come
/// through a cached collection window (music-scoped search results are
/// never cached, per ADR-0012), so every row carries its own denormalized
/// display fields. A queue restored after a restart renders with zero
/// network calls, which is what `Track.dart`'s own v0.0.7 doc comment
/// asked for.
///
/// Scalar queue state — current index, shuffle, repeat mode, last
/// position — lives in `KeyValueEntries` instead of here; it is exactly
/// the small structured app state that store already exists for.
@DataClassName('QueueEntryRow')
class QueueEntries extends Table {
  /// The entry's position in the queue's own (non-shuffled) order.
  IntColumn get position => integer()();

  TextColumn get serverId => text()();
  TextColumn get itemId => text()();

  TextColumn get title => text()();

  /// The joined artist credit line, already formatted for display.
  TextColumn get artist => text().nullable()();
  TextColumn get albumName => text().nullable()();
  IntColumn get durationMicros => integer().nullable()();

  TextColumn get imageItemId => text().nullable()();
  TextColumn get imageKind => text().nullable()();
  TextColumn get imageTag => text().nullable()();
  RealColumn get imageAspectRatio => real().nullable()();

  /// `MediaAvailability.name`. Carries a `remoteUnavailable` mark
  /// (`PlaybackEngine.failureStream`) forward across a restart, so a
  /// track that failed before the app closed is still shown as
  /// unavailable rather than looking playable again.
  TextColumn get availability =>
      text().withDefault(const Constant('remoteOnly'))();

  @override
  Set<Column<Object>> get primaryKey => {position};
}

/// The tracks Jellyfinity has been asked to keep on this device (v0.2.0,
/// ADR-0020), schema v4.
///
/// Like [QueueEntries] and for the same reason, this does not join
/// against [CachedMediaItems]: a downloaded track has to render and be
/// queueable with the server switched off, and the metadata cache is a
/// cache — it can be evicted, and it is never guaranteed to have seen the
/// track at all (a song downloaded from search results was never part of
/// a cached collection window). So every row carries its own denormalized
/// display fields, and a download survives the cache being cleared.
///
/// Keyed by `(server_id, item_id)` like every other media table: the
/// same song on two servers is two downloads.
@DataClassName('TrackDownloadRow')
class TrackDownloads extends Table {
  TextColumn get serverId => text()();
  TextColumn get itemId => text()();

  /// `DownloadState.name`.
  TextColumn get state => text()();

  /// `DownloadFailureReason.name`, set only for a failed row.
  TextColumn get failureReason => text().nullable()();

  /// Bytes on the device so far, so a resumed transfer reports honest
  /// progress after a restart instead of starting its bar at zero.
  IntColumn get receivedBytes => integer().withDefault(const Constant(0))();

  /// The file's full size once the server has reported one; null while
  /// that is still unknown.
  IntColumn get totalBytes => integer().nullable()();

  // --- Denormalized track metadata, mirroring QueueEntries. ---

  TextColumn get title => text()();

  /// Artist credits as a JSON array of `{name, id?}` objects, encoded the
  /// same way [CachedMediaItems.artistsJson] encodes them.
  TextColumn get artistsJson => text().nullable()();

  TextColumn get albumItemId => text().nullable()();
  TextColumn get albumName => text().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get durationMicros => integer().nullable()();
  RealColumn get normalizationGain => real().nullable()();

  TextColumn get imageItemId => text().nullable()();
  TextColumn get imageKind => text().nullable()();
  TextColumn get imageTag => text().nullable()();
  RealColumn get imageAspectRatio => real().nullable()();

  /// When the download was first requested (microseconds since epoch).
  /// This is the *order*: the engine takes pending downloads oldest
  /// first, so a long album does not overtake a song asked for before
  /// it. A monotonic insertion marker, like [SavedServers.addedAt].
  IntColumn get requestedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, itemId};
}

/// Why each downloaded file is being kept: one row per reason.
///
/// The same song can be wanted by the song itself and by its album; in
/// v0.2.1 and v0.2.2 a playlist and an artist join them. Removing one
/// target deletes that target's rows and only then, if a track has no
/// rows left, deletes the file — which is what stops "remove this album"
/// from taking away a song the user downloaded on its own.
///
/// Not a database foreign key onto [TrackDownloads], for the same reason
/// [SavedAccounts.serverId] is not one: the delete has to remove a file
/// as well as rows, so it is orchestrated in one place rather than half
/// here and half in a cascade the code cannot see.
@DataClassName('DownloadOwnerRow')
class DownloadOwners extends Table {
  TextColumn get serverId => text()();

  /// The downloaded track's item id.
  TextColumn get itemId => text()();

  /// `DownloadOwnerKind.name` — `track` or `album` today.
  TextColumn get ownerKind => text()();

  /// The owning item's id on the same server (the track's own id for a
  /// `track` owner, the album's for an `album` owner).
  TextColumn get ownerItemId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    serverId,
    itemId,
    ownerKind,
    ownerItemId,
  };
}
