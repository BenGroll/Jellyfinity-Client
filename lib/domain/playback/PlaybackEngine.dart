import 'CrossfadeSettings.dart';
import 'PlaybackFailure.dart';
import 'PlaybackSource.dart';
import 'playback_status.dart';

/// Plays an ordered list of resolved sources. Nothing more.
///
/// This is Jellyfinity's swappable boundary (ADR-0013): the engine has no
/// idea what a queue, shuffle or repeat is. `PlaybackQueue` computes the
/// actual play order — including a shuffled one — and `PlaybackCubit`
/// hands it to [setSources] as a plain list. Subsequent queue changes are
/// applied through [updateSources] so a native playlist can be edited without
/// interrupting the current source.
///
/// Keeping the contract this narrow is what makes a second implementation
/// (e.g. over `media_kit`) a real one-class swap: it only has to satisfy
/// "play this list, report position/status/current index," never
/// Jellyfinity's specific repeat/shuffle semantics.
///
/// The one production implementation, [JustAudioPlaybackEngine][1], is
/// also the `audio_service` handler — background execution and system
/// media controls are not a layer on top of playback on Android/iOS,
/// they are playback.
///
/// [1]: ../../infrastructure/playback/JustAudioPlaybackEngine.dart
abstract class PlaybackEngine {
  /// Replaces whatever is currently loaded with [sources] and starts
  /// loading [initialIndex] (at [initialPosition], for resuming a
  /// restored queue). Does not start playback — call [play] for that, so
  /// a cold-start restore can prime the engine without a surprise
  /// auto-play.
  Future<void> setSources(
    List<PlaybackSource> sources, {
    required int initialIndex,
    Duration? initialPosition,
  });

  /// Applies a changed playlist without replacing the native player playlist.
  /// Implementations should preserve the currently playing source and position
  /// whenever that source still exists in [sources].
  Future<void> updateSources(
    List<PlaybackSource> sources, {
    required int initialIndex,
    Duration? initialPosition,
    required bool resumePlaying,
  });

  /// Configures how the engine transitions between two consecutive
  /// sources (ADR-0016). Applies from the next transition onwards; it
  /// never reloads or interrupts what is currently playing.
  ///
  /// This stays inside the seam because it describes the *handover*
  /// between two sources the engine was already given, not which source
  /// comes next — that remains `PlaybackQueue`'s answer. A second
  /// implementation that cannot overlap sources may treat an enabled
  /// setting as a no-op; it must not fail.
  ///
  /// Until this is first called an implementation must behave as
  /// [CrossfadeSettings.disabled] — `PlaybackCubit` configures the engine
  /// explicitly at construction rather than assuming a default, so a
  /// second implementation never has to guess one.
  Future<void> setCrossfade(CrossfadeSettings settings);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  /// Jumps to [index] within the current source list.
  Future<void> skipToIndex(int index, {Duration? position});

  /// Stops playback and releases the current sources. [setSources] is
  /// needed again before anything can play.
  Future<void> stop();

  Stream<PlaybackStatus> get statusStream;

  /// The current source's playback position.
  Stream<Duration> get positionStream;

  /// The current source's total duration, once known. `null` before it
  /// is known or when nothing is loaded.
  Stream<Duration?> get durationStream;

  /// Which index of the currently loaded source list is current, or `null`
  /// when nothing is loaded.
  Stream<int?> get currentIndexStream;

  /// A source the engine could not play. Playback continues with
  /// whatever comes next in the list — this never stops the engine.
  Stream<PlaybackFailure> get failureStream;
}
