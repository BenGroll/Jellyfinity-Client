import 'CrossfadeSettings.dart';
import 'NormalizationSettings.dart';
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
    required bool preserveActiveTrack,
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

  /// Configures whether the engine applies each loaded [PlaybackSource]'s
  /// [PlaybackSource.normalizationGain] when setting playback volume
  /// (v0.1.4).
  ///
  /// Like [setCrossfade], this describes what the engine does with data
  /// it is already handed, not where that data comes from or which
  /// source is current — [PlaybackSource.normalizationGain] carries the
  /// loudness value itself, so the engine never has to know what a
  /// track, an album, or ReplayGain is. Unlike crossfade this applies
  /// immediately, including to whatever is playing right now, since
  /// there is no "next transition" a volume level waits for.
  ///
  /// A second implementation that cannot look up or apply gain may treat
  /// any setting as a no-op; it must not fail. Until this is first
  /// called an implementation must behave as
  /// [NormalizationSettings.disabled] — `PlaybackCubit` configures the
  /// engine explicitly at construction rather than assuming a default.
  Future<void> setNormalization(NormalizationSettings settings);

  /// [allowRemoteRoute] is v0.5.7's seam for a build that also wires an
  /// `ActiveTransportRoute`: `true` (the default every OS/hardware
  /// transport entry point — a lock screen, a Windows media-session
  /// button, a headset key — is invoked with, since none of them can
  /// pass an argument) lets the call go to whatever this device is
  /// remote-controlling instead of local playback. `PlaybackCubit`
  /// always passes `false`: its own calls exist to manage *this*
  /// device's local playback — including on behalf of a remote
  /// controller driving this device as its *target* (v0.5.3), a
  /// different relationship from this device controlling some third
  /// device — and must never be redirected just because this device
  /// also happens to be controlling something else. An implementation
  /// with no such route wired (every test, and any platform that never
  /// sets one) ignores this and always plays locally, the pre-v0.5.7
  /// behavior.
  Future<void> play({bool allowRemoteRoute = true});

  Future<void> pause({bool allowRemoteRoute = true});

  Future<void> seek(Duration position, {bool allowRemoteRoute = true});

  /// Jumps to [index] within the current source list.
  Future<void> skipToIndex(int index, {Duration? position});

  /// Stops playback and releases the current sources. [setSources] is
  /// needed again before anything can play.
  Future<void> stop();

  /// This device's own output volume, as a 0.0-1.0 fraction of the
  /// platform's own volume range (v0.6.0) — the OS/hardware output level,
  /// never [setNormalization]'s loudness gain or crossfade's ramp, both of
  /// which are internal to the mix and invisible to anything outside it.
  ///
  /// `null` when this platform has no settable system output volume to
  /// report. A platform that cannot must say so by returning `null` here
  /// rather than inventing a number — this is what lets
  /// `RemotePlaybackSnapshot.volume` stay honestly absent instead of
  /// silently `0`, and what a volume control's visibility is gated on.
  Future<double?> systemVolume();

  /// Sets this device's own output volume to [volume] (0.0-1.0).
  ///
  /// Only ever called after [systemVolume] has reported non-`null` for
  /// this platform — like [setNormalization], an implementation with no
  /// settable system volume must treat this as a no-op; it must not fail.
  Future<void> setSystemVolume(double volume);

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
