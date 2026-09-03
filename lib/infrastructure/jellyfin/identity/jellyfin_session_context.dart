/// What the Jellyfin layer needs to know about the signed-in profile in
/// order to make a request on its behalf.
///
/// The same seam as `AuthTokenProvider` (ADR-0008), for the same reason:
/// the transport layer must not depend on the session/composition layer,
/// so it declares the small interface it needs and `lib/app` implements
/// it. Media requests need three things beyond the token — where the
/// server is, which Jellyfin user is asking, and which saved server this
/// is, since that last one becomes half of every `MediaId`.
///
/// All three are `null` when no profile is active. Repositories treat
/// that as `UnauthorizedFailure` rather than crashing, which is what
/// makes a request that arrives during sign-out fail cleanly.
abstract class JellyfinSessionContext {
  /// Jellyfinity's local id for the active server.
  String? get serverId;

  /// The active server's normalized base URL.
  String? get baseUrl;

  /// The active profile's Jellyfin user id.
  String? get userId;
}
