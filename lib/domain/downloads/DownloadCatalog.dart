import 'package:equatable/equatable.dart';

import '../media/MediaId.dart';
import 'download_state.dart';
import 'DownloadOwner.dart';
import 'PlaylistDownload.dart';
import 'TrackDownload.dart';

/// What one collection's worth of downloads adds up to.
///
/// `ROADMAP.md` v0.2.0: an album's action shows aggregate progress and
/// "does not conceal a failed track" — so a summary carries the failed
/// count beside the finished one rather than reducing everything to a
/// single percentage.
class CollectionDownloadStatus extends Equatable {
  const CollectionDownloadStatus({
    required this.total,
    required this.completed,
    required this.pending,
    required this.failed,
    required this.paused,
    this.progress,
  });

  static const CollectionDownloadStatus none = CollectionDownloadStatus(
    total: 0,
    completed: 0,
    pending: 0,
    failed: 0,
    paused: 0,
  );

  /// How many tracks this collection asked for.
  final int total;
  final int completed;

  /// Queued or downloading right now.
  final int pending;
  final int failed;
  final int paused;

  /// Byte-weighted progress across the whole collection, `0.0`–`1.0`, or
  /// `null` when too little is known to state one. Falls back to
  /// track counts when the server has not reported sizes.
  final double? progress;

  /// Nothing has been asked for.
  bool get isEmpty => total == 0;

  /// Every requested track is on the device.
  bool get isComplete => total > 0 && completed == total;

  /// Work is still going on.
  bool get isActive => pending > 0;

  /// Something needs the user: a failure or a paused transfer.
  bool get needsAttention => failed > 0 || paused > 0;

  @override
  List<Object?> get props => [
    total,
    completed,
    pending,
    failed,
    paused,
    progress,
  ];
}

/// Every download Jellyfinity is keeping track of, as one immutable
/// snapshot.
///
/// This is `DownloadsCubit`'s state: screens read it to decide what a
/// download button should say, so it answers by id (a track row) and by
/// owner (an album header) without any screen having to hold its own
/// copy or run its own query.
class DownloadCatalog extends Equatable {
  const DownloadCatalog({
    this.downloads = const {},
    this.playlistSnapshots = const {},
    this.isLoaded = false,
  });

  static const DownloadCatalog empty = DownloadCatalog();

  /// Every record, keyed by the track it belongs to.
  final Map<MediaId, TrackDownload> downloads;

  /// The ordered membership snapshot of every downloaded playlist
  /// (v0.2.1), keyed by playlist id. A playlist absent here has not been
  /// downloaded; its presence — even with an empty list — means it has.
  final Map<MediaId, List<PlaylistDownloadMember>> playlistSnapshots;

  /// Whether the stored records have been read yet. Before that, a
  /// screen shows nothing rather than briefly claiming nothing is
  /// downloaded.
  final bool isLoaded;

  /// The record for [id], or `null` when it was never requested.
  TrackDownload? operator [](MediaId id) => downloads[id];

  /// [id]'s state, or `null` when it was never requested.
  DownloadState? stateOf(MediaId id) => downloads[id]?.state;

  /// Whether [id] is on the device and playable without the server.
  bool isDownloaded(MediaId id) =>
      downloads[id]?.state == DownloadState.completed;

  /// Every record [owner] asked for.
  Iterable<TrackDownload> ownedBy(DownloadOwner owner) =>
      downloads.values.where((download) => download.owners.contains(owner));

  /// Whether [playlistId] has been downloaded — a snapshot exists for it,
  /// whatever state its members are in.
  bool isPlaylistDownloaded(MediaId playlistId) =>
      playlistSnapshots.containsKey(playlistId);

  /// The downloaded tracks of [playlistId], in the order the snapshot
  /// recorded — what plays when the playlist is opened offline. A member
  /// whose record has since gone is skipped rather than left as a hole.
  List<TrackDownload> playlistDownloadsInOrder(MediaId playlistId) {
    final snapshot = playlistSnapshots[playlistId];
    if (snapshot == null) return const [];
    return [
      for (final member in snapshot)
        if (downloads[member.trackId] case final TrackDownload record) record,
    ];
  }

  /// What [owner]'s downloads add up to.
  CollectionDownloadStatus statusFor(DownloadOwner owner) {
    var total = 0;
    var completed = 0;
    var pending = 0;
    var failed = 0;
    var paused = 0;
    var receivedBytes = 0;
    var totalBytes = 0;
    var everySizeKnown = true;

    for (final download in ownedBy(owner)) {
      total++;
      switch (download.state) {
        case DownloadState.completed:
          completed++;
        case DownloadState.queued:
        case DownloadState.downloading:
          pending++;
        case DownloadState.failed:
          failed++;
        case DownloadState.paused:
          paused++;
      }
      final size = download.totalBytes;
      if (size == null || size <= 0) {
        everySizeKnown = false;
      } else {
        totalBytes += size;
        receivedBytes += download.state == DownloadState.completed
            ? size
            : download.receivedBytes;
      }
    }

    if (total == 0) return CollectionDownloadStatus.none;

    // Byte-weighted while every size is known; otherwise the honest
    // answer is "this many of that many tracks", not a percentage
    // extrapolated from the sizes that happen to have arrived.
    final progress = everySizeKnown && totalBytes > 0
        ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
        : completed / total;

    return CollectionDownloadStatus(
      total: total,
      completed: completed,
      pending: pending,
      failed: failed,
      paused: paused,
      progress: progress,
    );
  }

  DownloadCatalog copyWith({
    Map<MediaId, TrackDownload>? downloads,
    Map<MediaId, List<PlaylistDownloadMember>>? playlistSnapshots,
    bool? isLoaded,
  }) => DownloadCatalog(
    downloads: downloads ?? this.downloads,
    playlistSnapshots: playlistSnapshots ?? this.playlistSnapshots,
    isLoaded: isLoaded ?? this.isLoaded,
  );

  @override
  List<Object?> get props => [downloads, playlistSnapshots, isLoaded];
}
