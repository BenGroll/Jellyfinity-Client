import 'jellyfin_account.dart';

/// Stores the saved profiles (server + user pairings) and which one is
/// active.
///
/// Non-secret data only; tokens are the [CredentialStore]'s job. Backed by
/// the local database (`DriftAccountStore`, ADR-0010), same as
/// [ServerRegistry].
///
/// The active-account pointer lives here rather than in its own store
/// because it is always read and written together with the account list,
/// and "active profile" is meaningless without the profiles.
abstract class AccountStore {
  /// Every saved account, in insertion order.
  Future<List<JellyfinAccount>> all();

  /// Accounts belonging to the server with local id [serverId].
  Future<List<JellyfinAccount>> forServer(String serverId);

  /// The saved account with [id], or `null`.
  Future<JellyfinAccount?> byId(String id);

  /// The account for [userId] on [serverId], or `null` — used to detect
  /// re-login of an already-saved profile.
  Future<JellyfinAccount?> byServerAndUser(String serverId, String userId);

  /// Inserts [account], or replaces the entry with the same
  /// [JellyfinAccount.id].
  Future<void> save(JellyfinAccount account);

  /// Removes the account with [id]. If it was the active account, the
  /// active pointer is cleared.
  Future<void> remove(String id);

  /// The id of the active account, or `null` if none is active (no
  /// accounts, or the user logged out of all of them).
  Future<String?> activeAccountId();

  /// Sets (or, with `null`, clears) the active account. Passing an id
  /// that is not a saved account is a programming error.
  Future<void> setActiveAccountId(String? id);
}
