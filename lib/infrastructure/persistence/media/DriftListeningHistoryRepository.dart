import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/ListeningContext.dart';
import '../../../domain/media/ListeningHistoryEntry.dart';
import '../../../domain/media/ListeningHistoryRepository.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/media/MediaImage.dart';
import '../../jellyfin/identity/JellyfinSessionContext.dart';
import '../database/AppDatabase.dart';

/// [ListeningHistoryRepository] over `listening_history_entries` (schema
/// v7, ADR-0025).
///
/// ## Per-profile scope
///
/// Every row carries an `account_key` — the active server's local id and
/// the Jellyfin user id, joined — exactly as `DriftDownloadStore` does
/// (ADR-0023). Every read and write is filtered to the signed-in
/// profile's key, read from [JellyfinSessionContext]; with nobody signed
/// in a read is empty and [record] is a no-op. Signing out therefore
/// hides history rather than exposing the last profile's.
///
/// ## Bounded
///
/// At most [maxEntriesPerProfile] rows are kept per profile. Each
/// [record] that inserts a *new* context trims the profile back to the
/// cap by deleting the entries with the oldest `last_played_at_ms`. An
/// entry that only bumps an existing context cannot grow the row count,
/// so it never triggers a trim.
///
/// ## Offline
///
/// Nothing here touches a server. Recording a play is one local upsert,
/// so it behaves identically with the connection up or down.
@LazySingleton(as: ListeningHistoryRepository)
class DriftListeningHistoryRepository implements ListeningHistoryRepository {
  DriftListeningHistoryRepository(this._db, this._session);

  final AppDatabase _db;
  final JellyfinSessionContext _session;

  /// The cap `CONTEXT.md`'s "bounded local storage" rule requires. A
  /// hundred distinct albums, artists and singles is a deep "recently
  /// played" list and a hard ceiling regardless of how much the user
  /// plays — a year of listening does not make it longer, only more
  /// churned.
  static const int maxEntriesPerProfile = 100;

  /// The default page size for [recent]; a "recently played" section
  /// shows a handful of rows, not the whole cap.
  static const int _defaultRecentLimit = 30;

  String? get _accountKey {
    final serverId = _session.serverId;
    final userId = _session.userId;
    if (serverId == null || userId == null) return null;
    return '$serverId/$userId';
  }

  @override
  Future<Result<void>> record(ListeningPlay play) async {
    final key = _accountKey;
    if (key == null) return const Result.ok(null);

    final context = play.context;
    final serverId = context.id.serverId;
    final kind = context.kind.name;
    final itemId = context.id.itemId;
    final playedMs = play.playedAt.toUtc().millisecondsSinceEpoch;
    final image = context.image;

    try {
      await _db.transaction(() async {
        final existing =
            await (_db.select(_db.listeningHistoryEntries)..where(
                  (t) =>
                      t.accountKey.equals(key) &
                      t.serverId.equals(serverId) &
                      t.contextKind.equals(kind) &
                      t.contextItemId.equals(itemId),
                ))
                .getSingleOrNull();

        if (existing != null) {
          await (_db.update(_db.listeningHistoryEntries)..where(
                (t) =>
                    t.accountKey.equals(key) &
                    t.serverId.equals(serverId) &
                    t.contextKind.equals(kind) &
                    t.contextItemId.equals(itemId),
              ))
              .write(
                ListeningHistoryEntriesCompanion(
                  name: Value(context.name),
                  subtitle: Value(context.subtitle),
                  imageItemId: Value(image?.itemId.itemId),
                  imageKind: Value(image?.kind.name),
                  imageTag: Value(image?.tag),
                  imageAspectRatio: Value(image?.aspectRatio),
                  playCount: Value(existing.playCount + 1),
                  // A returning play can only move the entry forward in
                  // time; a clock skew must not drag it backwards.
                  lastPlayedAtMs: Value(
                    playedMs > existing.lastPlayedAtMs
                        ? playedMs
                        : existing.lastPlayedAtMs,
                  ),
                ),
              );
          return;
        }

        await _db
            .into(_db.listeningHistoryEntries)
            .insert(
              ListeningHistoryEntriesCompanion.insert(
                accountKey: key,
                serverId: serverId,
                contextKind: kind,
                contextItemId: itemId,
                name: context.name,
                subtitle: Value(context.subtitle),
                imageItemId: Value(image?.itemId.itemId),
                imageKind: Value(image?.kind.name),
                imageTag: Value(image?.tag),
                imageAspectRatio: Value(image?.aspectRatio),
                firstPlayedAtMs: playedMs,
                lastPlayedAtMs: playedMs,
              ),
            );

        await _trimToCap(key);
      });
      return const Result.ok(null);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not record listening history.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<ListeningHistoryEntry>>> recent({
    int limit = _defaultRecentLimit,
  }) async {
    final key = _accountKey;
    if (key == null) return const Result.ok([]);
    try {
      final rows =
          await (_db.select(_db.listeningHistoryEntries)
                ..where((t) => t.accountKey.equals(key))
                ..orderBy([(t) => OrderingTerm.desc(t.lastPlayedAtMs)])
                ..limit(limit < 0 ? 0 : limit))
              .get();
      return Result.ok([for (final row in rows) _toEntry(row)]);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not read listening history.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Deletes this profile's oldest-played entries until it is back within
  /// [maxEntriesPerProfile]. Runs inside [record]'s transaction.
  Future<void> _trimToCap(String key) async {
    final countExp = _db.listeningHistoryEntries.contextItemId.count();
    final countRow =
        await (_db.selectOnly(_db.listeningHistoryEntries)
              ..addColumns([countExp])
              ..where(_db.listeningHistoryEntries.accountKey.equals(key)))
            .getSingle();
    final total = countRow.read(countExp) ?? 0;
    final over = total - maxEntriesPerProfile;
    if (over <= 0) return;

    final doomed =
        await (_db.select(_db.listeningHistoryEntries)
              ..where((t) => t.accountKey.equals(key))
              ..orderBy([(t) => OrderingTerm.asc(t.lastPlayedAtMs)])
              ..limit(over))
            .get();
    for (final row in doomed) {
      await (_db.delete(_db.listeningHistoryEntries)..where(
            (t) =>
                t.accountKey.equals(key) &
                t.serverId.equals(row.serverId) &
                t.contextKind.equals(row.contextKind) &
                t.contextItemId.equals(row.contextItemId),
          ))
          .go();
    }
  }

  ListeningHistoryEntry _toEntry(ListeningHistoryEntryRow row) {
    final kind = ListeningContextKind.values.firstWhere(
      (candidate) => candidate.name == row.contextKind,
      orElse: () => ListeningContextKind.track,
    );
    return ListeningHistoryEntry(
      context: ListeningContext(
        kind: kind,
        id: MediaId(serverId: row.serverId, itemId: row.contextItemId),
        name: row.name,
        subtitle: row.subtitle,
        image: _decodeImage(row),
      ),
      firstPlayedAt: DateTime.fromMillisecondsSinceEpoch(
        row.firstPlayedAtMs,
        isUtc: true,
      ),
      lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
        row.lastPlayedAtMs,
        isUtc: true,
      ),
      playCount: row.playCount,
    );
  }

  static MediaImage? _decodeImage(ListeningHistoryEntryRow row) {
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
