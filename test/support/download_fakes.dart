import 'dart:async';

import 'package:jellyfinity/app/downloads/DownloadsCubit.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/downloads/downloads.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
export 'package:jellyfinity/domain/downloads/downloads.dart'
    show
        DownloadFailureReason,
        DownloadOwner,
        DownloadState,
        NetworkCondition,
        NetworkState,
        TrackDownload;
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/domain/media/MusicLibraryRepository.dart';
import 'package:jellyfinity/domain/media/PlaylistRepository.dart';
import 'music_fakes.dart'
    show FakeMusicLibraryRepository, FakePlaylistRepository;
import 'playback_fakes.dart' show FakeAudioSourceResolver;
import 'settings_fakes.dart' show fakeSettingsCubit;

/// A [DownloadsCubit] wired entirely to fakes, for tests that only need
/// one to exist because the widget tree provides it.
DownloadsCubit fakeDownloadsCubit({
  InMemoryDownloadStore? store,
  FakeDownloadEngine? engine,
  FakeAudioSourceResolver? resolver,
  MusicLibraryRepository? library,
  PlaylistRepository? playlists,
  SettingsCubit? settings,
  FakeNetworkCondition? network,
}) => DownloadsCubit(
  store ?? InMemoryDownloadStore(),
  engine ?? FakeDownloadEngine(),
  resolver ?? FakeAudioSourceResolver(),
  library ?? FakeMusicLibraryRepository(),
  playlists ?? FakePlaylistRepository(),
  settings ?? fakeSettingsCubit(),
  network ?? FakeNetworkCondition(),
);

/// A [NetworkCondition] a test drives: set [state] and push changes.
class FakeNetworkCondition implements NetworkCondition {
  FakeNetworkCondition({this.state = NetworkState.unmetered});

  NetworkState state;
  final _controller = StreamController<NetworkState>.broadcast();

  @override
  Future<NetworkState> current() async => state;

  @override
  Stream<NetworkState> changes() => _controller.stream;

  /// Moves to [next] and notifies listeners, the way a real device
  /// dropping from Wi-Fi to cellular would.
  void moveTo(NetworkState next) {
    state = next;
    _controller.add(next);
  }
}

/// A [DownloadStore] with no database behind it.
class InMemoryDownloadStore implements DownloadStore {
  final Map<MediaId, TrackDownload> records = {};

  /// Playlist membership snapshots, keyed by playlist id (v0.2.1).
  final Map<MediaId, List<PlaylistDownloadMember>> playlistSnapshots = {};

  /// Set to make every write fail, for the "storage is broken" paths.
  Failure? writeFailure;

  @override
  Future<Result<List<TrackDownload>>> all() async {
    final sorted = records.values.toList()
      ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    return Result.ok(sorted);
  }

  @override
  Future<Result<TrackDownload?>> find(MediaId id) async =>
      Result.ok(records[id]);

  @override
  Future<Result<void>> save(TrackDownload download) async {
    if (writeFailure case final failure?) return Result.err(failure);
    records[download.id] = download;
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> delete(MediaId id) async {
    records.remove(id);
    return const Result.ok(null);
  }

  @override
  Future<Result<List<MediaId>>> ownedBy(DownloadOwner owner) async =>
      Result.ok([
        for (final record in records.values)
          if (record.owners.contains(owner)) record.id,
      ]);

  @override
  Future<Result<void>> savePlaylistMembers(
    MediaId playlistId,
    List<PlaylistDownloadMember> members,
  ) async {
    if (writeFailure case final failure?) return Result.err(failure);
    if (members.isEmpty) {
      playlistSnapshots.remove(playlistId);
    } else {
      playlistSnapshots[playlistId] = List.of(members);
    }
    return const Result.ok(null);
  }

  @override
  Future<Result<List<PlaylistDownloadMember>>> playlistMembers(
    MediaId playlistId,
  ) async => Result.ok(playlistSnapshots[playlistId] ?? const []);

  @override
  Future<Result<Map<MediaId, List<PlaylistDownloadMember>>>>
  allPlaylistMembers() async => Result.ok({
    for (final entry in playlistSnapshots.entries)
      entry.key: List.of(entry.value),
  });

  @override
  Future<Result<void>> deletePlaylistMembers(MediaId playlistId) async {
    playlistSnapshots.remove(playlistId);
    return const Result.ok(null);
  }
}

/// A [DownloadEngine] a test drives directly: it records what it was
/// asked to do, and answers with whatever the test set up.
class FakeDownloadEngine implements DownloadEngine {
  /// Every id [fetch] was called for, in order.
  final List<MediaId> fetched = [];

  /// Every id [discard] was called for.
  final List<MediaId> discarded = [];

  /// Every id [abort] was called for.
  final List<MediaId> aborted = [];

  /// Ids that fail instead of completing, and how.
  final Map<MediaId, Failure> failures = {};

  /// Bytes an interrupted transfer already has on disk.
  final Map<MediaId, int> partials = {};

  /// Ids whose file is on disk, as [locate] reports it.
  final Map<MediaId, Uri> stored = {};

  /// Progress each fetch reports before it finishes.
  List<DownloadProgress> progressUpdates = const [];

  /// Held open by a test that wants a transfer to stay in flight.
  final Map<MediaId, Completer<void>> gates = {};

  int byteCount = 1024;

  @override
  Future<Result<StoredDownload>> fetch(
    MediaId id,
    Uri source, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    fetched.add(id);
    for (final progress in progressUpdates) {
      onProgress?.call(progress);
    }
    if (gates[id] case final gate?) await gate.future;
    if (failures[id] case final failure?) return Result.err(failure);
    final address = Uri.file('/downloads/${id.itemId}/audio.flac');
    stored[id] = address;
    return Result.ok(StoredDownload(address: address, byteCount: byteCount));
  }

  @override
  Future<void> abort(MediaId id) async {
    aborted.add(id);
    gates.remove(id)?.complete();
  }

  @override
  Future<void> discard(MediaId id) async {
    discarded.add(id);
    stored.remove(id);
    partials.remove(id);
  }

  @override
  Future<Uri?> locate(MediaId id) async => stored[id];

  @override
  Future<int> partialByteCount(MediaId id) async => partials[id] ?? 0;
}

/// A minimal [TrackDownload] for tests that only care about its id and
/// state — the download system's counterpart to `testTrack`.
TrackDownload downloadRecord(
  MediaId id, {
  String? title,
  required DownloadState state,
  Set<DownloadOwner>? owners,
  DateTime? requestedAt,
  int receivedBytes = 0,
  int? totalBytes,
  DownloadFailureReason? failureReason,
}) => TrackDownload(
  id: id,
  title: title ?? 'Track ${id.itemId}',
  state: state,
  owners: owners ?? {DownloadOwner.track(id)},
  requestedAt: requestedAt ?? DateTime.utc(2026, 1, 1),
  receivedBytes: receivedBytes,
  totalBytes: totalBytes,
  failureReason: failureReason,
);
