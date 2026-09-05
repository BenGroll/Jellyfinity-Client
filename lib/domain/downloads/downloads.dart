/// Jellyfinity's download vocabulary (v0.2.0, ADR-0020).
///
/// What it means to keep a track on the device: what was asked for and
/// by whom ([TrackDownload], [DownloadOwner]), how far it got
/// ([DownloadState], [DownloadFailureReason]), what a collection of them
/// adds up to ([DownloadCatalog]), where the finished file can be played
/// from ([LocalAudioSource]), a downloaded playlist's ordered membership
/// snapshot ([PlaylistDownloadMember], [PlaylistDownloadChange], v0.2.1),
/// the network the device is on for the Wi-Fi-only preference
/// ([NetworkCondition], [NetworkState], v0.2.2), a downloaded album's,
/// artist's or playlist's stored identity for the offline library
/// ([DownloadedCollection], v0.2.3),
/// and the two seams underneath — durable records ([DownloadStore]) and
/// the transfer mechanism itself ([DownloadEngine]).
///
/// Nothing here knows about Jellyfin, filesystem paths, or a platform
/// download worker; those live in `lib/infrastructure/downloads/`.
///
/// Import this one file rather than reaching into the individual files.
library;

export 'download_state.dart';
export 'DownloadCatalog.dart';
export 'DownloadedCollection.dart';
export 'DownloadEngine.dart';
export 'DownloadOwner.dart';
export 'DownloadStore.dart';
export 'LocalAudioSource.dart';
export 'NetworkCondition.dart';
export 'PlaylistDownload.dart';
export 'TrackDownload.dart';
