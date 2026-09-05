import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../domain/downloads/downloads.dart';
import '../../domain/media/Album.dart';
import '../../domain/media/MediaId.dart';
import '../../domain/media/MusicLibraryRepository.dart';
import '../../domain/media/page.dart';
import '../../domain/media/Playlist.dart';
import '../../domain/media/PlaylistRepository.dart';
import '../../domain/media/Track.dart';
import '../../domain/playback/AudioSourceResolver.dart';
import '../../domain/playback/stream_quality.dart';

/// The single source of truth for downloads — what has been asked for,
/// what state each request is in, and the worker that moves them along
/// (v0.2.0, ADR-0020).
///
/// The same architectural slot as `PlaybackCubit`: cross-cutting
/// application state rather than a feature, because a track row, an
/// album header and (from v0.2.2) a Downloads screen all need the same
/// answer about the same file. It owns the *rules* — who wants a file,
/// what order work happens in, what a failure means — while
/// [DownloadEngine] owns the mechanism.
///
/// ## One at a time
///
/// Downloads run serially. On a phone, several parallel transfers
/// compete for the same radio without finishing the album any sooner,
/// and they turn one interruption into several partial files. Serial
/// work also makes the queue's meaning plain: the oldest request is the
/// one being worked on.
///
/// ## Quality
///
/// Files are fetched at [StreamQuality.original] — `ROADMAP.md`'s
/// "intended safe starting point ... because it never silently changes
/// what a user gets". The separate, configurable download-quality
/// preference is v0.2.2's.
@lazySingleton
class DownloadsCubit extends Cubit<DownloadCatalog> {
  DownloadsCubit(
    this._store,
    this._engine,
    this._remote,
    this._library,
    this._playlists,
  ) : super(DownloadCatalog.empty);

  final DownloadStore _store;
  final DownloadEngine _engine;

  /// The server-backed resolver, not the local-first one: a download is
  /// how a file *becomes* local, so it always addresses the server.
  final AudioSourceResolver _remote;

  final MusicLibraryRepository _library;
  final PlaylistRepository _playlists;

  /// The track being transferred right now, if any.
  MediaId? _active;

  /// Ids the user removed or cancelled while their transfer was in
  /// flight. The engine's own failure for an aborted transfer arrives
  /// after the fact, and must not be written back over the state the
  /// user just asked for.
  final Set<MediaId> _abandoned = {};

  /// Serializes the worker so two pumps cannot both claim the same
  /// pending record.
  Future<void> _worker = Future<void>.value();

  /// A record's album, for the aggregate an album header shows.
  static DownloadOwner albumOwner(MediaId albumId) =>
      DownloadOwner.album(albumId);

  /// A record's playlist, for the aggregate a playlist header shows
  /// (v0.2.1).
  static DownloadOwner playlistOwner(MediaId playlistId) =>
      DownloadOwner.playlist(playlistId);

  // ---- Cold start ----

  /// Reads the stored records and picks up where the last run left off.
  ///
  /// Anything the store still calls [DownloadState.downloading] was
  /// interrupted by the app going away mid-transfer — there is no
  /// transfer running in a fresh process. Those go back to
  /// [DownloadState.queued] and resume from the bytes already on disk,
  /// which is what makes "close the app, come back later" finish an
  /// album rather than silently abandon it.
  Future<void> restore() async {
    final stored = await _store.all();
    if (stored case Err<List<TrackDownload>>()) {
      emit(state.copyWith(isLoaded: true));
      return;
    }

    final snapshots = await _store.allPlaylistMembers();
    final playlistSnapshots =
        snapshots is Ok<Map<MediaId, List<PlaylistDownloadMember>>>
        ? snapshots.value
        : const <MediaId, List<PlaylistDownloadMember>>{};

    final downloads = <MediaId, TrackDownload>{};
    final interrupted = <TrackDownload>[];
    for (final record in (stored as Ok<List<TrackDownload>>).value) {
      if (record.state == DownloadState.downloading) {
        final resumed = record.copyWith(
          state: DownloadState.queued,
          receivedBytes: await _engine.partialByteCount(record.id),
          clearFailureReason: true,
        );
        interrupted.add(resumed);
        downloads[record.id] = resumed;
      } else {
        downloads[record.id] = record;
      }
    }

    emit(
      DownloadCatalog(
        downloads: downloads,
        playlistSnapshots: playlistSnapshots,
        isLoaded: true,
      ),
    );
    for (final record in interrupted) {
      await _store.save(record);
    }
    _pump();
  }

  // ---- Requesting ----

  /// Keeps [track] on this device.
  ///
  /// Asking for a track that is already downloaded does not fetch it
  /// again: it adds the request as another reason the file is kept, so
  /// removing the album it came with will not take it away.
  Future<void> downloadTrack(Track track) =>
      _request([track], owner: DownloadOwner.track(track.id));

  /// Keeps every track on [album] on this device.
  ///
  /// Reads the album's tracks itself, one page at a time, rather than
  /// taking whatever a screen happens to have scrolled into view — a
  /// user who asks for an album means all of it.
  Future<Result<void>> downloadAlbum(Album album) async {
    final tracks = await _albumTracks(album.id);
    if (tracks case Err<List<Track>>(:final failure)) {
      return Result.err(failure);
    }
    await _request(
      (tracks as Ok<List<Track>>).value,
      owner: DownloadOwner.album(album.id),
    );
    return const Result.ok(null);
  }

  /// Keeps [playlist] on this device as a membership snapshot (v0.2.1).
  ///
  /// Reads the playlist's entries a page at a time and requests each page
  /// as it arrives rather than accumulating the whole list first, then
  /// records the order it saw in a durable snapshot separate from the
  /// per-track owner rows. An already downloaded track is reused — it
  /// gains a playlist owner and its file is not fetched again. A page
  /// that fails after the first one succeeded leaves a partial snapshot
  /// that a later online open reconciles and completes, rather than
  /// failing the whole request.
  Future<Result<void>> downloadPlaylist(Playlist playlist) async {
    final owner = DownloadOwner.playlist(playlist.id);
    final members = <PlaylistDownloadMember>[];
    var request = const PageRequest.first();
    var readAnything = false;
    Failure? readFailure;

    while (true) {
      final page = await _playlists.tracks(playlist.id, page: request);
      if (page case Err<Page<Track>>(:final failure)) {
        readFailure = failure;
        break;
      }
      readAnything = true;
      final window = (page as Ok<Page<Track>>).value;
      if (window.items.isNotEmpty) {
        for (final track in window.items) {
          members.add((position: members.length, trackId: track.id));
        }
        await _request(window.items, owner: owner);
      }
      if (window.consumed == 0) break;
      final next = window.nextRequest();
      if (next == null) break;
      request = next;
    }

    if (!readAnything) {
      return Result.err(
        readFailure ?? const UnavailableFailure('That playlist is not there.'),
      );
    }

    await _store.savePlaylistMembers(playlist.id, members);
    _emitSnapshot(playlist.id, members);
    _pump();
    return const Result.ok(null);
  }

  /// Gives up a playlist's claim on every track it asked for and forgets
  /// its snapshot (v0.2.1).
  ///
  /// A track the user also downloaded on its own, or that another
  /// downloaded playlist still lists, keeps its file — the playlist was
  /// only ever one of the reasons it was there.
  Future<void> removePlaylist(MediaId playlistId) async {
    final owner = DownloadOwner.playlist(playlistId);
    for (final record in state.ownedBy(owner).toList()) {
      await _release(record.id, owner);
    }
    await _store.deletePlaylistMembers(playlistId);
    final snapshots = Map<MediaId, List<PlaylistDownloadMember>>.of(
      state.playlistSnapshots,
    )..remove(playlistId);
    emit(state.copyWith(playlistSnapshots: snapshots));
  }

  /// Reconciles a downloaded playlist against the server (v0.2.1).
  ///
  /// `ROADMAP.md` v0.2.1: on a user-requested refresh and when the
  /// playlist is opened online, queue new members, drop the claim on
  /// members the server no longer lists (keeping a file another download
  /// still owns), and report what changed. A playlist that is not
  /// downloaded, or a read that only the cache could answer, is left
  /// alone — there is no reconciling against a server that did not speak.
  Future<PlaylistDownloadChange> reconcilePlaylist(MediaId playlistId) async {
    final snapshot = state.playlistSnapshots[playlistId];
    if (snapshot == null) return PlaylistDownloadChange.none;

    final owner = DownloadOwner.playlist(playlistId);
    final current = <Track>[];
    var request = const PageRequest.first();
    while (true) {
      final page = await _playlists.tracks(playlistId, page: request);
      if (page case Err<Page<Track>>()) return PlaylistDownloadChange.none;
      final window = (page as Ok<Page<Track>>).value;
      // A cached window is not the server answering; reconciling against
      // it would treat a stale copy as authoritative.
      if (window.isCached) return PlaylistDownloadChange.none;
      current.addAll(window.items);
      if (window.consumed == 0) break;
      final next = window.nextRequest();
      if (next == null) break;
      request = next;
    }

    final currentIds = {for (final track in current) track.id};
    final snapshotIds = {for (final member in snapshot) member.trackId};

    final added = [
      for (final track in current)
        if (!snapshotIds.contains(track.id)) track,
    ];
    final removed = [
      for (final member in snapshot)
        if (!currentIds.contains(member.trackId)) member.trackId,
    ];

    if (added.isNotEmpty) await _request(added, owner: owner);

    var removedButKept = 0;
    for (final id in removed) {
      await _release(id, owner);
      if (state[id] != null) removedButKept++;
    }

    final members = <PlaylistDownloadMember>[
      for (var i = 0; i < current.length; i++)
        (position: i, trackId: current[i].id),
    ];
    await _store.savePlaylistMembers(playlistId, members);
    _emitSnapshot(playlistId, members);
    if (added.isNotEmpty) _pump();

    return PlaylistDownloadChange(
      added: added.length,
      removed: removed.length,
      removedButKept: removedButKept,
    );
  }

  void _emitSnapshot(MediaId playlistId, List<PlaylistDownloadMember> members) {
    emit(
      state.copyWith(
        playlistSnapshots: {...state.playlistSnapshots, playlistId: members},
      ),
    );
  }

  Future<void> _request(
    List<Track> tracks, {
    required DownloadOwner owner,
  }) async {
    if (tracks.isEmpty) return;
    final downloads = Map<MediaId, TrackDownload>.of(state.downloads);
    final now = DateTime.now();

    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final existing = downloads[track.id];
      if (existing == null) {
        // Requests made in one batch keep their order in the queue: the
        // store orders by requestedAt, so the album plays back in the
        // order it downloads.
        downloads[track.id] = TrackDownload.requested(
          track,
          owner: owner,
          requestedAt: now.add(Duration(microseconds: i)),
        );
      } else {
        // Already known. Add the new reason for keeping it, and give a
        // stopped download another go — asking again is the plainest
        // way a user can say "try that once more".
        final owners = {...existing.owners, owner};
        downloads[track.id] = existing.state.isRetryable
            ? existing.copyWith(
                state: DownloadState.queued,
                owners: owners,
                clearFailureReason: true,
              )
            : existing.copyWith(owners: owners);
      }
      _abandoned.remove(track.id);
    }

    emit(state.copyWith(downloads: downloads));
    for (final track in tracks) {
      await _store.save(downloads[track.id]!);
    }
    _pump();
  }

  // ---- Stopping and removing ----

  /// Stops [id]'s transfer, keeping what has arrived so far so resuming
  /// does not start the file over.
  Future<void> pause(MediaId id) async {
    final record = state[id];
    if (record == null || !record.state.isPending) return;
    _abandoned.add(id);
    await _engine.abort(id);
    await _write(
      record.copyWith(state: DownloadState.paused, clearFailureReason: true),
    );
  }

  /// Queues [id] again after it failed or was paused.
  Future<void> retry(MediaId id) async {
    final record = state[id];
    if (record == null || !record.state.isRetryable) return;
    _abandoned.remove(id);
    await _write(
      record.copyWith(state: DownloadState.queued, clearFailureReason: true),
    );
    _pump();
  }

  /// Queues every failed or paused download owned by [owner] again —
  /// the "download all available" recovery a partially finished
  /// collection needs.
  Future<void> retryAll(DownloadOwner owner) async {
    for (final record in state.ownedBy(owner).toList()) {
      if (record.state.isRetryable) await retry(record.id);
    }
  }

  /// Removes [id] from the device.
  ///
  /// With no [owner], this is the user pointing at one song and saying
  /// "stop keeping this": every claim on it is dropped and the file
  /// goes, even if it arrived as part of an album — the album then
  /// honestly shows one track short rather than pretending it is whole.
  /// With an [owner], only that claim is given up, and the file survives
  /// as long as something else still wants it.
  ///
  /// Never touches the server's copy: removing a download is a storage
  /// decision, not a library one.
  Future<void> removeTrack(MediaId id, {DownloadOwner? owner}) =>
      _release(id, owner);

  /// Gives up an album's claim on every track it asked for.
  ///
  /// A track the user also downloaded on its own keeps its file: the
  /// album was only ever one of the reasons it was there.
  Future<void> removeAlbum(MediaId albumId) async {
    final owner = DownloadOwner.album(albumId);
    for (final record in state.ownedBy(owner).toList()) {
      await _release(record.id, owner);
    }
  }

  /// Drops [owner]'s claim on [id] — or every claim, when [owner] is
  /// null — and deletes the file once nothing wants it any more.
  Future<void> _release(MediaId id, DownloadOwner? owner) async {
    final record = state[id];
    if (record == null) return;

    final owners = owner == null
        ? <DownloadOwner>{}
        : ({...record.owners}..remove(owner));
    if (owners.isNotEmpty) {
      await _write(record.copyWith(owners: owners));
      return;
    }

    _abandoned.add(id);
    if (_active == id) await _engine.abort(id);
    await _engine.discard(id);
    await _store.delete(id);

    final downloads = Map<MediaId, TrackDownload>.of(state.downloads)
      ..remove(id);
    emit(state.copyWith(downloads: downloads));
    _pump();
  }

  // ---- The worker ----

  void _pump() {
    _worker = _worker.then((_) => _drain());
  }

  Future<void> _drain() async {
    if (isClosed || _active != null) return;

    final next = _nextPending();
    if (next == null) return;

    _active = next.id;
    _abandoned.remove(next.id);
    await _write(
      next.copyWith(state: DownloadState.downloading, clearFailureReason: true),
    );

    final failure = await _transfer(next);
    _active = null;

    if (!isClosed && failure != null && !_abandoned.remove(next.id)) {
      final current = state[next.id];
      if (current != null) {
        await _write(
          current.copyWith(state: DownloadState.failed, failureReason: failure),
        );
      }
    }

    // Straight on to the next one, rather than waiting for something
    // else to nudge the queue.
    if (!isClosed) _pump();
  }

  /// Fetches one track. Returns `null` on success, or why it stopped.
  Future<DownloadFailureReason?> _transfer(TrackDownload record) async {
    final address = await _remote.resolve(
      record.id,
      quality: StreamQuality.original,
    );
    if (address case Err<Uri>(:final failure)) {
      return _reasonFor(failure);
    }

    final stored = await _engine.fetch(
      record.id,
      (address as Ok<Uri>).value,
      onProgress: (progress) {
        if (isClosed || _abandoned.contains(record.id)) return;
        final current = state[record.id];
        if (current == null || current.state != DownloadState.downloading) {
          return;
        }
        // Progress only touches the in-memory catalog. Writing every
        // tick to the database would be hundreds of writes per track
        // for a number that is re-derivable from the partial file after
        // a restart anyway.
        emit(
          state.copyWith(
            downloads: {
              ...state.downloads,
              record.id: current.copyWith(
                receivedBytes: progress.receivedBytes,
                totalBytes: progress.totalBytes,
              ),
            },
          ),
        );
      },
    );

    if (stored case Err<StoredDownload>(:final failure)) {
      return _reasonFor(failure);
    }

    if (_abandoned.contains(record.id)) return null;
    final completed = (stored as Ok<StoredDownload>).value;
    final current = state[record.id];
    if (current == null) return null;
    await _write(
      current.copyWith(
        state: DownloadState.completed,
        receivedBytes: completed.byteCount,
        totalBytes: completed.byteCount,
        clearFailureReason: true,
      ),
    );
    return null;
  }

  /// The oldest request still waiting. [DownloadState.paused] records
  /// are deliberately not picked up: the user stopped those, and only
  /// an explicit retry starts them again.
  TrackDownload? _nextPending() {
    TrackDownload? next;
    for (final record in state.downloads.values) {
      if (record.state != DownloadState.queued) continue;
      if (next == null || record.requestedAt.isBefore(next.requestedAt)) {
        next = record;
      }
    }
    return next;
  }

  Future<void> _write(TrackDownload record) async {
    if (isClosed) return;
    emit(state.copyWith(downloads: {...state.downloads, record.id: record}));
    await _store.save(record);
  }

  /// Pages through an album's tracks. Albums are a bounded collection —
  /// a long one is a few dozen tracks — so reading all of them is safe;
  /// the same is emphatically not true of an artist, which is why
  /// `ROADMAP.md` gives artist downloads their own version.
  Future<Result<List<Track>>> _albumTracks(MediaId albumId) async {
    final tracks = <Track>[];
    var request = const PageRequest.first();
    while (true) {
      final page = await _library.tracks(page: request, albumId: albumId);
      if (page case Err<Page<Track>>(:final failure)) {
        // Nothing loaded at all: the user gets a failure instead of a
        // silently truncated album.
        if (tracks.isEmpty) return Result.err(failure);
        break;
      }
      final window = (page as Ok<Page<Track>>).value;
      tracks.addAll(window.items);
      // A window that accounted for nothing would be asked for forever.
      if (window.consumed == 0) break;
      final next = window.nextRequest();
      if (next == null) break;
      request = next;
    }
    return Result.ok(tracks);
  }

  static DownloadFailureReason _reasonFor(Failure failure) {
    // A write that failed for a reason other than space is still a
    // storage problem, and telling the user their server lost the file
    // would send them looking in the wrong place.
    if (failure is! InsufficientStorageFailure &&
        failure.cause is FileSystemException) {
      return DownloadFailureReason.storage;
    }
    return _reasonForFailure(failure);
  }

  static DownloadFailureReason _reasonForFailure(Failure failure) =>
      switch (failure) {
        UnauthorizedFailure() => DownloadFailureReason.unauthorized,
        InsufficientStorageFailure() =>
          DownloadFailureReason.insufficientStorage,
        UnavailableFailure() => DownloadFailureReason.unavailable,
        RecoverableFailure() => DownloadFailureReason.network,
        _ => DownloadFailureReason.unknown,
      };
}
