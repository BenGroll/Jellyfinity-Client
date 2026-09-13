import '../../domain/connected_playback/ActiveTransportRoute.dart';
import '../../domain/connected_playback/remote_command_kind.dart';
import 'PlaybackControlCubit.dart';

/// The app layer's implementation of `ActiveTransportRoute` (v0.5.7):
/// `PlaybackControlCubit.isControlling` says whether a hardware or OS
/// transport press belongs to the controlled device instead of local
/// playback, and this hands each press to the same `_send`-guarded
/// commands the mini-player, Now Playing and the queue screen already
/// use — so a target that hasn't advertised a command drops a system
/// media-key press exactly as it would a disabled on-screen button,
/// rather than the press falling through to local playback instead.
///
/// Registered with `getIt` and handed to `JustAudioPlaybackEngine` at
/// bootstrap, never constructed by injectable itself: it exists only to
/// give infrastructure a narrow, app-independent seam
/// (`ActiveTransportRoute`) onto this cubit, not to be looked up as
/// itself anywhere else.
class ActivePlaybackRouteAdapter implements ActiveTransportRoute {
  ActivePlaybackRouteAdapter(this._control);

  final PlaybackControlCubit _control;

  @override
  bool get isRemote => _control.state.isControlling;

  @override
  Future<void> play() => _sendIfAvailable(RemoteCommandKind.play, _control.play);

  @override
  Future<void> pause() =>
      _sendIfAvailable(RemoteCommandKind.pause, _control.pause);

  @override
  Future<void> next() => _sendIfAvailable(RemoteCommandKind.next, _control.next);

  @override
  Future<void> previous() =>
      _sendIfAvailable(RemoteCommandKind.previous, _control.previous);

  @override
  Future<void> seek(Duration position) => _sendIfAvailable(
    RemoteCommandKind.seek,
    () => _control.seek(position),
  );

  Future<void> _sendIfAvailable(
    RemoteCommandKind kind,
    Future<dynamic> Function() send,
  ) async {
    if (!_control.state.commandAvailable(kind)) return;
    await send();
  }
}
