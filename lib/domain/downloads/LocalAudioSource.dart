import '../media/MediaId.dart';

/// Where a downloaded track can be played from on this device.
///
/// The narrowest possible read of the download system, and the only part
/// of it playback depends on: `LocalFirstAudioSourceResolver` asks this
/// before it asks the server, so a completed download plays whether or
/// not the server can be reached.
///
/// Deliberately not `DownloadEngine.locate` directly — a file being
/// present on disk is not the same as a download Jellyfinity considers
/// complete, and playback must only ever use the second.
abstract class LocalAudioSource {
  /// The `file:` address to play [id] from, or `null` when there is no
  /// completed download for it.
  Future<Uri?> addressFor(MediaId id);
}
