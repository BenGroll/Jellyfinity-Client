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

export 'account_store.dart';
export 'auth_session.dart';
export 'authenticated_user.dart';
export 'credential_store.dart';
export 'jellyfin_account.dart';
export 'jellyfin_authenticator.dart';
export 'jellyfin_server.dart';
export 'server_registry.dart';
