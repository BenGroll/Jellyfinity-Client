/// The quality [AudioSourceResolver] should resolve a stream at.
///
/// v0.0.9 shipped this with one member (`original`) and a resolver
/// parameter built ahead of the feature, specifically so a transcoded/
/// lower-bitrate option would be an addition here later, not a signature
/// change through every caller. v0.1.1 is that addition (ADR-0015).
enum StreamQuality {
  /// The original file, unmodified — Jellyfin's direct/static stream. No
  /// transcoding, whatever the file's own bitrate/codec.
  original,

  /// A transcode targeting [highBitrateBps] — close to source quality for
  /// most lossy libraries, a real reduction for lossless ones.
  high,

  /// A transcode targeting [mediumBitrateBps] — a middle ground between
  /// [high] and [dataSaver].
  medium,

  /// A transcode targeting [dataSaverBitrateBps] — the smallest tier, for
  /// constrained connections.
  dataSaver;

  static const int highBitrateBps = 320000;
  static const int mediumBitrateBps = 192000;
  static const int dataSaverBitrateBps = 128000;

  /// The codec every transcoded tier requests — AAC, for broad Android/
  /// iOS decoder support without a per-platform codec choice.
  static const String transcodeCodec = 'aac';

  /// The bitrate a transcode should target, or `null` for [original],
  /// which has no target — it is whatever the source file already is.
  int? get targetBitrateBps => switch (this) {
    StreamQuality.original => null,
    StreamQuality.high => highBitrateBps,
    StreamQuality.medium => mediumBitrateBps,
    StreamQuality.dataSaver => dataSaverBitrateBps,
  };

  /// Whether this tier asks Jellyfin to transcode rather than stream the
  /// original file untouched.
  bool get isTranscoded => this != StreamQuality.original;

  static const StreamQuality fallback = StreamQuality.original;

  static StreamQuality? tryParse(String? raw) => switch (raw) {
    'original' => StreamQuality.original,
    'high' => StreamQuality.high,
    'medium' => StreamQuality.medium,
    'dataSaver' => StreamQuality.dataSaver,
    _ => null,
  };
}
