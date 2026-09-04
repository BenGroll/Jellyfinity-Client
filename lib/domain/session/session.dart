/// Jellyfinity's session domain (v0.0.5).
///
/// The first real content in `lib/domain/`. Authentication is the first
/// feature whose concepts every *later* feature needs — media browsing and
/// playback all need "which server, which user, which token" — so per
/// ADR-0001 these graduate straight into `lib/domain/` rather than living
/// inside the auth feature. See ADR-0009.
///
/// The five concepts `CONTEXT.md` keeps distinct map to:
/// - server → [JellyfinServer]
/// - Jellyfin user → [JellyfinAccount] (a user *as saved on* a server)
/// - credential/token → [CredentialStore] (the token itself is never a
///   domain value that gets passed around; it lives in [AuthSession] at
///   runtime and the credential store at rest)
/// - saved profile → [JellyfinAccount]
/// - active profile → [AccountStore.activeAccountId] / [AuthSession]
library;

export 'AccountStore.dart';
export 'AuthSession.dart';
export 'AuthenticatedUser.dart';
export 'CredentialStore.dart';
export 'JellyfinAccount.dart';
export 'JellyfinAuthenticator.dart';
export 'JellyfinServer.dart';
export 'ServerRegistry.dart';
