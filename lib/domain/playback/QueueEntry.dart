import 'package:equatable/equatable.dart';

import '../media/artist.dart';
import '../media/media_availability.dart';
import '../media/MediaId.dart';
import '../media/MediaImage.dart';
import '../media/Track.dart';

/// One entry in [PlaybackQueue] — a denormalized snapshot of a [Track],
/// not a live reference to one.
///
/// A queue restored after a restart has to render — title, artist, album,
/// duration, artwork — without a network call, exactly the reason
/// `Track.dart` keeps its own album as id *and* name. Storing the
/// snapshot here, rather than looking it up again by [id], also means a
/// track queued from an uncached source (music search, per ADR-0012)
/// survives just as well as one queued from a browsed, cached list.
class QueueEntry extends Equatable {
  const QueueEntry({
    required this.id,
    required this.title,
    this.artist,
    this.albumName,
    this.duration,
    this.image,
    this.availability = MediaAvailability.remoteOnly,
  });

  factory QueueEntry.fromTrack(Track track) => QueueEntry(
    id: track.id,
    title: track.name,
    artist: track.artists.isEmpty ? null : track.artists.display,
    albumName: track.albumName,
    duration: track.duration,
    image: track.image,
    availability: track.availability,
  );

  final MediaId id;
  final String title;

  /// The joined artist credit line, e.g. "Miles Davis, John Coltrane".
  final String? artist;
  final String? albumName;
  final Duration? duration;
  final MediaImage? image;

  /// Set to [MediaAvailability.remoteUnavailable] when
  /// [PlaybackEngine.failureStream] reports this entry could not be
  /// played. The entry stays in the queue, marked, rather than being
  /// dropped.
  final MediaAvailability availability;

  QueueEntry markUnavailable() => QueueEntry(
    id: id,
    title: title,
    artist: artist,
    albumName: albumName,
    duration: duration,
    image: image,
    availability: MediaAvailability.remoteUnavailable,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    artist,
    albumName,
    duration,
    image,
    availability,
  ];
}
