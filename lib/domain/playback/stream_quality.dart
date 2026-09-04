/// The quality [AudioSourceResolver] should resolve a stream at.
///
/// One member today: v0.0.9 is direct-play only (`ROADMAP.md`'s "Prepare
/// playback-quality configuration architecture" without building
/// transcoding). The parameter exists on the resolver contract so a
/// transcoded/lower-bitrate option is an addition here later, not a
/// signature change through every caller.
enum StreamQuality {
  /// The original file, unmodified — Jellyfin's direct/static stream.
  original,
}
