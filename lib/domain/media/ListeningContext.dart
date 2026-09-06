import 'package:equatable/equatable.dart';

import 'MediaId.dart';
import 'MediaImage.dart';

/// What a single act of listening was *about* — the album, artist, or (for
/// a song played on its own) the track.
///
/// Listening history collapses on this (ADR-0025): playing an album
/// straight through is one thing the user did, so twelve track plays that
/// all share an album context become one history entry, not twelve rows.
///
/// It also carries enough to render and open a "recently played" row
/// without asking the server — a [kind], the [id] to navigate to, a
/// [name], an optional [subtitle] (the artist credit line) and, where the
/// queue had one, an [image]. An artist context has no artwork in the
/// queue snapshot it is derived from, so [image] is null there rather
/// than the album art of whichever track was playing.
enum ListeningContextKind {
  album,
  artist,

  /// A song played with no album to attribute it to (a single, a search
  /// result). The context [id] is the track's own id.
  track,
}

class ListeningContext extends Equatable {
  const ListeningContext({
    required this.kind,
    required this.id,
    required this.name,
    this.subtitle,
    this.image,
  });

  final ListeningContextKind kind;

  /// The thing to open when the row is tapped: an album, artist or track
  /// id on the server that issued it.
  final MediaId id;

  final String name;

  /// The credit line shown under [name], when there is one.
  final String? subtitle;

  final MediaImage? image;

  @override
  List<Object?> get props => [kind, id, name, subtitle, image];
}
