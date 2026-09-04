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
export 'auth/DioJellyfinAuthenticator.dart';
export 'http/JellyfinHttpClient.dart';
export 'http/jellyfin_interceptors.dart';
export 'http/TransportErrorMapper.dart';
export 'identity/auth_token_provider.dart';
export 'identity/JellyfinClientIdentity.dart';
export 'identity/JellyfinSessionContext.dart';
export 'media/base_item_dto.dart';
export 'media/BaseItemMapper.dart';
export 'media/ItemsResponseDto.dart';
export 'media/JellyfinArtworkResolver.dart';
export 'media/jellyfin_media_api.dart';
export 'media/JellyfinMediaMetadataRepository.dart';
export 'media/JellyfinMusicLibraryRepository.dart';
export 'media/JellyfinPlaybackProgressRepository.dart';
export 'media/JellyfinPlaylistRepository.dart';
export 'server/JellyfinServerInfo.dart';
export 'server/JellyfinServerProbe.dart';
export 'server/JellyfinServerUrl.dart';
export 'server/MinimumServerVersionPolicy.dart';
export 'server/PublicSystemInfoDto.dart';
export 'server/ServerVersion.dart';
