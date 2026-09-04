import '../../core/result/result.dart';
import '../media/MediaId.dart';
import 'TrackSourceInfo.dart';

/// Reads a track's *file* details — the audio counterpart to
/// `ArtworkResolver` and [AudioSourceResolver], and deliberately just as
/// narrow: only [TrackSourceInfo], nothing a browsed list needs.
///
/// A single-item, on-demand lookup rather than a `MusicLibraryRepository`
/// method: nothing browses by source format, and the fields it needs
/// (`MediaSources`) are too heavy to ask for on every row of a paged list
/// (`PHILOSOPHY.md` §11). Now Playing is the one caller, for one track at
/// a time.
abstract class TrackSourceInfoResolver {
  /// [id]'s file details, or a [Result.err] if it cannot be read right
  /// now (signed out, wrong server, no longer in the library).
  Future<Result<TrackSourceInfo>> resolve(MediaId id);
}
