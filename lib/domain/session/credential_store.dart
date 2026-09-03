/// Stores Jellyfin access tokens in platform secure storage, keyed by
/// [JellyfinAccount.id].
///
/// This is the only place a token is persisted. The v0.0.5 implementation
/// is backed by `flutter_secure_storage` (iOS Keychain / Android Keystore
/// via EncryptedSharedPreferences) — see ADR-0009. Tokens must never be
/// written anywhere else: not the [AccountStore]'s tables, not the
/// key/value store, not logs (`Logger`'s privacy rule).
abstract class CredentialStore {
  /// The token for the account with local id [accountId], or `null` if
  /// none is stored (never logged in, or the secure entry is gone).
  Future<String?> readToken(String accountId);

  /// Stores (or replaces) the token for [accountId].
  Future<void> writeToken(String accountId, String token);

  /// Deletes the token for [accountId]. Safe to call when none exists.
  Future<void> deleteToken(String accountId);
}
