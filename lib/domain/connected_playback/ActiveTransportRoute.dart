/// Where a hardware or OS-level transport command should go while this
/// device might be controlling another one instead of playing locally
/// (v0.5.7).
///
/// `JustAudioPlaybackEngine` is both the domain `PlaybackEngine` and the
/// `audio_service` handler the OS calls directly, so its `play`/`pause`/
/// `seek`/`skipToNext`/`skipToPrevious` are the one place a lock-screen,
/// Windows media-session, or hardware media-key press arrives without
/// passing through any app-layer widget or cubit first. Everywhere else,
/// a screen already reads `PlaybackControlCubit.isControlling` before
/// deciding whether to command the target or local `PlaybackCubit`
/// (`MiniPlayer`'s own doc calls this "never the other way around"); this
/// is that same choice made available to infrastructure, without
/// infrastructure depending on the app-layer cubit that owns it
/// (dependency direction: the app layer implements this interface and
/// hands infrastructure only this narrow contract).
abstract class ActiveTransportRoute {
  /// True while a hardware/OS transport command should be sent to the
  /// controlled device instead of applied to local playback.
  bool get isRemote;

  /// Sends the equivalent of a "play" press. A no-op if the target has
  /// not advertised the command, the same as a disabled button would be.
  Future<void> play();

  Future<void> pause();

  Future<void> next();

  Future<void> previous();

  /// Seeks the target to an absolute [position] — the OS/system seek
  /// bar's unit, unlike a relative fast-forward/rewind step.
  Future<void> seek(Duration position);
}
