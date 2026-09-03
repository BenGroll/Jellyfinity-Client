import 'package:equatable/equatable.dart';

import '../../domain/session/auth_session.dart';
import 'session_status.dart';

/// The whole-app session state held by [SessionCubit].
///
/// [status] is what the router redirect switches on; [session] carries
/// the resolved active profile once signed in (the shell and account
/// switcher read it). [lastAccountId] remembers the profile that was
/// active when a token went stale, so the re-login screen can prefill it.
class SessionState extends Equatable {
  const SessionState._(this.status, {this.session, this.lastAccountId});

  /// Startup, before storage has been read.
  const SessionState.restoring() : this._(SessionStatus.unknown);

  /// Signed out. [lastAccountId] is set when this followed a token
  /// expiry rather than an explicit logout.
  const SessionState.signedOut({String? lastAccountId})
    : this._(SessionStatus.unauthenticated, lastAccountId: lastAccountId);

  /// Signed in as [session]'s profile.
  const SessionState.signedIn(AuthSession session)
    : this._(SessionStatus.authenticated, session: session);

  final SessionStatus status;
  final AuthSession? session;
  final String? lastAccountId;

  @override
  List<Object?> get props => [status, session, lastAccountId];
}
