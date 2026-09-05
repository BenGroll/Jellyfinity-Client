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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await m.createIndex(_savedAccountsServerIdIndex);
      await m.createIndex(_savedServersBaseUrlIndex);
      await m.createIndex(_downloadOwnersOwnerIndex);
      await m.createIndex(_playlistDownloadMembersPlaylistIndex);
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
      if (from < 3) {
        await m.createTable(queueEntries);
      }
      // v4 (v0.2.0): downloads. Additive again — the two new tables
      // start empty, so an upgrading install keeps everything it had
      // and simply has nothing downloaded yet.
      if (from < 4) {
        await m.createTable(trackDownloads);
        await m.createTable(downloadOwners);
        await m.createIndex(_downloadOwnersOwnerIndex);
      }
      // v5 (v0.2.1): playlist download membership snapshots. One new
      // table, still additive — an upgrading install has every track and
      // album download it had, and simply no playlist snapshots yet.
      if (from < 5) {
        await m.createTable(playlistDownloadMembers);
        await m.createIndex(_playlistDownloadMembersPlaylistIndex);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
}
