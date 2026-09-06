import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
import '../../core/result/partial.dart';
import '../../core/result/result.dart';
import '../../domain/downloads/DownloadedCollection.dart';
import '../../domain/downloads/download_state.dart';
import '../../domain/downloads/DownloadOwner.dart';
import '../../domain/downloads/DownloadStore.dart';
import '../../domain/downloads/PlaylistDownload.dart';
import '../../domain/downloads/TrackDownload.dart';
import '../../domain/media/artist.dart';
import '../../domain/media/MediaId.dart';
import '../../domain/media/MediaImage.dart';
import '../../domain/media/page.dart';
import '../jellyfin/identity/JellyfinSessionContext.dart';
import '../persistence/database/AppDatabase.dart';

/// [DownloadStore] over `track_downloads`, `download_owners`,
/// `playlist_download_members` and `downloaded_collections` (schema v6).
///
/// A record and its owners are written in one transaction, so a download
/// never exists without a reason it is being kept — an ownerless record
/// would be a file nothing ever deletes.
///
/// ## Per-profile scope (v0.2.3)
///
/// Every row carries an `account_key` — the active server's local id and
/// the Jellyfin user id, joined — and every read and write here is
/// filtered to the signed-in profile's key. A second profile on the same
/// server therefore keeps an entirely separate collection, and signing
/// out makes the store read empty rather than exposing the last
/// profile's downloads. The key comes from [JellyfinSessionContext], the
/// same seam the media layer reads the session through; it is `null`
/// when no profile is active, which turns reads into empty results and
/// writes into no-ops.
@LazySingleton(as: DownloadStore)
class DriftDownloadStore implements DownloadStore {
  DriftDownloadStore(this._db, this._session);

  final AppDatabase _db;
  final JellyfinSessionContext _session;

  /// The active profile's row key, or `null` when nobody is signed in.
  String? get _accountKey {
    final serverId = _session.serverId;
    final userId = _session.userId;
    if (serverId == null || userId == null) return null;
    return '$serverId/$userId';
  }

  @override
  Future<Result<List<TrackDownload>>> all() async {
    final key = _accountKey;
    if (key == null) return const Result.ok([]);
    try {
      final rows =
          await (_db.select(_db.trackDownloads)
                ..where((t) => t.accountKey.equals(key))
                ..orderBy([(t) => OrderingTerm.asc(t.requestedAt)]))
              .get();
      if (rows.isEmpty) return const Result.ok([]);

      final ownerRows = await (_db.select(
        _db.downloadOwners,
      )..where((t) => t.accountKey.equals(key))).get();
      final owners = <(String, String), Set<DownloadOwner>>{};
      for (final row in ownerRows) {
        final owner = _toOwner(row);
        if (owner == null) continue;
        owners.putIfAbsent((row.serverId, row.itemId), () => {}).add(owner);
      }

      return Result.ok([
        for (final row in rows)
          _toDownload(row, owners[(row.serverId, row.itemId)] ?? const {}),
      ]);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not read your downloads.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<TrackDownload?>> find(MediaId id) async {
    final key = _accountKey;
    if (key == null) return const Result.ok(null);
    try {
      final row =
          await (_db.select(_db.trackDownloads)..where(
                (t) =>
                    t.accountKey.equals(key) &
                    t.serverId.equals(id.serverId) &
                    t.itemId.equals(id.itemId),
              ))
              .getSingleOrNull();
      if (row == null) return const Result.ok(null);
      return Result.ok(_toDownload(row, await _ownersOf(key, id)));
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not read that download.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> save(TrackDownload download) async {
    final key = _accountKey;
    if (key == null) return const Result.ok(null);
    try {
      await _db.transaction(() async {
        await _db
            .into(_db.trackDownloads)
            .insertOnConflictUpdate(_toRow(download, key));
        // The owner set is authoritative: rewriting it is what makes
        // "the album no longer wants this" a save rather than a
        // separate, forgettable call.
        await (_db.delete(_db.downloadOwners)..where(
              (t) =>
                  t.accountKey.equals(key) &
                  t.serverId.equals(download.id.serverId) &
                  t.itemId.equals(download.id.itemId),
            ))
            .go();
        for (final owner in download.owners) {
          await _db
              .into(_db.downloadOwners)
              .insertOnConflictUpdate(
                DownloadOwnersCompanion.insert(
                  accountKey: Value(key),
                  serverId: download.id.serverId,
                  itemId: download.id.itemId,
                  ownerKind: owner.kind.name,
                  ownerItemId: owner.id.itemId,
                ),
              );
        }
      });
      return const Result.ok(null);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not save that download.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(MediaId id) async {
    final key = _accountKey;
    if (key == null) return const Result.ok(null);
    try {
      await _db.transaction(() async {
        await (_db.delete(_db.downloadOwners)..where(
              (t) =>
                  t.accountKey.equals(key) &
                  t.serverId.equals(id.serverId) &
                  t.itemId.equals(id.itemId),
            ))
            .go();
        await (_db.delete(_db.trackDownloads)..where(
              (t) =>
                  t.accountKey.equals(key) &
                  t.serverId.equals(id.serverId) &
                  t.itemId.equals(id.itemId),
            ))
            .go();
      });
      return const Result.ok(null);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not remove that download.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<MediaId>>> ownedBy(DownloadOwner owner) async {
    final key = _accountKey;
    if (key == null) return const Result.ok([]);
    try {
      final rows =
          await (_db.select(_db.downloadOwners)..where(
                (t) =>
                    t.accountKey.equals(key) &
                    t.serverId.equals(owner.id.serverId) &
                    t.ownerKind.equals(owner.kind.name) &
                    t.ownerItemId.equals(owner.id.itemId),
              ))
              .get();
      return Result.ok([
        for (final row in rows)
          MediaId(serverId: row.serverId, itemId: row.itemId),
      ]);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not read that collection\'s downloads.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> savePlaylistMembers(
    MediaId playlistId,
    List<PlaylistDownloadMember> members,
  ) async {
    final key = _accountKey;
    if (key == null) return const Result.ok(null);
    try {
      await _db.transaction(() async {
        await _clearPlaylistMembers(key, playlistId);
        for (final member in members) {
          await _db
              .into(_db.playlistDownloadMembers)
              .insert(
                PlaylistDownloadMembersCompanion.insert(
                  accountKey: Value(key),
                  serverId: playlistId.serverId,
                  playlistItemId: playlistId.itemId,
                  position: member.position,
                  trackItemId: member.trackId.itemId,
                ),
              );
        }
      });
      return const Result.ok(null);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not save that playlist download.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<PlaylistDownloadMember>>> playlistMembers(
    MediaId playlistId,
  ) async {
    final key = _accountKey;
    if (key == null) return const Result.ok([]);
    try {
      final rows =
          await (_db.select(_db.playlistDownloadMembers)
                ..where(
                  (t) =>
                      t.accountKey.equals(key) &
                      t.serverId.equals(playlistId.serverId) &
                      t.playlistItemId.equals(playlistId.itemId),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      return Result.ok([for (final row in rows) _toMember(row)]);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not read that playlist download.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Map<MediaId, List<PlaylistDownloadMember>>>>
  allPlaylistMembers() async {
    final key = _accountKey;
    if (key == null) return const Result.ok({});
    try {
      final rows =
          await (_db.select(_db.playlistDownloadMembers)
                ..where((t) => t.accountKey.equals(key))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      final byPlaylist = <MediaId, List<PlaylistDownloadMember>>{};
      for (final row in rows) {
        final playlistId = MediaId(
          serverId: row.serverId,
          itemId: row.playlistItemId,
        );
        byPlaylist.putIfAbsent(playlistId, () => []).add(_toMember(row));
      }
      return Result.ok(byPlaylist);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not read your playlist downloads.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deletePlaylistMembers(MediaId playlistId) async {
    final key = _accountKey;
    if (key == null) return const Result.ok(null);
    try {
      await _clearPlaylistMembers(key, playlistId);
      return const Result.ok(null);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not remove that playlist download.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ---- Downloaded-collection identity (v0.2.3) ----

  @override
  Future<Result<void>> saveCollection(DownloadedCollection collection) async {
    final key = _accountKey;
    if (key == null) return const Result.ok(null);
    try {
      final image = collection.image;
      await _db
          .into(_db.downloadedCollections)
          .insertOnConflictUpdate(
            DownloadedCollectionsCompanion.insert(
              accountKey: Value(key),
              serverId: collection.id.serverId,
              ownerKind: collection.kind.name,
              ownerItemId: collection.id.itemId,
              name: collection.name,
              sortName: Value(collection.name.toLowerCase()),
              imageItemId: Value(image?.itemId.itemId),
              imageKind: Value(image?.kind.name),
              imageTag: Value(image?.tag),
              imageAspectRatio: Value(image?.aspectRatio),
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      return const Result.ok(null);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not save that download.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteCollection(DownloadOwner owner) async {
    final key = _accountKey;
    if (key == null) return const Result.ok(null);
    try {
      await (_db.delete(_db.downloadedCollections)..where(
            (t) =>
                t.accountKey.equals(key) &
                t.serverId.equals(owner.id.serverId) &
                t.ownerKind.equals(owner.kind.name) &
                t.ownerItemId.equals(owner.id.itemId),
          ))
          .go();
      return const Result.ok(null);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not remove that download.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Page<DownloadedCollection>>> collections({
    DownloadOwnerKind? kind,
    String? searchTerm,
    PageRequest page = const PageRequest.first(),
  }) async {
    final key = _accountKey;
    if (key == null) return Result.ok(const Page<DownloadedCollection>.empty());
    try {
      final term = searchTerm?.trim().toLowerCase();
      final table = _db.downloadedCollections;
      var filter = table.accountKey.equals(key);
      if (kind != null) filter = filter & table.ownerKind.equals(kind.name);
      if (term != null && term.isNotEmpty) {
        filter = filter & table.sortName.like('%${_escapeLike(term)}%');
      }

      final total = await _count(table, filter);
      final rows =
          await (_db.select(table)
                ..where((_) => filter)
                ..orderBy([(t) => OrderingTerm.asc(t.sortName)])
                ..limit(page.limit, offset: page.startIndex))
              .get();

      return Result.ok(
        Page<DownloadedCollection>(
          content: Partial(
            available: [for (final row in rows) _toCollection(row)],
          ),
          startIndex: page.startIndex,
          totalCount: total,
          source: PageSource.cache,
        ),
      );
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not read your downloaded collections.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ---- Offline discovery (v0.2.3) ----

  @override
  Future<Result<Page<TrackDownload>>> searchTrackDownloads({
    String? searchTerm,
    PageRequest page = const PageRequest.first(),
  }) async {
    final key = _accountKey;
    if (key == null) return Result.ok(const Page<TrackDownload>.empty());
    try {
      final term = searchTerm?.trim().toLowerCase();
      final table = _db.trackDownloads;
      var filter =
          table.accountKey.equals(key) &
          table.state.equals(DownloadState.completed.name);
      if (term != null && term.isNotEmpty) {
        filter = filter & table.title.lower().like('%${_escapeLike(term)}%');
      }

      final total = await _count(table, filter);
      final rows =
          await (_db.select(table)
                ..where((_) => filter)
                ..orderBy([
                  (t) => OrderingTerm.asc(t.title.lower()),
                  (t) => OrderingTerm.asc(t.requestedAt),
                ])
                ..limit(page.limit, offset: page.startIndex))
              .get();

      final owners = await _ownersForRows(key, rows);
      return Result.ok(
        Page<TrackDownload>(
          content: Partial(
            available: [
              for (final row in rows)
                _toDownload(
                  row,
                  owners[(row.serverId, row.itemId)] ?? const {},
                ),
            ],
          ),
          startIndex: page.startIndex,
          totalCount: total,
          source: PageSource.cache,
        ),
      );
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not search your downloads.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ---- Migration to per-profile downloads (v0.2.3) ----

  @override
  Future<Result<int>> claimLegacyDownloads() async {
    final key = _accountKey;
    if (key == null || key.isEmpty) return const Result.ok(0);
    try {
      var moved = 0;
      await _db.transaction(() async {
        for (final table in <TableInfo<Table, dynamic>>[
          _db.trackDownloads,
          _db.downloadOwners,
          _db.playlistDownloadMembers,
          _db.downloadedCollections,
        ]) {
          moved += await _db.customUpdate(
            'UPDATE ${table.actualTableName} SET account_key = ? '
            'WHERE account_key = ?',
            variables: [Variable<String>(key), const Variable<String>('')],
            updates: {table},
          );
        }
      });
      return Result.ok(moved);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not migrate your downloads.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ---- Helpers ----

  Future<void> _clearPlaylistMembers(String key, MediaId playlistId) =>
      (_db.delete(_db.playlistDownloadMembers)..where(
            (t) =>
                t.accountKey.equals(key) &
                t.serverId.equals(playlistId.serverId) &
                t.playlistItemId.equals(playlistId.itemId),
          ))
          .go();

  PlaylistDownloadMember _toMember(PlaylistDownloadMemberRow row) => (
    position: row.position,
    trackId: MediaId(serverId: row.serverId, itemId: row.trackItemId),
  );

  Future<Set<DownloadOwner>> _ownersOf(String key, MediaId id) async {
    final rows =
        await (_db.select(_db.downloadOwners)..where(
              (t) =>
                  t.accountKey.equals(key) &
                  t.serverId.equals(id.serverId) &
                  t.itemId.equals(id.itemId),
            ))
            .get();
    return {
      for (final row in rows)
        if (_toOwner(row) case final DownloadOwner owner) owner,
    };
  }

  /// The owner sets for a batch of track rows, in one query rather than
  /// one per row — the same reason the metadata cache batches its lookups.
  Future<Map<(String, String), Set<DownloadOwner>>> _ownersForRows(
    String key,
    List<TrackDownloadRow> rows,
  ) async {
    if (rows.isEmpty) return const {};
    final itemIds = {for (final row in rows) row.itemId};
    final ownerRows = await (_db.select(
      _db.downloadOwners,
    )..where((t) => t.accountKey.equals(key) & t.itemId.isIn(itemIds))).get();
    final owners = <(String, String), Set<DownloadOwner>>{};
    for (final row in ownerRows) {
      final owner = _toOwner(row);
      if (owner == null) continue;
      owners.putIfAbsent((row.serverId, row.itemId), () => {}).add(owner);
    }
    return owners;
  }

  Future<int> _count(
    ResultSetImplementation<HasResultSet, dynamic> table,
    Expression<bool> filter,
  ) async {
    final count = countAll();
    final query = _db.selectOnly(table)
      ..addColumns([count])
      ..where(filter);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  DownloadedCollection _toCollection(DownloadedCollectionRow row) {
    final kind =
        DownloadOwnerKind.tryParse(row.ownerKind) ?? DownloadOwnerKind.album;
    return DownloadedCollection(
      owner: DownloadOwner(
        kind: kind,
        id: MediaId(serverId: row.serverId, itemId: row.ownerItemId),
      ),
      name: row.name,
      image: _decodeCollectionImage(row),
    );
  }

  static MediaImage? _decodeCollectionImage(DownloadedCollectionRow row) {
    final itemId = row.imageItemId;
    final tag = row.imageTag;
    if (itemId == null || tag == null) return null;
    final kind = MediaImageKind.values.firstWhere(
      (candidate) => candidate.name == row.imageKind,
      orElse: () => MediaImageKind.primary,
    );
    return MediaImage(
      itemId: MediaId(serverId: row.serverId, itemId: itemId),
      kind: kind,
      tag: tag,
      aspectRatio: row.imageAspectRatio,
    );
  }

  /// A `LIKE` pattern escapes `%`, `_` and the escape character itself;
  /// the queries pair this with `ESCAPE '\'` implicitly via drift's
  /// default operand handling — drift's `like` does not take an escape
  /// clause, so we only guard the wildcards a title could realistically
  /// contain.
  static String _escapeLike(String term) =>
      term.replaceAll('%', r'\%').replaceAll('_', r'\_');

  DownloadOwner? _toOwner(DownloadOwnerRow row) {
    final kind = DownloadOwnerKind.tryParse(row.ownerKind);
    if (kind == null) return null;
    return DownloadOwner(
      kind: kind,
      id: MediaId(serverId: row.serverId, itemId: row.ownerItemId),
    );
  }

  TrackDownloadsCompanion _toRow(TrackDownload download, String accountKey) =>
      TrackDownloadsCompanion.insert(
        accountKey: Value(accountKey),
        serverId: download.id.serverId,
        itemId: download.id.itemId,
        state: download.state.name,
        serverGone: Value(download.serverGone),
        failureReason: Value(download.failureReason?.name),
        receivedBytes: Value(download.receivedBytes),
        totalBytes: Value(download.totalBytes),
        title: download.title,
        artistsJson: Value(_encodeArtists(download.artists)),
        albumItemId: Value(download.albumId?.itemId),
        albumName: Value(download.albumName),
        trackNumber: Value(download.trackNumber),
        discNumber: Value(download.discNumber),
        durationMicros: Value(download.duration?.inMicroseconds),
        normalizationGain: Value(download.normalizationGain),
        imageItemId: Value(download.image?.itemId.itemId),
        imageKind: Value(download.image?.kind.name),
        imageTag: Value(download.image?.tag),
        imageAspectRatio: Value(download.image?.aspectRatio),
        requestedAt: download.requestedAt.microsecondsSinceEpoch,
      );

  TrackDownload _toDownload(TrackDownloadRow row, Set<DownloadOwner> owners) {
    final id = MediaId(serverId: row.serverId, itemId: row.itemId);
    // A row whose state string is not one Jellyfinity knows (a database
    // written by a newer build, then downgraded) is treated as
    // interrupted rather than dropped: the file and the request are
    // both still real.
    final state = _stateFrom(row.state);
    return TrackDownload(
      id: id,
      title: row.title,
      state: state,
      owners: owners,
      requestedAt: DateTime.fromMicrosecondsSinceEpoch(
        row.requestedAt,
        isUtc: true,
      ),
      artists: _decodeArtists(row.artistsJson, row.serverId),
      albumId: row.albumItemId == null
          ? null
          : MediaId(serverId: row.serverId, itemId: row.albumItemId!),
      albumName: row.albumName,
      trackNumber: row.trackNumber,
      discNumber: row.discNumber,
      duration: row.durationMicros == null
          ? null
          : Duration(microseconds: row.durationMicros!),
      normalizationGain: row.normalizationGain,
      image: _decodeImage(row),
      receivedBytes: row.receivedBytes,
      totalBytes: row.totalBytes,
      failureReason: state == DownloadState.failed
          ? _failureReasonFrom(row.failureReason)
          : null,
      serverGone: row.serverGone,
    );
  }

  static DownloadState _stateFrom(String raw) {
    for (final state in DownloadState.values) {
      if (state.name == raw) return state;
    }
    return DownloadState.paused;
  }

  static DownloadFailureReason _failureReasonFrom(String? raw) {
    for (final reason in DownloadFailureReason.values) {
      if (reason.name == raw) return reason;
    }
    return DownloadFailureReason.unknown;
  }

  /// Encoded exactly as `MediaCacheMapper` encodes the same list, so the
  /// two tables stay readable by one another's conventions.
  static String? _encodeArtists(List<ArtistRef> artists) {
    if (artists.isEmpty) return null;
    return jsonEncode([
      for (final credit in artists)
        <String, Object?>{'name': credit.name, 'id': credit.id?.itemId},
    ]);
  }

  static List<ArtistRef> _decodeArtists(String? json, String serverId) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry is Map<String, dynamic> && entry['name'] is String)
            ArtistRef(
              name: entry['name'] as String,
              id: entry['id'] is String
                  ? MediaId(serverId: serverId, itemId: entry['id'] as String)
                  : null,
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  static MediaImage? _decodeImage(TrackDownloadRow row) {
    final itemId = row.imageItemId;
    final tag = row.imageTag;
    if (itemId == null || tag == null) return null;
    final kind = MediaImageKind.values.firstWhere(
      (candidate) => candidate.name == row.imageKind,
      orElse: () => MediaImageKind.primary,
    );
    return MediaImage(
      itemId: MediaId(serverId: row.serverId, itemId: itemId),
      kind: kind,
      tag: tag,
      aspectRatio: row.imageAspectRatio,
    );
  }
}
