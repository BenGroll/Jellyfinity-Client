import 'jellyfin_server.dart';

/// Stores the set of Jellyfin servers the user has saved.
///
/// Non-secret data only — a server is an address and a name. The v0.0.5
/// implementation is a JSON file (see the infrastructure layer and
/// ADR-0009); v0.0.6's persistence milestone replaces it with the real
/// local database behind this same contract, so nothing above this
/// interface changes.
///
/// Kept narrow on purpose (ADR-0001: "avoid a single giant repository
/// interface"): just what the auth/account feature needs.
abstract class ServerRegistry {
  /// Every saved server, in insertion order.
  Future<List<JellyfinServer>> all();

  /// The saved server with [id], or `null` if it was removed.
  Future<JellyfinServer?> byId(String id);

  /// The saved server whose [JellyfinServer.baseUrl] matches [baseUrl]
  /// exactly (both already normalized), or `null`. Used so connecting to
  /// an address that is already saved reuses its entry instead of
  /// duplicating it.
  Future<JellyfinServer?> byBaseUrl(String baseUrl);

  /// Inserts [server], or replaces the existing entry with the same
  /// [JellyfinServer.id].
  Future<void> save(JellyfinServer server);

  /// Removes the server with [id] if present. Callers are responsible for
  /// also removing that server's accounts and their credentials.
  Future<void> remove(String id);
}
