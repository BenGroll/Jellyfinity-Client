import 'package:equatable/equatable.dart';

/// The counts an artist page shows alongside its discography: how much of
/// the library is credited to this artist, and for how long.
///
/// Kept off [Artist] itself, the same reasoning as `TrackSourceInfo` being
/// kept off `Track`: nothing that browses a list of artists needs these
/// numbers, and computing them costs its own queries (`ArtistStats.dart`'s
/// only reader, the artist detail page, already asks for them on demand).
///
/// [totalDuration] is `null` when the artist has too many tracks to sum
/// within [durationSumLimit] — the count is still shown, the running time
/// is simply omitted rather than fetching an unbounded number of tracks
/// for one label.
class ArtistStats extends Equatable {
  const ArtistStats({
    required this.albumCount,
    required this.songCount,
    this.totalDuration,
  });

  /// How many tracks [totalDuration] will be summed across before giving
  /// up on a total — bounds a single artist page's worth of fetching
  /// (`CONTEXT.md`'s "never load a whole library into memory" scoped to
  /// one artist rather than the library).
  static const int durationSumLimit = 2000;

  final int albumCount;
  final int songCount;
  final Duration? totalDuration;

  @override
  List<Object?> get props => [albumCount, songCount, totalDuration];
}
