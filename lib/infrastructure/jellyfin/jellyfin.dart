/// Jellyfinity's Jellyfin transport layer (v0.0.4, extended in v0.0.5 and
/// v0.0.7).
///
/// The reusable networking foundation every later Jellyfin-backed feature
/// builds on: a `dio`-based HTTP client with the Jellyfin identity/auth
/// header, bounded retry and request tracing; server URL normalization;
/// the minimum-version policy; API DTOs kept separate from domain models;
/// transport errors normalized to the ADR-0004 `Failure` model;
/// `JellyfinServerProbe` to validate a server; and (v0.0.5)
/// `DioJellyfinAuthenticator` for `AuthenticateByName` credential login.
///
/// v0.0.7 adds the media layer under `media/`: the polymorphic
/// `BaseItemDto`, the `BaseItemMapper` that is the only translator
/// between Jellyfin items and Jellyfinity entities, the session-scoped
/// `JellyfinMediaApi`, and the implementations of the domain media
/// repository contracts.
///
/// Import this one file rather than reaching into the subfolders.
library;

export 'auth/authentication_result_dto.dart';
export 'auth/dio_jellyfin_authenticator.dart';
export 'http/jellyfin_http_client.dart';
export 'http/jellyfin_interceptors.dart';
export 'http/transport_error_mapper.dart';
export 'identity/auth_token_provider.dart';
export 'identity/jellyfin_client_identity.dart';
export 'identity/jellyfin_session_context.dart';
export 'media/base_item_dto.dart';
export 'media/base_item_mapper.dart';
export 'media/items_response_dto.dart';
export 'media/jellyfin_artwork_resolver.dart';
export 'media/jellyfin_media_api.dart';
export 'media/jellyfin_media_metadata_repository.dart';
export 'media/jellyfin_music_library_repository.dart';
export 'media/jellyfin_playback_progress_repository.dart';
export 'media/jellyfin_playlist_repository.dart';
export 'server/jellyfin_server_info.dart';
export 'server/jellyfin_server_probe.dart';
export 'server/jellyfin_server_url.dart';
export 'server/minimum_server_version_policy.dart';
export 'server/public_system_info_dto.dart';
export 'server/server_version.dart';
