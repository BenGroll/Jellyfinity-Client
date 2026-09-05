import 'dart:async';

import 'package:jellyfinity/app/downloads/DownloadsCubit.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/downloads/downloads.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
export 'package:jellyfinity/domain/downloads/downloads.dart'
    show
        DownloadCatalog,
        DownloadedCollection,
        DownloadFailureReason,
        DownloadOwner,
        DownloadOwnerKind,
        DownloadState,
        DownloadStorageProbe,
        DownloadStorageWarning,
        NetworkCondition,
        NetworkState,
        TrackDownload;
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/core/result/partial.dart' show Partial;
import 'package:jellyfinity/domain/media/MusicLibraryRepository.dart';
import 'package:jellyfinity/domain/media/page.dart'
    show Page, PageRequest, PageSource;
import 'package:jellyfinity/domain/media/PlaylistRepository.dart';
import 'music_fakes.dart'
    show FakeMusicLibraryRepository, FakePlaylistRepository;
import 'playback_fakes.dart' show FakeAudioSourceResolver;
import 'session_fakes.dart' show fakeAuthSession, fakeSessionCubit;
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
  SessionCubit? session,
  FakeStorageProbe? storage,
}) => DownloadsCubit(
  store ?? InMemoryDownloadStore(),
  engine ?? FakeDownloadEngine(),
  resolver ?? FakeAudioSourceResolver(),
  library ?? FakeMusicLibraryRepository(),
  playlists ?? FakePlaylistRepository(),
  settings ?? fakeSettingsCubit(),
  network ?? FakeNetworkCondition(),
  session ?? fakeSessionCubit(signedIn: fakeAuthSession()),
  storage ?? FakeStorageProbe(),
);

/// A [DownloadStorageProbe] a test controls. Defaults to "plenty of
/// room"; set [availableBytes] to `null` for "platform won't say" or a
/// small number to trigger the low-storage warning.
class FakeStorageProbe implements DownloadStorageProbe {
  FakeStorageProbe({this.available = 8 * 1024 * 1024 * 1024});

  int? available;

  @override
  Future<int?> availableBytes() async => available;
}

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
///
/// Scoped per profile (v0.2.3) the same way `DriftDownloadStore` is: set
/// [accountKey] to the profile a call belongs to. The default key means
/// tests that do not care about isolation need do nothing.
class InMemoryDownloadStore implements DownloadStore {
  /// The profile the next call reads and writes. Flip it to model a
  /// profile switch.
  String accountKey = 'server-1/user-1';

  final Map<String, Map<MediaId, TrackDownload>> _recordsByAccount = {};
  final Map<String, Map<MediaId, List<PlaylistDownloadMember>>>
  _snapshotsByAccount = {};
  final Map<String, Map<DownloadOwner, DownloadedCollection>>
  _collectionsByAccount = {};

  /// Set to make every write fail, for the "storage is broken" paths.
  Failure? writeFailure;

  /// The current profile's records, keyed by track — kept for the many
  /// existing tests that read `store.records` directly.
  Map<MediaId, TrackDownload> get records =>
      _recordsByAccount.putIfAbsent(accountKey, () => {});

  Map<MediaId, List<PlaylistDownloadMember>> get playlistSnapshots =>
      _snapshotsByAccount.putIfAbsent(accountKey, () => {});

  Map<DownloadOwner, DownloadedCollection> get collectionsMap =>
      _collectionsByAccount.putIfAbsent(accountKey, () => {});

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

  @override
  Future<Result<void>> saveCollection(DownloadedCollection collection) async {
    if (writeFailure case final failure?) return Result.err(failure);
    collectionsMap[collection.owner] = collection;
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> deleteCollection(DownloadOwner owner) async {
    collectionsMap.remove(owner);
    return const Result.ok(null);
  }

  @override
  Future<Result<Page<DownloadedCollection>>> collections({
    DownloadOwnerKind? kind,
    String? searchTerm,
    PageRequest page = const PageRequest.first(),
  }) async {
    final term = searchTerm?.trim().toLowerCase();
    final all =
        collectionsMap.values
            .where((c) => kind == null || c.kind == kind)
            .where(
              (c) =>
                  term == null ||
                  term.isEmpty ||
                  c.name.toLowerCase().contains(term),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final window = all
        .skip(page.startIndex)
        .take(page.limit)
        .toList(growable: false);
    return Result.ok(
      Page<DownloadedCollection>(
        content: Partial(available: window),
        startIndex: page.startIndex,
        totalCount: all.length,
        source: PageSource.cache,
      ),
    );
  }

  @override
  Future<Result<Page<TrackDownload>>> searchTrackDownloads({
    String? searchTerm,
    PageRequest page = const PageRequest.first(),
  }) async {
    final term = searchTerm?.trim().toLowerCase();
    final all =
        records.values
            .where((r) => r.state == DownloadState.completed)
            .where(
              (r) =>
                  term == null ||
                  term.isEmpty ||
                  r.title.toLowerCase().contains(term),
            )
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    final window = all
        .skip(page.startIndex)
        .take(page.limit)
        .toList(growable: false);
    return Result.ok(
      Page<TrackDownload>(
        content: Partial(available: window),
        startIndex: page.startIndex,
        totalCount: all.length,
        source: PageSource.cache,
      ),
    );
  }

  @override
  Future<Result<int>> claimLegacyDownloads() async {
    final legacyRecords = _recordsByAccount.remove('');
    final legacySnapshots = _snapshotsByAccount.remove('');
    final legacyCollections = _collectionsByAccount.remove('');
    var moved = 0;
    if (legacyRecords != null) {
      records.addAll(legacyRecords);
      moved += legacyRecords.length;
    }
    if (legacySnapshots != null) playlistSnapshots.addAll(legacySnapshots);
    if (legacyCollections != null) collectionsMap.addAll(legacyCollections);
    return Result.ok(moved);
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
