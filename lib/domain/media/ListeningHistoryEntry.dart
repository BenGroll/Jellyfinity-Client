import 'package:equatable/equatable.dart';

import 'ListeningContext.dart';

/// One thing this profile listened to, as listening history remembers it
/// (ADR-0025).
///
/// An entry is per-[context], not per-track: repeated plays of the same
/// album, artist or single-track context fold into the one entry, bumping
/// [lastPlayedAt] and [playCount] rather than adding a row. So the history
/// is a list of *distinct* things the user returned to, newest by
/// [lastPlayedAt] first — which is exactly what a later "recently played"
/// section needs, and nothing here shows it yet.
class ListeningHistoryEntry extends Equatable {
  const ListeningHistoryEntry({
    required this.context,
    required this.firstPlayedAt,
    required this.lastPlayedAt,
    required this.playCount,
  });

  final ListeningContext context;

  /// When this context was first listened to within the retained window.
  final DateTime firstPlayedAt;

  /// When it was last listened to — the sort key for "recently played".
  final DateTime lastPlayedAt;

  /// How many qualifying track plays have folded into this entry. At least
  /// one; twelve for an album played straight through.
  final int playCount;

  @override
  List<Object?> get props => [context, firstPlayedAt, lastPlayedAt, playCount];
}
