/// The coarse session fact the router's auth gate keys off of.
///
/// The full session (which server, which profile, the token) lives on
/// [SessionState]; the router only needs these three cases to choose
/// between the splash screen, the onboarding flow, and the app shell.
enum SessionStatus {
  /// Startup: a saved session is still being restored from storage.
  unknown,

  /// No active profile. The user is in onboarding / sign-in.
  unauthenticated,

  /// An active profile with a token exists; the app shell is reachable.
  authenticated,
}
