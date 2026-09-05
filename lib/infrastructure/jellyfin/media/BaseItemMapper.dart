import '../../../core/result/partial.dart';
import '../../../domain/media/media.dart';
import '../../../domain/playback/Lyrics.dart';
import '../../../domain/playback/TrackSourceInfo.dart';
import 'base_item_dto.dart';
import 'ItemsResponseDto.dart';
import 'LyricsDto.dart';

/// Translates Jellyfin's items into Jellyfinity's media entities.
///
/// The single place in the codebase that knows what `RunTimeTicks`,
/// `ParentIndexNumber` or `LocationType` mean. Everything above it works
/// in `Duration`s, disc numbers and [MediaAvailability].
///
/// A mapper is bound to one server ([serverId], Jellyfinity's local id
/// for it) because that is the other half of every [MediaId] it produces:
/// an item id alone does not identify anything.
///
/// Mapping never throws and never guesses. An item that is not of the
/// expected type, or is missing the two things every entity needs — an id
/// and a name — maps to `null`, and the caller turns that into an
/// [UnavailableItem] rather than into a broken row or a failed page.
/// Checking the type here rather than trusting the query is what stops a
/// film sitting in a playlist from being rendered as a song.
class BaseItemMapper {
  const BaseItemMapper(this.serverId);

  /// Jellyfinity's local id for the server these items came from.
  final String serverId;

  /// Jellyfin's `Type` discriminators that Jellyfinity models.
  static const String artistType = 'MusicArtist';
  static const String albumType = 'MusicAlbum';
  static const String trackType = 'Audio';
  static const String playlistType = 'Playlist';
  static const String movieType = 'Movie';
  static const String seriesType = 'Series';
  static const String seasonType = 'Season';
  static const String episodeType = 'Episode';

  /// A Jellyfin item that exists in the library but has no file behind
  /// it — a missing episode.
  static const String virtualLocation = 'Virtual';

  /// One Jellyfin tick is 100 nanoseconds.
  static const int _microsecondsPerTick = 10;

  /// Maps an item of any modelled type, or `null` if the item is
  /// unusable or of a type Jellyfinity does not model.
  MediaItem? toMediaItem(BaseItemDto dto) => switch (dto.type) {
    artistType => toArtist(dto),
    albumType => toAlbum(dto),
    trackType => toTrack(dto),
    playlistType => toPlaylist(dto),
    movieType => toMovie(dto),
    seriesType => toSeries(dto),
    seasonType => toSeason(dto),
    episodeType => toEpisode(dto),
    _ => null,
  };

  Artist? toArtist(BaseItemDto dto) {
    if (dto.type != artistType) return null;
    final id = _id(dto.id);
    final name = _name(dto.name);
    if (id == null || name == null) return null;
    return Artist(
      id: id,
      name: name,
      availability: _availability(dto),
      image: _primaryImage(dto, id),
    );
  }

  Album? toAlbum(BaseItemDto dto) {
    if (dto.type != albumType) return null;
    final id = _id(dto.id);
    final name = _name(dto.name);
    if (id == null || name == null) return null;
    return Album(
      id: id,
      name: name,
      artists: _albumArtists(dto),
      productionYear: dto.productionYear,
      duration: _duration(dto.runTimeTicks),
      trackCount: dto.childCount,
      availability: _availability(dto),
      image: _primaryImage(dto, id),
    );
  }

  Track? toTrack(BaseItemDto dto) {
    if (dto.type != trackType) return null;
    final id = _id(dto.id);
    final name = _name(dto.name);
    if (id == null || name == null) return null;
    return Track(
      id: id,
      name: name,
      artists: _trackArtists(dto),
      albumId: _id(dto.albumId),
      albumName: _name(dto.album),
      trackNumber: dto.indexNumber,
      discNumber: dto.parentIndexNumber,
      duration: _duration(dto.runTimeTicks),
      normalizationGain: dto.normalizationGain,
      availability: _availability(dto),
      image: _primaryImage(dto, id),
    );
  }

  Playlist? toPlaylist(BaseItemDto dto) {
    if (dto.type != playlistType) return null;
    final id = _id(dto.id);
    final name = _name(dto.name);
    if (id == null || name == null) return null;
    return Playlist(
      id: id,
      name: name,
      itemCount: dto.childCount,
      duration: _duration(dto.runTimeTicks),
      availability: _availability(dto),
      image: _primaryImage(dto, id),
    );
  }

  Movie? toMovie(BaseItemDto dto) {
    if (dto.type != movieType) return null;
    final id = _id(dto.id);
    final name = _name(dto.name);
    if (id == null || name == null) return null;
    return Movie(
      id: id,
      name: name,
      productionYear: dto.productionYear,
      duration: _duration(dto.runTimeTicks),
      overview: _name(dto.overview),
      progress: toProgress(dto.userData),
      availability: _availability(dto),
      image: _primaryImage(dto, id),
    );
  }

  Series? toSeries(BaseItemDto dto) {
    if (dto.type != seriesType) return null;
    final id = _id(dto.id);
    final name = _name(dto.name);
    if (id == null || name == null) return null;
    return Series(
      id: id,
      name: name,
      productionYear: dto.productionYear,
      overview: _name(dto.overview),
      availability: _availability(dto),
      image: _primaryImage(dto, id),
    );
  }

  Season? toSeason(BaseItemDto dto) {
    if (dto.type != seasonType) return null;
    final id = _id(dto.id);
    final name = _name(dto.name);
    if (id == null || name == null) return null;
    return Season(
      id: id,
      name: name,
      seriesId: _id(dto.seriesId),
      seriesName: _name(dto.seriesName),
      seasonNumber: dto.indexNumber,
      availability: _availability(dto),
      image: _primaryImage(dto, id),
    );
  }

  Episode? toEpisode(BaseItemDto dto) {
    if (dto.type != episodeType) return null;
    final id = _id(dto.id);
    final name = _name(dto.name);
    if (id == null || name == null) return null;
    return Episode(
      id: id,
      name: name,
      seriesId: _id(dto.seriesId),
      seriesName: _name(dto.seriesName),
      seasonId: _id(dto.seasonId),
      seasonNumber: dto.parentIndexNumber,
      episodeNumber: dto.indexNumber,
      duration: _duration(dto.runTimeTicks),
      overview: _name(dto.overview),
      progress: toProgress(dto.userData),
      availability: _availability(dto),
      image: _primaryImage(dto, id),
    );
  }

  /// A track's file details, for the streaming-quality UI (ADR-0015).
  ///
  /// Jellyfinity only ever reads the first media source and, within it,
  /// the first audio stream — the only case that matters for a music
  /// track. `null` (never a thrown error) when the item has no usable
  /// source, same discipline as every other `to*` method.
  TrackSourceInfo? toTrackSourceInfo(BaseItemDto dto) {
    if (dto.type != trackType) return null;
    final sources = dto.mediaSources;
    if (sources == null || sources.isEmpty) return null;
    final source = sources.first;
    final audio = _audioStream(source.mediaStreams);

    return TrackSourceInfo(
      container: _name(source.container),
      codec: _name(audio?.codec),
      bitrateBps: audio?.bitRate ?? source.bitrate,
      sampleRateHz: audio?.sampleRate,
      bitDepth: audio?.bitDepth,
      channels: audio?.channels,
    );
  }

  MediaStreamDto? _audioStream(List<MediaStreamDto>? streams) {
    if (streams == null) return null;
    for (final stream in streams) {
      if (stream.type == 'Audio') return stream;
    }
    return null;
  }

  /// A track's lyrics (v0.1.5), or `null` when there is no usable line —
  /// same discipline as every other `to*` method, so an empty/blank
  /// response reads as "no lyrics" rather than an empty [Lyrics].
  Lyrics? toLyrics(LyricsDto dto) {
    final raw = dto.lyrics;
    if (raw == null || raw.isEmpty) return null;

    final lines = <LyricLine>[];
    for (final line in raw) {
      final text = _name(line.text);
      if (text == null) continue;
      lines.add(LyricLine(text: text, start: _lyricStart(line.start)));
    }
    if (lines.isEmpty) return null;

    return Lyrics(lines: lines, isSynchronized: _isReliablySynchronized(lines));
  }

  /// Ticks to a line's start position, distinct from [_duration]: a lyric
  /// line legitimately starts at position zero (the first line of the
  /// track), whereas zero/negative is "unknown" for a duration field.
  Duration? _lyricStart(int? ticks) {
    if (ticks == null || ticks < 0) return null;
    return Duration(microseconds: ticks ~/ _microsecondsPerTick);
  }

  /// Synchronized scrolling is only trustworthy when every line carries a
  /// timestamp and they never run backwards — anything less is the
  /// "half-working synchronization" the roadmap rules out, so the caller
  /// falls back to plain lyrics instead.
  bool _isReliablySynchronized(List<LyricLine> lines) {
    Duration? previous;
    for (final line in lines) {
      final start = line.start;
      if (start == null) return false;
      if (previous != null && start < previous) return false;
      previous = start;
    }
    return true;
  }

  /// The user's position in an item. Absent user data means "never
  /// played", not "unknown" — Jellyfin simply omits it until there is
  /// something to report.
  PlaybackProgress toProgress(UserItemDataDto? data) {
    if (data == null) return PlaybackProgress.none;
    return PlaybackProgress(
      position: _duration(data.playbackPositionTicks) ?? Duration.zero,
      completed: data.played ?? false,
      lastPlayedAt: data.lastPlayedDate,
    );
  }

  /// Maps one window of a collection.
  ///
  /// Rows [map] cannot make sense of are recorded as unavailable instead
  /// of being dropped or failing the window: the page still renders, the
  /// count still adds up, and the user sees that something is missing
  /// (`PHILOSOPHY.md` §2).
  Page<T> toPage<T extends MediaItem>(
    ItemsResponseDto response, {
    required PageRequest request,
    required T? Function(BaseItemDto dto) map,
    String reason = 'This item is unavailable.',
  }) {
    final rows = response.items ?? const <BaseItemDto>[];
    final available = <T>[];
    final unavailable = <UnavailableItem>[];

    for (final row in rows) {
      final item = map(row);
      if (item != null) {
        available.add(item);
      } else {
        unavailable.add(UnavailableItem(id: row.id ?? '', reason: reason));
      }
    }

    return Page<T>(
      content: Partial(available: available, unavailable: unavailable),
      startIndex: response.startIndex ?? request.startIndex,
      // A server that omits the total is telling us nothing follows this
      // window; treating it as "everything we have" stops paging cleanly
      // instead of looping.
      totalCount:
          response.totalRecordCount ??
          (response.startIndex ?? request.startIndex) + rows.length,
    );
  }

  MediaId? _id(String? itemId) {
    if (itemId == null || itemId.isEmpty) return null;
    return MediaId(serverId: serverId, itemId: itemId);
  }

  String? _name(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Duration? _duration(int? ticks) {
    if (ticks == null || ticks <= 0) return null;
    return Duration(microseconds: ticks ~/ _microsecondsPerTick);
  }

  MediaAvailability _availability(BaseItemDto dto) {
    // Nothing is downloaded yet (downloads are post-v0.1.0), so a server
    // item is remote-only unless the library says there is no file
    // behind it.
    return dto.locationType == virtualLocation
        ? MediaAvailability.remoteUnavailable
        : MediaAvailability.remoteOnly;
  }

  /// The artwork to show for an item, following Jellyfin's inheritance:
  /// a song shows its album's cover and an episode its show's poster,
  /// each pointing at the item that actually owns the image so it is
  /// cached once.
  MediaImage? _primaryImage(BaseItemDto dto, MediaId id) {
    final ownTag = dto.imageTags?['Primary'];
    if (ownTag != null && ownTag.isNotEmpty) {
      return MediaImage(
        itemId: id,
        kind: MediaImageKind.primary,
        tag: ownTag,
        aspectRatio: dto.primaryImageAspectRatio,
      );
    }

    final albumId = _id(dto.albumId);
    final albumTag = dto.albumPrimaryImageTag;
    if (albumId != null && albumTag != null && albumTag.isNotEmpty) {
      return MediaImage(
        itemId: albumId,
        kind: MediaImageKind.primary,
        tag: albumTag,
      );
    }

    final seriesId = _id(dto.seriesId);
    final seriesTag = dto.seriesPrimaryImageTag;
    if (seriesId != null && seriesTag != null && seriesTag.isNotEmpty) {
      return MediaImage(
        itemId: seriesId,
        kind: MediaImageKind.primary,
        tag: seriesTag,
      );
    }

    return null;
  }

  List<ArtistRef> _albumArtists(BaseItemDto dto) =>
      _credits(dto.albumArtists) ??
      _credits(dto.artistItems) ??
      _namedCredits(dto.artists);

  List<ArtistRef> _trackArtists(BaseItemDto dto) =>
      _credits(dto.artistItems) ??
      _credits(dto.albumArtists) ??
      _namedCredits(dto.artists);

  List<ArtistRef>? _credits(List<NameIdPairDto>? pairs) {
    if (pairs == null || pairs.isEmpty) return null;
    final credits = <ArtistRef>[];
    for (final pair in pairs) {
      final name = _name(pair.name);
      if (name == null) continue;
      credits.add(ArtistRef(name: name, id: _id(pair.id)));
    }
    return credits.isEmpty ? null : credits;
  }

  /// Names the server credited without linking to an artist item. They
  /// are shown but cannot be navigated to.
  List<ArtistRef> _namedCredits(List<String>? names) {
    if (names == null) return const [];
    return names
        .map(_name)
        .whereType<String>()
        .map((name) => ArtistRef(name: name))
        .toList(growable: false);
  }
}
