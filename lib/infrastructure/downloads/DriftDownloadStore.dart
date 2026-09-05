import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../domain/downloads/download_state.dart';
import '../../domain/downloads/DownloadOwner.dart';
import '../../domain/downloads/DownloadStore.dart';
import '../../domain/downloads/TrackDownload.dart';
import '../../domain/media/artist.dart';
import '../../domain/media/MediaId.dart';
import '../../domain/media/MediaImage.dart';
import '../persistence/database/AppDatabase.dart';

/// [DownloadStore] over `track_downloads` and `download_owners`
/// (schema v4).
///
/// A record and its owners are written in one transaction, so a download
/// never exists without a reason it is being kept — an ownerless record
/// would be a file nothing ever deletes.
@LazySingleton(as: DownloadStore)
class DriftDownloadStore implements DownloadStore {
  DriftDownloadStore(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<TrackDownload>>> all() async {
    try {
      final rows = await (_db.select(
        _db.trackDownloads,
      )..orderBy([(t) => OrderingTerm.asc(t.requestedAt)])).get();
      if (rows.isEmpty) return const Result.ok([]);

      final ownerRows = await _db.select(_db.downloadOwners).get();
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
    try {
      final row =
          await (_db.select(_db.trackDownloads)..where(
                (t) =>
                    t.serverId.equals(id.serverId) & t.itemId.equals(id.itemId),
              ))
              .getSingleOrNull();
      if (row == null) return const Result.ok(null);
      return Result.ok(_toDownload(row, await _ownersOf(id)));
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
    try {
      await _db.transaction(() async {
        await _db
            .into(_db.trackDownloads)
            .insertOnConflictUpdate(_toRow(download));
        // The owner set is authoritative: rewriting it is what makes
        // "the album no longer wants this" a save rather than a
        // separate, forgettable call.
        await (_db.delete(_db.downloadOwners)..where(
              (t) =>
                  t.serverId.equals(download.id.serverId) &
                  t.itemId.equals(download.id.itemId),
            ))
            .go();
        for (final owner in download.owners) {
          await _db
              .into(_db.downloadOwners)
              .insertOnConflictUpdate(
                DownloadOwnersCompanion.insert(
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
    try {
      await _db.transaction(() async {
        await (_db.delete(_db.downloadOwners)..where(
              (t) =>
                  t.serverId.equals(id.serverId) & t.itemId.equals(id.itemId),
            ))
            .go();
        await (_db.delete(_db.trackDownloads)..where(
              (t) =>
                  t.serverId.equals(id.serverId) & t.itemId.equals(id.itemId),
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
    try {
      final rows =
          await (_db.select(_db.downloadOwners)..where(
                (t) =>
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

  Future<Set<DownloadOwner>> _ownersOf(MediaId id) async {
    final rows =
        await (_db.select(_db.downloadOwners)..where(
              (t) =>
                  t.serverId.equals(id.serverId) & t.itemId.equals(id.itemId),
            ))
            .get();
    return {
      for (final row in rows)
        if (_toOwner(row) case final DownloadOwner owner) owner,
    };
  }

  DownloadOwner? _toOwner(DownloadOwnerRow row) {
    final kind = DownloadOwnerKind.tryParse(row.ownerKind);
    if (kind == null) return null;
    return DownloadOwner(
      kind: kind,
      id: MediaId(serverId: row.serverId, itemId: row.ownerItemId),
    );
  }

  TrackDownloadsCompanion _toRow(TrackDownload download) =>
      TrackDownloadsCompanion.insert(
        serverId: download.id.serverId,
        itemId: download.id.itemId,
        state: download.state.name,
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
      requestedAt: DateTime.fromMicrosecondsSinceEpoch(row.requestedAt),
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
