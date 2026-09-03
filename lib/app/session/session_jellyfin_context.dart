import 'package:injectable/injectable.dart';

import '../../infrastructure/jellyfin/identity/jellyfin_session_context.dart';
import 'auth_session_manager.dart';

/// The real [JellyfinSessionContext]: reports the active profile's
/// server and user to the Jellyfin media layer.
///
/// Sits beside `SessionAuthTokenProvider` and works the same way — an
/// app-layer implementation of an interface the transport layer declares,
/// reading in-memory session state, so it costs nothing per request.
@LazySingleton(as: JellyfinSessionContext)
class SessionJellyfinContext implements JellyfinSessionContext {
  SessionJellyfinContext(this._sessions);

  final AuthSessionManager _sessions;

  @override
  String? get serverId => _sessions.current?.server.id;

  @override
  String? get baseUrl => _sessions.current?.server.baseUrl;

  @override
  String? get userId => _sessions.current?.account.userId;
}
