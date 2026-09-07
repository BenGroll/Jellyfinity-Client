import 'package:drift/drift.dart';

import 'tables.dart';

part 'AppDatabase.g.dart';

/// Jellyfinity's local database (ADR-0010).
///
/// SQLite via Drift. This is the foundational local-data store every later
/// media feature builds on: cached metadata, user-authored local state,
/// and (from v0.0.5's session work) the saved servers and profiles.
///
/// ## Schema versioning
///
/// [schemaVersion] starts at 1. Every schema change bumps it by one and
/// adds a step to [MigrationStrategy.onUpgrade] — the database is never
/// dropped and recreated on upgrade. The committed schema snapshots under
/// `drift_schemas/` are the reference for what each version looks like;
/// regenerate with `dart run drift_dev schema dump` after a schema change
/// and add a matching migration test.
///
/// ## Construction
///
/// Production wiring opens a lazily-resolved on-disk database (see
/// `DatabaseModule`). Tests construct `AppDatabase(NativeDatabase.memory())`
/// directly, so the suite never touches a platform channel or a real file.
@DriftDatabase(
  tables: [
    SavedServers,
    SavedAccounts,
    KeyValueEntries,
    CachedMediaItems,
    CachedCollections,
    CachedCollectionEntries,
    QueueEntries,
    TrackDownloads,
    DownloadOwners,
    PlaylistDownloadMembers,
    DownloadedCollections,
    ListeningHistoryEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await m.createIndex(_savedAccountsServerIdIndex);
      await m.createIndex(_savedServersBaseUrlIndex);
      await m.createIndex(_downloadOwnersOwnerIndex);
      await m.createIndex(_playlistDownloadMembersPlaylistIndex);
      await m.createIndex(_trackDownloadsAccountIndex);
      await m.createIndex(_downloadedCollectionsAccountIndex);
      await m.createIndex(_listeningHistoryAccountIndex);
    },
    onUpgrade: (m, from, to) async {
      // v2 (v0.0.8): the media metadata cache. Purely additive — three
      // new tables, nothing existing touched, so an install upgrading
      // from v1 keeps its saved servers, profiles and preferences and
      // simply starts with an empty cache.
      if (from < 2) {
        await m.createTable(cachedMediaItems);
        await m.createTable(cachedCollections);
        await m.createTable(cachedCollectionEntries);
      }
      // v3 (v0.0.9): the playback queue. Also purely additive — an
      // install upgrading from v1 or v2 starts with an empty queue.
      //
      // Frozen at its v3 shape rather than built from the live definition:
      // v0.3.1 (v7) adds two columns to `queue_entries`, and a v2 -> v3
      // step must still produce exactly the v3 schema. The v7 step below
      // brings it up to date, the same treatment v0.2.3 gave the download
      // tables (ADR-0023).
      if (from < 3) {
        await m.database.customStatement(_createQueueEntriesV3);
      }
      // v4 (v0.2.0): downloads. Additive again — the two new tables
      // start empty, so an upgrading install keeps everything it had
      // and simply has nothing downloaded yet.
      //
      // These two `CREATE TABLE`s are frozen at their v4 shape rather
      // than built from the current definitions: v0.2.3 (v6) adds
      // columns to both, and a v3 -> v4 step must still produce exactly
      // the v4 schema. The v6 step below brings them up to date.
      if (from < 4) {
        await m.database.customStatement(_createTrackDownloadsV4);
        await m.database.customStatement(_createDownloadOwnersV4);
        await m.createIndex(_downloadOwnersOwnerIndex);
      }
      // v5 (v0.2.1): playlist download membership snapshots. One new
      // table, still additive — an upgrading install has every track and
      // album download it had, and simply no playlist snapshots yet.
      // Frozen at its v5 shape for the same reason as the v4 tables.
      if (from < 5) {
        await m.database.customStatement(_createPlaylistDownloadMembersV5);
        await m.createIndex(_playlistDownloadMembersPlaylistIndex);
      }
      // v6 (v0.2.3): per-profile downloads and downloaded-collection
      // identity. `track_downloads`, `download_owners` and
      // `playlist_download_members` each gain an `account_key` in their
      // primary key (and `track_downloads` a `server_gone` flag) so one
      // profile never sees, plays or removes another profile's
      // downloads. Every pre-v6 row keeps its data with an empty key,
      // which `DownloadsCubit.restore` then claims for the first profile
      // to sign in — the pre-v6 "one shared bucket" behaviour, carried
      // forward. `downloaded_collections` is new and starts empty; a
      // collection's name and artwork fill in the next time it is
      // downloaded or opened online.
      if (from < 6) {
        await m.alterTable(
          TableMigration(
            trackDownloads,
            newColumns: [trackDownloads.accountKey, trackDownloads.serverGone],
          ),
        );
        await m.alterTable(
          TableMigration(
            downloadOwners,
            newColumns: [downloadOwners.accountKey],
          ),
        );
        await m.alterTable(
          TableMigration(
            playlistDownloadMembers,
            newColumns: [playlistDownloadMembers.accountKey],
          ),
        );
        await m.createTable(downloadedCollections);
        // Recreating a table drops its indexes, so re-create the two the
        // alterTable calls above just cleared, plus the new v0.2.3 ones.
        await m.createIndex(_downloadOwnersOwnerIndex);
        await m.createIndex(_playlistDownloadMembersPlaylistIndex);
        await m.createIndex(_trackDownloadsAccountIndex);
        await m.createIndex(_downloadedCollectionsAccountIndex);
      }
      // v7 (v0.3.1): listening history, and the two ids the queue snapshot
      // was missing. `queue_entries` gains `artists_json` and
      // `album_item_id` (both nullable) so a queued or restored track can
      // open its artist and album; every pre-v7 row keeps its data with
      // those null. `listening_history_entries` is new and starts empty —
      // history begins accruing from the next qualifying play.
      if (from < 7) {
        await m.alterTable(
          TableMigration(
            queueEntries,
            newColumns: [queueEntries.artistsJson, queueEntries.albumItemId],
          ),
        );
        await m.createTable(listeningHistoryEntries);
        await m.createIndex(_listeningHistoryAccountIndex);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The v4 shape of `track_downloads`, frozen so the v3 -> v4 step
  /// produces exactly what schema v4 committed even though v6 adds
  /// columns to the live definition.
  static const String _createTrackDownloadsV4 =
      'CREATE TABLE IF NOT EXISTS "track_downloads" ('
      '"server_id" TEXT NOT NULL, '
      '"item_id" TEXT NOT NULL, '
      '"state" TEXT NOT NULL, '
      '"failure_reason" TEXT NULL, '
      '"received_bytes" INTEGER NOT NULL DEFAULT 0, '
      '"total_bytes" INTEGER NULL, '
      '"title" TEXT NOT NULL, '
      '"artists_json" TEXT NULL, '
      '"album_item_id" TEXT NULL, '
      '"album_name" TEXT NULL, '
      '"track_number" INTEGER NULL, '
      '"disc_number" INTEGER NULL, '
      '"duration_micros" INTEGER NULL, '
      '"normalization_gain" REAL NULL, '
      '"image_item_id" TEXT NULL, '
      '"image_kind" TEXT NULL, '
      '"image_tag" TEXT NULL, '
      '"image_aspect_ratio" REAL NULL, '
      '"requested_at" INTEGER NOT NULL, '
      'PRIMARY KEY ("server_id", "item_id"))';

  /// The v3 shape of `queue_entries`, frozen so the v2 -> v3 step produces
  /// exactly what schema v3 committed even though v7 adds columns to the
  /// live definition (see [_createTrackDownloadsV4]).
  static const String _createQueueEntriesV3 =
      'CREATE TABLE IF NOT EXISTS "queue_entries" ('
      '"position" INTEGER NOT NULL, '
      '"server_id" TEXT NOT NULL, '
      '"item_id" TEXT NOT NULL, '
      '"title" TEXT NOT NULL, '
      '"artist" TEXT NULL, '
      '"album_name" TEXT NULL, '
      '"duration_micros" INTEGER NULL, '
      '"image_item_id" TEXT NULL, '
      '"image_kind" TEXT NULL, '
      '"image_tag" TEXT NULL, '
      '"image_aspect_ratio" REAL NULL, '
      '"availability" TEXT NOT NULL DEFAULT \'remoteOnly\', '
      'PRIMARY KEY ("position"))';

  /// The v4 shape of `download_owners`, frozen (see
  /// [_createTrackDownloadsV4]).
  static const String _createDownloadOwnersV4 =
      'CREATE TABLE IF NOT EXISTS "download_owners" ('
      '"server_id" TEXT NOT NULL, '
      '"item_id" TEXT NOT NULL, '
      '"owner_kind" TEXT NOT NULL, '
      '"owner_item_id" TEXT NOT NULL, '
      'PRIMARY KEY ("server_id", "item_id", "owner_kind", "owner_item_id"))';

  /// The v5 shape of `playlist_download_members`, frozen (see
  /// [_createTrackDownloadsV4]).
  static const String _createPlaylistDownloadMembersV5 =
      'CREATE TABLE IF NOT EXISTS "playlist_download_members" ('
      '"server_id" TEXT NOT NULL, '
      '"playlist_item_id" TEXT NOT NULL, '
      '"position" INTEGER NOT NULL, '
      '"track_item_id" TEXT NOT NULL, '
      'PRIMARY KEY ("server_id", "playlist_item_id", "position"))';

  static final Index _savedAccountsServerIdIndex = Index(
    'idx_saved_accounts_server_id',
    'CREATE INDEX IF NOT EXISTS idx_saved_accounts_server_id '
        'ON saved_accounts (server_id)',
  );

  /// `ownedBy` — "which tracks did downloading this album ask for" — is
  /// the one query that does not start from a track id, and it runs
  /// every time an album header renders.
  static final Index _downloadOwnersOwnerIndex = Index(
    'idx_download_owners_owner',
    'CREATE INDEX IF NOT EXISTS idx_download_owners_owner '
        'ON download_owners (server_id, owner_kind, owner_item_id)',
  );

  static final Index _savedServersBaseUrlIndex = Index(
    'idx_saved_servers_base_url',
    'CREATE INDEX IF NOT EXISTS idx_saved_servers_base_url '
        'ON saved_servers (base_url)',
  );

  /// Reading a downloaded playlist's snapshot — for offline playback and
  /// for reconciling it against the server — always starts from the
  /// playlist id, ordered by position.
  static final Index _playlistDownloadMembersPlaylistIndex = Index(
    'idx_playlist_download_members_playlist',
    'CREATE INDEX IF NOT EXISTS idx_playlist_download_members_playlist '
        'ON playlist_download_members (server_id, playlist_item_id, position)',
  );

  /// Every download read starts from the active profile (v0.2.3): the
  /// catalog restore, the offline library listing, and the offline
  /// search all scan `track_downloads` for one `account_key`.
  static final Index _trackDownloadsAccountIndex = Index(
    'idx_track_downloads_account',
    'CREATE INDEX IF NOT EXISTS idx_track_downloads_account '
        'ON track_downloads (account_key, state, title)',
  );

  /// Listing a profile's downloaded albums, artists and playlists — for
  /// the Downloads screen and the offline library — is keyed by profile
  /// and kind, ordered by name.
  static final Index _downloadedCollectionsAccountIndex = Index(
    'idx_downloaded_collections_account',
    'CREATE INDEX IF NOT EXISTS idx_downloaded_collections_account '
        'ON downloaded_collections (account_key, owner_kind, sort_name)',
  );

  /// Reading listening history — and enforcing its per-profile bound —
  /// always scans one profile's rows newest-played first (v0.3.1).
  static final Index _listeningHistoryAccountIndex = Index(
    'idx_listening_history_account',
    'CREATE INDEX IF NOT EXISTS idx_listening_history_account '
        'ON listening_history_entries (account_key, last_played_at_ms)',
  );
}
