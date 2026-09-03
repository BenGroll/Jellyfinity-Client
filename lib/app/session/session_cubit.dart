import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'session_status.dart';

/// Holds the current [SessionStatus] for the whole app and is the router's
/// `refreshListenable` source (via `GoRouterRefreshStream`).
///
/// v0.0.3 scope: this is a deliberate stub. It has no dependencies, starts
/// [SessionStatus.unauthenticated], and only changes when the development
/// welcome screen calls [signInForDevelopment] / [signOut]. The
/// authentication milestone (v0.0.5) replaces the body of this class with
/// real session restore and Jellyfin credential handling — the type and
/// its place in the composition root are meant to stay.
@lazySingleton
class SessionCubit extends Cubit<SessionStatus> {
  SessionCubit() : super(SessionStatus.unauthenticated);

  /// Stand-in for a successful login, used only by the dev welcome screen.
  void signInForDevelopment() => emit(SessionStatus.authenticated);

  /// Clears the (stub) session and returns the user to onboarding.
  void signOut() => emit(SessionStatus.unauthenticated);
}
