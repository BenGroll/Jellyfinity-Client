import 'package:equatable/equatable.dart';

import '../media/MediaId.dart';
import '../media/MediaImage.dart';

/// One resolved, playable thing, as [PlaybackEngine] needs it.
///
/// Carries display metadata alongside the address so the system media
/// session (lock screen, notification) has a title/artist/artwork the
/// instant a source loads, rather than waiting on a repository round
/// trip on every track change. `PlaybackCubit` builds this by combining
/// a [QueueEntry]'s denormalized fields with the [Uri]
/// [AudioSourceResolver] resolves.
class PlaybackSource extends Equatable {
  const PlaybackSource({
    required this.id,
    required this.uri,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.image,
  });

  final MediaId id;
  final Uri uri;
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final MediaImage? image;

  @override
  List<Object?> get props => [id, uri, title, artist, album, duration, image];
}
