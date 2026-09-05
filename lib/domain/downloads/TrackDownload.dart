import 'package:equatable/equatable.dart';

import '../media/artist.dart';
import '../media/media_availability.dart';
import '../media/MediaId.dart';
import '../media/MediaImage.dart';
import '../media/Track.dart';
import 'download_state.dart';
import 'DownloadOwner.dart';

/// One track Jellyfinity has been asked to keep on the device, and how
/// far that has got.
///
/// Like `QueueEntry`, this is a denormalized snapshot rather than a live
/// reference to a [Track]: the whole point of a download is that it
/// still works when the server does not answer, so the record carries
/// everything needed to render the track in a list and put it in the
/// queue — title, credits, album, running time, artwork pointer and
/// loudness gain — without a lookup. [toTrack] is what turns it back
/// into the entity the rest of the app speaks.
class TrackDownload extends Equatable {
  const TrackDownload({
    required this.id,
    required this.title,
    required this.state,
    required this.owners,
    required this.requestedAt,
    this.artists = const [],
    this.albumId,
    this.albumName,
    this.trackNumber,
    this.discNumber,
    this.duration,
    this.normalizationGain,
    this.image,
    this.receivedBytes = 0,
    this.totalBytes,
    this.failureReason,
    this.serverGone = false,
  });

  /// The record a fresh request starts from.
  factory TrackDownload.requested(
    Track track, {
    required DownloadOwner owner,
    required DateTime requestedAt,
  }) => TrackDownload(
    id: track.id,
    title: track.name,
    state: DownloadState.queued,
    owners: {owner},
    requestedAt: requestedAt,
    artists: track.artists,
    albumId: track.albumId,
    albumName: track.albumName,
    trackNumber: track.trackNumber,
    discNumber: track.discNumber,
    duration: track.duration,
    normalizationGain: track.normalizationGain,
    image: track.image,
  );

  final MediaId id;
  final String title;
  final DownloadState state;

  /// Every reason this file is being kept. Never empty for a stored
  /// record — a download with no owners is one nothing wants, and is
  /// deleted rather than persisted.
  final Set<DownloadOwner> owners;

  /// When the download was first requested. Also the queue's order: the
  /// engine works through pending downloads oldest first, so a long
  /// album does not jump ahead of a song asked for before it.
  final DateTime requestedAt;

  final List<ArtistRef> artists;
  final MediaId? albumId;
  final String? albumName;
  final int? trackNumber;
  final int? discNumber;
  final Duration? duration;
  final double? normalizationGain;
  final MediaImage? image;

  /// How many bytes are on the device so far. Survives a restart, so a
  /// resumed transfer reports honest progress instead of restarting its
  /// progress bar at zero.
  final int receivedBytes;

  /// The file's full size, once the server has reported one. `null`
  /// while that is still unknown — a download in that state shows
  /// indeterminate progress rather than a made-up percentage.
  final int? totalBytes;

  /// Set only when [state] is [DownloadState.failed].
  final DownloadFailureReason? failureReason;

  /// The server has been reached since this was downloaded and no longer
  /// lists the track (v0.2.3). The file is kept; [toTrack] then reports
  /// [MediaAvailability.localOnly] so the app shows it as "Only on this
  /// device" rather than as a remote failure or by making it vanish.
  /// Never set from a merely unreachable server.
  final bool serverGone;

  /// How much of the file is on the device, `0.0`–`1.0`, or `null` when
  /// the total size is not known yet.
  double? get progress {
    final total = totalBytes;
    if (state == DownloadState.completed) return 1;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  /// Whether this track can be played without reaching the server.
  bool get isPlayableOffline => state == DownloadState.completed;

  /// The track as the rest of the application speaks about it.
  ///
  /// [availability], when omitted, is derived from the record: a
  /// completed download the server still lists is
  /// [MediaAvailability.localAndRemote]; one the server has dropped
  /// ([serverGone], v0.2.3) is [MediaAvailability.localOnly] — kept and
  /// playable, shown as "Only on this device"; an incomplete one is
  /// [MediaAvailability.remoteOnly]. A caller that knows better passes
  /// [availability] explicitly.
  Track toTrack({MediaAvailability? availability}) => Track(
    id: id,
    name: title,
    artists: artists,
    albumId: albumId,
    albumName: albumName,
    trackNumber: trackNumber,
    discNumber: discNumber,
    duration: duration,
    normalizationGain: normalizationGain,
    availability: availability ?? _availability,
    image: image,
  );

  MediaAvailability get _availability {
    if (!isPlayableOffline) return MediaAvailability.remoteOnly;
    return serverGone
        ? MediaAvailability.localOnly
        : MediaAvailability.localAndRemote;
  }

  TrackDownload copyWith({
    DownloadState? state,
    Set<DownloadOwner>? owners,
    int? receivedBytes,
    int? totalBytes,
    DownloadFailureReason? failureReason,
    bool? serverGone,
    bool clearFailureReason = false,
    bool clearTotalBytes = false,
  }) => TrackDownload(
    id: id,
    title: title,
    state: state ?? this.state,
    owners: owners ?? this.owners,
    requestedAt: requestedAt,
    artists: artists,
    albumId: albumId,
    albumName: albumName,
    trackNumber: trackNumber,
    discNumber: discNumber,
    duration: duration,
    normalizationGain: normalizationGain,
    image: image,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: clearTotalBytes ? null : (totalBytes ?? this.totalBytes),
    failureReason: clearFailureReason
        ? null
        : (failureReason ?? this.failureReason),
    serverGone: serverGone ?? this.serverGone,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    state,
    owners,
    requestedAt,
    artists,
    albumId,
    albumName,
    trackNumber,
    discNumber,
    duration,
    normalizationGain,
    image,
    receivedBytes,
    totalBytes,
    failureReason,
    serverGone,
  ];
}
