import 'package:equatable/equatable.dart';

import '../../core/result/result.dart';
import '../media/MediaId.dart';

/// A file the engine has finished storing on the device.
class StoredDownload extends Equatable {
  const StoredDownload({required this.address, required this.byteCount});

  /// Where to play the file from — a `file:` address, the local
  /// counterpart to the `https:` one `AudioSourceResolver` produces.
  ///
  /// An address rather than a path on purpose: the rest of the
  /// application plays URIs, and `ROADMAP.md` v0.2.0 keeps filesystem
  /// paths inside infrastructure.
  final Uri address;

  /// The size of the stored file, in bytes.
  final int byteCount;

  @override
  List<Object?> get props => [address, byteCount];
}

/// How far a transfer has got, as the engine reports it.
typedef DownloadProgress = ({int receivedBytes, int? totalBytes});

/// The replaceable seam that actually moves bytes onto the device
/// (ADR-0020).
///
/// Everything platform-specific about downloading lives behind this
/// interface, for the same reason `PlaybackEngine` exists for playback:
/// the application's download rules — what is wanted, who wants it, what
/// state it is in, when it is removed — are Jellyfinity's own, and the
/// mechanism underneath them is expected to be swapped (a foreground
/// implementation today, an OS background-transfer one when its
/// behaviour has been proven on both platforms).
///
/// Implementations must:
///
/// - resume an interrupted transfer for the same [MediaId] rather than
///   starting it over, when the source supports it;
/// - complete atomically, so a file only becomes visible to [locate]
///   once every byte of it is written;
/// - keep the partial transfer after [abort], and delete everything
///   after [discard];
/// - never throw — a failure comes back as an `Err`.
abstract class DownloadEngine {
  /// Transfers [source] into device storage, under [id].
  ///
  /// Reports byte progress through [onProgress] as it goes. Resumes a
  /// partial transfer left by an earlier [fetch] or [abort] when one
  /// exists.
  Future<Result<StoredDownload>> fetch(
    MediaId id,
    Uri source, {
    void Function(DownloadProgress progress)? onProgress,
  });

  /// Stops an in-flight [fetch] for [id], keeping what has been
  /// transferred so far. Does nothing if [id] is not being fetched.
  Future<void> abort(MediaId id);

  /// Deletes everything stored for [id] — the completed file, a partial
  /// transfer, or neither. Safe to call for an [id] the engine has
  /// never seen.
  Future<void> discard(MediaId id);

  /// The address of the *completed* file for [id], or `null` when there
  /// is not one. A partial transfer is never returned.
  Future<Uri?> locate(MediaId id);

  /// How many bytes of a partial transfer for [id] are already on the
  /// device, so a resumed download's progress starts where it stopped.
  /// `0` when there is nothing partial.
  Future<int> partialByteCount(MediaId id);
}
