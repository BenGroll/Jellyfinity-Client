import 'package:equatable/equatable.dart';

/// What a track's *file* actually is on the server — container, codec,
/// bitrate, sample rate — as opposed to [PlaybackSource], which is what
/// it currently streams as.
///
/// Kept separate from [Track] itself rather than added as a field on it:
/// every track in a browsed list would otherwise carry this, and it is
/// only ever useful for the one track currently playing (a Now Playing
/// detail, fetched on demand by [TrackSourceInfoResolver]).
class TrackSourceInfo extends Equatable {
  const TrackSourceInfo({
    this.container,
    this.codec,
    this.bitrateBps,
    this.sampleRateHz,
    this.bitDepth,
    this.channels,
  });

  /// The file's container, e.g. `flac`, `mp3`.
  final String? container;

  /// The audio stream's codec, e.g. `flac`, `aac`. May differ from
  /// [container] (a `.m4a` file can carry ALAC or AAC).
  final String? codec;

  final int? bitrateBps;
  final int? sampleRateHz;
  final int? bitDepth;
  final int? channels;

  @override
  List<Object?> get props => [
    container,
    codec,
    bitrateBps,
    sampleRateHz,
    bitDepth,
    channels,
  ];
}
