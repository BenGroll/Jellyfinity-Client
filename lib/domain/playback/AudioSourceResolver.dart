import '../../core/result/result.dart';
import '../media/MediaId.dart';
import 'stream_quality.dart';

/// Turns a [MediaId] into an address [PlaybackEngine] can stream from.
///
/// The audio counterpart to `ArtworkResolver`, and deliberately just as
/// narrow: only the address, not display metadata (that comes from
/// `QueueEntry`) and not the engine (that's `PlaybackEngine`). Unlike
/// artwork, a stream needs authentication, which is why this returns a
/// `Result` rather than a nullable `Uri` — there is a real failure mode
/// (signed out, wrong server) worth reporting distinctly from "no
/// artwork."
abstract class AudioSourceResolver {
  /// Where to stream [id] from, at [quality].
  Future<Result<Uri>> resolve(
    MediaId id, {
    StreamQuality quality = StreamQuality.original,
  });
}

/// The injectable name the *server-backed* [AudioSourceResolver] is
/// registered under.
///
/// From v0.2.0 the unnamed registration belongs to
/// `LocalFirstAudioSourceResolver`, which prefers a completed download
/// and falls back to the server. Anything that specifically needs the
/// server address — downloading the file in the first place — asks for
/// this name instead, and everything that just wants to play a track
/// keeps asking for the bare contract.
const String remoteAudioSourceResolver = 'remoteAudioSourceResolver';
