/// Jellyfinity's Jellyfin transport layer (v0.0.4).
///
/// The reusable networking foundation every later Jellyfin-backed feature
/// builds on: a `dio`-based HTTP client with the Jellyfin identity/auth
/// header, bounded retry and request tracing; server URL normalization;
/// the minimum-version policy; API DTOs kept separate from domain models;
/// transport errors normalized to the ADR-0004 `Failure` model; and
/// `JellyfinServerProbe` to validate a server.
///
/// Import this one file rather than reaching into the subfolders.
library;

export 'http/jellyfin_http_client.dart';
export 'http/jellyfin_interceptors.dart';
export 'http/transport_error_mapper.dart';
export 'identity/auth_token_provider.dart';
export 'identity/jellyfin_client_identity.dart';
export 'server/jellyfin_server_info.dart';
export 'server/jellyfin_server_probe.dart';
export 'server/jellyfin_server_url.dart';
export 'server/minimum_server_version_policy.dart';
export 'server/public_system_info_dto.dart';
export 'server/server_version.dart';
