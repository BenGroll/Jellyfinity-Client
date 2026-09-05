import '../../core/result/result.dart';
import '../media/MediaId.dart';
import 'Lyrics.dart';

/// Reads a track's lyrics — the same on-demand, one-track-at-a-time shape
/// as [TrackSourceInfoResolver]: nothing browses by lyrics, and Now
/// Playing/the Lyrics view are the only callers.
abstract class LyricsResolver {
  /// [id]'s lyrics, or `Ok(null)` when the track has none.
  ///
  /// A missing lyrics file is an expected empty state, not a failure
  /// (`Roadmap to v0.2.md` §v0.1.5) — `Err` is reserved for a request that
  /// genuinely could not be answered (signed out, wrong server, offline).
  Future<Result<Lyrics?>> resolve(MediaId id);
}
