import '../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../session/SessionState.dart';

/// The saved server and Jellyfin user of the active profile, or `null`
/// when nothing is signed in.
///
/// Built from the server's *local* id and the account's user id rather
/// than from the saved account — two saved accounts can point at the
/// same user on the same server, and their devices are the same devices.
///
/// Shared by every connected-playback link that has to know "what profile
/// is this for" from `SessionCubit` — [ConnectedPlaybackLink] and
/// [ConnectedPlaybackTargetLink] each track their own lifecycle against
/// the same session stream, and both must agree on exactly this mapping.
ConnectedPlaybackScope? connectedPlaybackScopeOf(SessionState state) {
  final session = state.session;
  if (session == null) return null;
  return ConnectedPlaybackScope(
    serverId: session.server.id,
    userId: session.account.userId,
  );
}
