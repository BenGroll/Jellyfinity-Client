import 'package:equatable/equatable.dart';

import '../media/MediaId.dart';
import '../media/MediaImage.dart';

/// What this queue was built from, when its entries cannot say
/// (v0.4.2).
///
/// A queue is a list of tracks, and a track already names its album and
/// its artists — which is why listening history can attribute a play to
/// either without help (ADR-0025). A playlist is the one thing it cannot:
/// nothing about "So What" says it was played from *Late Night*, and
/// asking the server which playlists contain it would answer with all of
/// them.
///
/// So the queue remembers. ADR-0026 called this a "queue origin" and
/// deferred it; this is it, deliberately no bigger than the one question
/// it answers — a queue has an origin exactly when a playlist started it,
/// and `null` every other time.
///
/// It is state about the queue as a whole rather than about any entry,
/// which is why it rides the same key-value store the shuffled play order
/// does (ADR-0031) instead of a column on every row.
class QueueOrigin extends Equatable {
  const QueueOrigin.playlist({
    required this.playlistId,
    required this.name,
    this.image,
  });

  /// The playlist this queue was started from.
  final MediaId playlistId;

  /// Its name at the time — enough to say "from Late Night" without a
  /// read, and to render a history row for a playlist that has since been
  /// renamed or deleted.
  final String name;

  final MediaImage? image;

  @override
  List<Object?> get props => [playlistId, name, image];
}
