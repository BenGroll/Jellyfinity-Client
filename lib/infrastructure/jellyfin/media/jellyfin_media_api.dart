import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/logging/Logger.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/media/page.dart';
import '../http/JellyfinHttpClient.dart';
import '../identity/auth_token_provider.dart';
import '../identity/JellyfinClientIdentity.dart';
import '../identity/JellyfinSessionContext.dart';
import 'base_item_dto.dart';
import 'BaseItemMapper.dart';
import 'ItemsResponseDto.dart';
import 'LyricsDto.dart';

/// Builds a [JellyfinHttpClient] for a base URL. Injected so tests can
/// supply a client wired to a fake `dio` adapter (the pattern
/// `JellyfinServerProbe` and `DioJellyfinAuthenticator` already use).
typedef MediaHttpClientFactory = JellyfinHttpClient Function(String baseUrl);

/// What reading one item needs before a request can be made: the mapper
/// bound to the active server, and the item's id on it.
typedef MediaScope = ({BaseItemMapper mapper, String itemId});

/// The active session's view of Jellyfin's item endpoints.
///
/// One place that knows Jellyfin's query vocabulary — `IncludeItemTypes`,
/// `ParentId`, `AlbumArtistIds`, `StartIndex`, `SortBy` — so the
/// repositories above it read as library questions rather than as URL
/// building. It also owns the session-scoped [JellyfinHttpClient]: one
/// client per server, rebuilt when the active profile moves to a
/// different server.
///
/// Requests are always windowed and always sorted by the server
/// (`PHILOSOPHY.md` §11). Nothing here fetches a library to narrow it in
/// Dart.
@lazySingleton
class JellyfinMediaApi {
  JellyfinMediaApi(
    this._context,
    this._identity,
    this._authTokenProvider,
    this._logger,
  );

  final JellyfinSessionContext _context;
  final JellyfinClientIdentity _identity;
  final AuthTokenProvider _authTokenProvider;
  final Logger _logger;

  /// Overrides how the HTTP client is built. `null` in production.
  MediaHttpClientFactory? httpClientFactory;

  JellyfinHttpClient? _client;
  String? _clientBaseUrl;

  /// Jellyfin's item query endpoint; everything browsable comes from it.
  static const String itemsPath = '/Items';

  /// Album artists — the artists a music library lists, as opposed to
  /// every performer credited on any track.
  static const String albumArtistsPath = '/Artists/AlbumArtists';

  /// The metadata Jellyfinity asks for beyond an item's defaults. Kept
  /// short deliberately: every field is paid for on all 100 rows of every
  /// page.
  static const List<String> defaultFields = ['PrimaryImageAspectRatio'];

  /// Fields a detail view needs and a list does not.
  static const List<String> detailFields = [
    'PrimaryImageAspectRatio',
    'Overview',
    'ChildCount',
  ];

  /// Fields [TrackSourceInfoResolver] needs — a track's file/codec
  /// details. Deliberately its own list, not folded into [detailFields]:
  /// that one is paid for on every row of paged detail views (albums
  /// included), while `MediaSources` is only ever asked for one track at
  /// a time, on demand.
  static const List<String> trackSourceFields = ['MediaSources'];

  /// The image kinds Jellyfinity renders; asking for only these keeps
  /// image tags out of the response for the dozen kinds it does not.
  static const List<String> imageTypes = ['Primary', 'Backdrop', 'Logo'];

  /// Jellyfinity's local id for the server being queried, or `null` when
  /// signed out. The other half of every [MediaId] the mapper produces.
  String? get serverId => _context.serverId;

  /// A search term the server can use, or `null` when the caller did not
  /// really ask for one. Normalized here so every query surface agrees
  /// that a blank term means "no search" rather than "match nothing".
  static String? normalizeSearchTerm(String? term) {
    final trimmed = term?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static String playlistItemsPath(String playlistId) =>
      '/Playlists/$playlistId/Items';

  /// A track's lyrics (v0.1.5). 404 when the track has none.
  static String lyricsPath(String itemId) => '/Audio/$itemId/Lyrics';

  /// Jellyfin 10.10 replaced `/Users/{userId}/PlayedItems/{itemId}` with
  /// this user-implicit form; the minimum supported server is 10.11.6.
  static String playedItemPath(String itemId) => '/UserPlayedItems/$itemId';

  /// Reports the start, ongoing progress, and end of a playback session
  /// (v0.0.9), so Jellyfin's own resume position and played state agree
  /// with what Jellyfinity actually played. No `PlaySessionId` is sent —
  /// Jellyfin correlates these to the authenticated connection without
  /// one, and Jellyfinity does not otherwise need to name its own play
  /// sessions.
  static const String playingSessionPath = '/Sessions/Playing';
  static const String playingProgressPath = '/Sessions/Playing/Progress';
  static const String playingStoppedPath = '/Sessions/Playing/Stopped';

  /// The mapper for the active server.
  ///
  /// A mapper cannot exist without a server to bind ids to, so this is
  /// also the repositories' signed-in check.
  Result<BaseItemMapper> mapper() {
    final active = serverId;
    if (active == null) {
      return const Result.err(
        UnauthorizedFailure('Sign in to browse your library.'),
      );
    }
    return Result.ok(BaseItemMapper(active));
  }

  /// The Jellyfin item id inside [id], if [id] belongs to the server
  /// currently signed in to.
  ///
  /// An id from another saved server is not an error in the transport
  /// sense — the item exists, just not here — so it comes back as
  /// unavailable. This is the guard that keeps a cached entity or an old
  /// deep link from quietly querying the wrong library.
  Result<String> localItemId(MediaId id) {
    final active = serverId;
    if (active == null) {
      return const Result.err(
        UnauthorizedFailure('Sign in to browse your library.'),
      );
    }
    if (id.serverId != active) {
      return const Result.err(
        UnavailableFailure('That item is on a different server.'),
      );
    }
    return Result.ok(id.itemId);
  }

  /// [mapper] and [localItemId] resolved together, which is what every
  /// single-item read needs.
  Result<MediaScope> scopeFor(MediaId id) {
    final boundMapper = mapper();
    if (boundMapper case Err<BaseItemMapper>(:final failure)) {
      return Result.err(failure);
    }
    final itemId = localItemId(id);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);

    return Result.ok((
      mapper: (boundMapper as Ok<BaseItemMapper>).value,
      itemId: (itemId as Ok<String>).value,
    ));
  }

  /// Queries a collection of items.
  ///
  /// [path] defaults to [itemsPath] but also serves the artist and
  /// playlist endpoints, which take the same query parameters.
  ///
  /// [searchTerm] is Jellyfin's own name matching, applied by the server
  /// on top of every other filter. Matching a 130k-track library is the
  /// server's job; nothing here narrows anything in Dart.
  Future<Result<ItemsResponseDto>> queryItems({
    String path = itemsPath,
    List<String> includeItemTypes = const [],
    List<String> ids = const [],
    String? parentId,
    String? artistId,
    String? albumArtistId,
    String? searchTerm,
    List<String> fields = defaultFields,
    List<String> sortBy = const [],
    bool recursive = true,
    PageRequest? page,
    CancelToken? cancelToken,
  }) async {
    final session = _session();
    if (session case Err<_ActiveSession>(:final failure)) {
      return Result.err(failure);
    }
    final active = (session as Ok<_ActiveSession>).value;

    final query = <String, dynamic>{
      'userId': active.userId,
      if (fields.isNotEmpty) 'fields': fields.join(','),
      'enableImageTypes': imageTypes.join(','),
      if (includeItemTypes.isNotEmpty)
        'includeItemTypes': includeItemTypes.join(','),
      if (ids.isNotEmpty) 'ids': ids.join(','),
      'parentId': ?parentId,
      'artistIds': ?artistId,
      'albumArtistIds': ?albumArtistId,
      'searchTerm': ?normalizeSearchTerm(searchTerm),
      if (sortBy.isNotEmpty) ...{
        'sortBy': sortBy.join(','),
        'sortOrder': 'Ascending',
      },
      if (recursive && path == itemsPath) 'recursive': true,
      if (page != null) ...{'startIndex': page.startIndex, 'limit': page.limit},
    };

    return active.client.getJson<ItemsResponseDto>(
      path,
      parse: ItemsResponseDto.fromJson,
      queryParameters: query,
      cancelToken: cancelToken,
    );
  }

  /// One item by id, whatever its type.
  ///
  /// Asks the collection endpoint for a single id rather than using the
  /// single-item route: it is the same query surface (so the same fields
  /// and user data come back), and an item that has since been removed
  /// answers with an empty list instead of a 404.
  ///
  /// `Ok(null)` means "the server does not have that item".
  Future<Result<BaseItemDto?>> item(
    String itemId, {
    List<String> fields = detailFields,
    CancelToken? cancelToken,
  }) async {
    final response = await queryItems(
      ids: [itemId],
      fields: fields,
      page: const PageRequest(startIndex: 0, limit: 1),
      cancelToken: cancelToken,
    );

    return response.map((dto) {
      final items = dto.items;
      return (items == null || items.isEmpty) ? null : items.first;
    });
  }

  /// The lyrics Jellyfin has stored for [itemId], or `Ok(null)` when there
  /// are none.
  ///
  /// Jellyfin answers both "no lyrics file" and "no such item" with a 404,
  /// which [TransportErrorMapper] normalizes to [UnavailableFailure]; here
  /// that specific failure is folded into `Ok(null)` instead of propagated,
  /// since either way there is nothing to show and the roadmap treats a
  /// missing lyrics file as an empty state rather than an error. Any other
  /// failure (unauthorized, offline, ...) still propagates as `Err`.
  Future<Result<LyricsDto?>> lyrics(
    String itemId, {
    CancelToken? cancelToken,
  }) async {
    final session = _session();
    if (session case Err<_ActiveSession>(:final failure)) {
      return Result.err(failure);
    }
    final active = (session as Ok<_ActiveSession>).value;

    final response = await active.client.getJson<LyricsDto>(
      lyricsPath(itemId),
      parse: LyricsDto.fromJson,
      cancelToken: cancelToken,
    );
    return switch (response) {
      Ok<LyricsDto>(:final value) => Result.ok(value),
      Err<LyricsDto>(failure: final f) when f is UnavailableFailure =>
        const Result.ok(null),
      Err<LyricsDto>(:final failure) => Result.err(failure),
    };
  }

  /// Sets or clears Jellyfin's played flag for an item.
  Future<Result<void>> setPlayed(
    String itemId, {
    required bool played,
    CancelToken? cancelToken,
  }) async {
    final session = _session();
    if (session case Err<_ActiveSession>(:final failure)) {
      return Result.err(failure);
    }
    final active = (session as Ok<_ActiveSession>).value;

    return active.client.send(
      playedItemPath(itemId),
      method: played ? 'POST' : 'DELETE',
      queryParameters: {'userId': active.userId},
      cancelToken: cancelToken,
    );
  }

  /// Tells the server [itemId] has started playing, from position zero.
  Future<Result<void>> reportPlaybackStart(
    String itemId, {
    CancelToken? cancelToken,
  }) {
    return _sendPlayback(
      playingSessionPath,
      itemId: itemId,
      extra: const {'CanSeek': true, 'IsPaused': false},
      cancelToken: cancelToken,
    );
  }

  /// Reports the live playback position of [itemId]. Called on a timer
  /// while a track plays.
  Future<Result<void>> reportPlaybackProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
    CancelToken? cancelToken,
  }) {
    return _sendPlayback(
      playingProgressPath,
      itemId: itemId,
      position: position,
      extra: {'IsPaused': isPaused},
      cancelToken: cancelToken,
    );
  }

  /// Tells the server playback of [itemId] ended at [position].
  Future<Result<void>> reportPlaybackStopped(
    String itemId, {
    required Duration position,
    CancelToken? cancelToken,
  }) {
    return _sendPlayback(
      playingStoppedPath,
      itemId: itemId,
      position: position,
      cancelToken: cancelToken,
    );
  }

  Future<Result<void>> _sendPlayback(
    String path, {
    required String itemId,
    Duration position = Duration.zero,
    Map<String, dynamic> extra = const {},
    CancelToken? cancelToken,
  }) async {
    final session = _session();
    if (session case Err<_ActiveSession>(:final failure)) {
      return Result.err(failure);
    }
    final active = (session as Ok<_ActiveSession>).value;

    return active.client.send(
      path,
      method: 'POST',
      body: <String, dynamic>{
        'ItemId': itemId,
        // One tick is 100 nanoseconds, i.e. a tenth of a microsecond.
        'PositionTicks': position.inMicroseconds * 10,
        ...extra,
      },
      cancelToken: cancelToken,
    );
  }

  /// Releases the session-scoped client. Called when the active server
  /// changes; harmless otherwise.
  void close() {
    _client?.close();
    _client = null;
    _clientBaseUrl = null;
  }

  Result<_ActiveSession> _session() {
    final baseUrl = _context.baseUrl;
    final userId = _context.userId;
    if (baseUrl == null || userId == null || _context.serverId == null) {
      return const Result.err(
        UnauthorizedFailure('Sign in to browse your library.'),
      );
    }
    return Result.ok(_ActiveSession(_clientFor(baseUrl), userId));
  }

  JellyfinHttpClient _clientFor(String baseUrl) {
    final cached = _client;
    if (cached != null && _clientBaseUrl == baseUrl) return cached;
    // The active profile moved to a different server: the old client is
    // bound to the old base URL and can never be useful again.
    close();
    final client = (httpClientFactory ?? _defaultClient)(baseUrl);
    _client = client;
    _clientBaseUrl = baseUrl;
    return client;
  }

  JellyfinHttpClient _defaultClient(String baseUrl) => JellyfinHttpClient(
    baseUrl: baseUrl,
    identity: _identity,
    authTokenProvider: _authTokenProvider,
    logger: _logger,
  );
}

/// The signed-in profile's client and user id, resolved together because
/// a request needs both or neither.
class _ActiveSession {
  const _ActiveSession(this.client, this.userId);

  final JellyfinHttpClient client;
  final String userId;
}
