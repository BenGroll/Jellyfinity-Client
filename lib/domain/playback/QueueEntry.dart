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
///
/// [albumId] and [artists] carry the same ids `Track` does (v0.3.1): the
/// queue screen and listening history (ADR-0025) both need to open the
/// album or artist a queued track belongs to, not just print its name.
class QueueEntry extends Equatable {
  const QueueEntry({
    required this.id,
    required this.title,
    this.artist,
    this.artists = const [],
    this.albumId,
    this.albumName,
    this.duration,
    this.image,
    this.normalizationGain,
    this.availability = MediaAvailability.remoteOnly,
  });

  factory QueueEntry.fromTrack(Track track) => QueueEntry(
    id: track.id,
    title: track.name,
    artist: track.artists.isEmpty ? null : track.artists.display,
    artists: track.artists,
    albumId: track.albumId,
    albumName: track.albumName,
    duration: track.duration,
    image: track.image,
    normalizationGain: track.normalizationGain,
    availability: track.availability,
  );

  final MediaId id;
  final String title;

  /// The joined artist credit line, e.g. "Miles Davis, John Coltrane".
  final String? artist;

  /// The individual artist credits, kept for their ids so a queued track
  /// can open its artist. [artist] is the display join of these.
  final List<ArtistRef> artists;

  /// The album this track belongs to, when it has one — id for navigation
  /// and history attribution, [albumName] for display.
  final MediaId? albumId;
  final String? albumName;
  final Duration? duration;
  final MediaImage? image;

  /// Denormalized from [Track.normalizationGain] (v0.1.4), for the same
  /// reason every other display field here is: a restored queue has to
  /// hand `PlaybackCubit` a source-ready value without a network call.
  final double? normalizationGain;

  /// Set to [MediaAvailability.remoteUnavailable] when
  /// [PlaybackEngine.failureStream] reports this entry could not be
  /// played. The entry stays in the queue, marked, rather than being
  /// dropped.
  final MediaAvailability availability;

  QueueEntry markUnavailable() => QueueEntry(
    id: id,
    title: title,
    artist: artist,
    artists: artists,
    albumId: albumId,
    albumName: albumName,
    duration: duration,
    image: image,
    normalizationGain: normalizationGain,
    availability: MediaAvailability.remoteUnavailable,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    artist,
    artists,
    albumId,
    albumName,
    duration,
    image,
    normalizationGain,
    availability,
  ];
}
