import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/media/media.dart';
import '../database/AppDatabase.dart';

/// Translates between Jellyfinity's media entities and their rows in the
/// local cache.
///
/// The persistence counterpart to `BaseItemMapper`: that one is the only
/// place that understands Jellyfin's wire format, this one is the only
/// place that understands the cache's column layout
/// (`PHILOSOPHY.md` §12 keeps those two representations apart on
/// purpose). Nothing above the store sees a row.
///
/// Like the Jellyfin mapper it never throws. A row written by an older
/// build, with a kind or an enum name this build does not know, maps to
/// `null` and is reported as an unavailable entry rather than crashing a
/// screen the user only opened to see what they had saved.
///
/// ## Scope
///
/// Only the music kinds are cached in v0.0.8, because only music is
/// browsable. [toRow] returns `null` for a movie or an episode instead of
/// storing a half-row: video entities carry fields (overview, playback
/// progress, series and season links) that this schema has no columns
/// for, and those columns arrive with the feature that reads them.
class MediaCacheMapper {
  const MediaCacheMapper();

  /// The kinds this cache stores.
  static const Set<MediaKind> cachedKinds = {
    MediaKind.artist,
    MediaKind.album,
    MediaKind.track,
    MediaKind.playlist,
  };

  /// [item] as a row, or `null` if this cache does not store its kind.
  CachedMediaItemsCompanion? toRow(MediaItem item, {required int now}) {
    if (!cachedKinds.contains(item.kind)) return null;

    final image = item.image;
    return CachedMediaItemsCompanion.insert(
      serverId: item.id.serverId,
      itemId: item.id.itemId,
      kind: item.kind.name,
      name: item.name,
      availability: item.availability.name,
      imageItemId: Value(image?.itemId.itemId),
      imageKind: Value(image?.kind.name),
      imageTag: Value(image?.tag),
      imageAspectRatio: Value(image?.aspectRatio),
      artistsJson: Value(_encodeArtists(item)),
      albumItemId: Value(item is Track ? item.albumId?.itemId : null),
      albumName: Value(item is Track ? item.albumName : null),
      trackNumber: Value(item is Track ? item.trackNumber : null),
      discNumber: Value(item is Track ? item.discNumber : null),
      durationMicros: Value(_duration(item)?.inMicroseconds),
      productionYear: Value(item is Album ? item.productionYear : null),
      childCount: Value(switch (item) {
        Album(:final trackCount) => trackCount,
        Playlist(:final itemCount) => itemCount,
        _ => null,
      }),
      updatedAt: now,
    );
  }

  /// [row] as an entity, or `null` if it cannot be understood.
  ///
  /// [availability] overrides what the row recorded. A cache read only
  /// happens because the server did not answer, so the caller passes
  /// `remoteUnavailable`: the metadata is real, the media is not
  /// reachable, and the user is entitled to see exactly that rather than
  /// a row that looks playable and is not.
  MediaItem? toItem(CachedMediaItemRow row, {MediaAvailability? availability}) {
    final kind = _kind(row.kind);
    if (kind == null) return null;

    final id = MediaId(serverId: row.serverId, itemId: row.itemId);
    final state =
        availability ??
        _availability(row.availability) ??
        MediaAvailability.remoteOnly;
    final image = _image(row);

    return switch (kind) {
      MediaKind.artist => Artist(
        id: id,
        name: row.name,
        availability: state,
        image: image,
      ),
      MediaKind.album => Album(
        id: id,
        name: row.name,
        artists: _decodeArtists(row),
        productionYear: row.productionYear,
        duration: _micros(row.durationMicros),
        trackCount: row.childCount,
        availability: state,
        image: image,
      ),
      MediaKind.track => Track(
        id: id,
        name: row.name,
        artists: _decodeArtists(row),
        albumId: row.albumItemId == null
            ? null
            : MediaId(serverId: row.serverId, itemId: row.albumItemId!),
        albumName: row.albumName,
        trackNumber: row.trackNumber,
        discNumber: row.discNumber,
        duration: _micros(row.durationMicros),
        availability: state,
        image: image,
      ),
      MediaKind.playlist => Playlist(
        id: id,
        name: row.name,
        itemCount: row.childCount,
        duration: _micros(row.durationMicros),
        availability: state,
        image: image,
      ),
      _ => null,
    };
  }

  String? _encodeArtists(MediaItem item) {
    final credits = switch (item) {
      Album(:final artists) => artists,
      Track(:final artists) => artists,
      _ => const <ArtistRef>[],
    };
    if (credits.isEmpty) return null;
    return jsonEncode([
      for (final credit in credits)
        <String, Object?>{'name': credit.name, 'id': credit.id?.itemId},
    ]);
  }

  List<ArtistRef> _decodeArtists(CachedMediaItemRow row) {
    final encoded = row.artistsJson;
    if (encoded == null || encoded.isEmpty) return const [];

    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      // A credit list we cannot read costs a by-line, not a screen.
      return const [];
    }
    if (decoded is! List) return const [];

    return [
      for (final entry in decoded)
        if (entry is Map && entry['name'] is String)
          ArtistRef(
            name: entry['name'] as String,
            id: entry['id'] is String
                ? MediaId(serverId: row.serverId, itemId: entry['id'] as String)
                : null,
          ),
    ];
  }

  MediaImage? _image(CachedMediaItemRow row) {
    final owner = row.imageItemId;
    final tag = row.imageTag;
    final kind = _imageKind(row.imageKind);
    if (owner == null || tag == null || kind == null) return null;
    return MediaImage(
      itemId: MediaId(serverId: row.serverId, itemId: owner),
      kind: kind,
      tag: tag,
      aspectRatio: row.imageAspectRatio,
    );
  }

  Duration? _micros(int? value) =>
      value == null ? null : Duration(microseconds: value);

  Duration? _duration(MediaItem item) => switch (item) {
    Album(:final duration) => duration,
    Track(:final duration) => duration,
    Playlist(:final duration) => duration,
    _ => null,
  };

  /// Enum lookups are by name rather than by index: a row written by an
  /// older build must not start meaning a different thing because a value
  /// was inserted into the middle of an enum.
  MediaKind? _kind(String name) {
    for (final kind in MediaKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  MediaAvailability? _availability(String name) {
    for (final value in MediaAvailability.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  MediaImageKind? _imageKind(String? name) {
    if (name == null) return null;
    for (final kind in MediaImageKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}
