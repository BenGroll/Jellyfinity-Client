/// Whether the app currently has a usable user session.
///
/// This is the single fact the router's auth gate keys off of. In v0.0.3
/// there is no real authentication yet — [SessionCubit] only moves between
/// [unauthenticated] and [authenticated] via the development welcome
/// screen, so both navigation trees exist and can be tested. The real
/// restore/login/logout transitions arrive with the authentication
/// milestone (v0.0.5), which is also when [unknown] starts being used for
/// the "still restoring a saved session at startup" window.
enum SessionStatus {
  /// Startup: not yet determined whether a saved session can be restored.
  unknown,

  /// No active profile. The user must onboard / sign in.
  unauthenticated,

  /// An active profile/session exists; the app shell is reachable.
  authenticated,
}
