import 'package:json_annotation/json_annotation.dart';

part 'base_item_dto.g.dart';

/// The shape of a Jellyfin library item.
///
/// Jellyfin answers every item request with the same polymorphic object
/// and discriminates it with [type] — an album, a song, a movie and an
/// episode all arrive in this one shape, most fields null. Mirroring that
/// with one DTO keeps the parsing honest; [BaseItemMapper] is what turns
/// it into the right Jellyfinity entity.
///
/// An **API DTO** (ADR-0001): it stays inside `lib/infrastructure/` and
/// is never handed to domain or presentation code.
///
/// Every field is nullable, and only the fields Jellyfinity actually uses
/// are declared — Jellyfin's real item object has well over a hundred.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class BaseItemDto {
  const BaseItemDto({
    this.id,
    this.name,
    this.type,
    this.locationType,
    this.productionYear,
    this.indexNumber,
    this.parentIndexNumber,
    this.runTimeTicks,
    this.overview,
    this.childCount,
    this.albumId,
    this.album,
    this.albumPrimaryImageTag,
    this.albumArtists,
    this.artistItems,
    this.artists,
    this.seriesId,
    this.seriesName,
    this.seriesPrimaryImageTag,
    this.seasonId,
    this.seasonName,
    this.imageTags,
    this.backdropImageTags,
    this.primaryImageAspectRatio,
    this.userData,
    this.mediaSources,
    this.normalizationGain,
  });

  factory BaseItemDto.fromJson(Map<String, dynamic> json) =>
      _$BaseItemDtoFromJson(json);

  final String? id;
  final String? name;

  /// The discriminator: `MusicArtist`, `MusicAlbum`, `Audio`, `Playlist`,
  /// `Movie`, `Series`, `Season`, `Episode`, and many more Jellyfinity
  /// does not model.
  final String? type;

  /// `Virtual` for an item the library knows about but has no file for —
  /// a missing episode. Jellyfinity shows those as unavailable rather
  /// than pretending they are playable.
  final String? locationType;

  final int? productionYear;

  /// Track number, or episode number within its season.
  final int? indexNumber;

  /// Disc number, or season number for an episode.
  final int? parentIndexNumber;

  /// Running time in 100-nanosecond ticks.
  final int? runTimeTicks;

  final String? overview;

  /// Number of children — an album's track count, a season's episodes.
  /// Only present when `ChildCount` was requested in `fields`.
  final int? childCount;

  final String? albumId;
  final String? album;

  /// The album's cover tag, carried on each of its tracks so a song can
  /// display artwork without its album being loaded.
  final String? albumPrimaryImageTag;

  final List<NameIdPairDto>? albumArtists;
  final List<NameIdPairDto>? artistItems;

  /// Artist names with no corresponding artist items. Used only as a
  /// fallback when [artistItems] is absent.
  final List<String>? artists;

  final String? seriesId;
  final String? seriesName;
  final String? seriesPrimaryImageTag;
  final String? seasonId;
  final String? seasonName;

  /// Image tags by image type, e.g. `{"Primary": "abc123"}`.
  final Map<String, String>? imageTags;

  final List<String>? backdropImageTags;

  final double? primaryImageAspectRatio;

  final UserItemDataDto? userData;

  /// The item's underlying file(s) — container, bitrate, audio/video
  /// streams. Only requested via `MediaSources` in `fields` (ADR-0015's
  /// `TrackSourceInfoResolver`), never in a list query's default fields.
  final List<MediaSourceInfoDto>? mediaSources;

  /// The dB gain Jellyfin computed for this item's loudness (v0.1.4,
  /// ADR-0017) — from server-side LUFS analysis when available, else an
  /// embedded ReplayGain tag, else absent. Set unconditionally by the
  /// server on every item response, unlike [mediaSources]; no extra
  /// `fields` entry is needed for it.
  final double? normalizationGain;
}

/// One file behind an item — Jellyfin supports multiple versions per
/// item, but Jellyfinity only ever reads the first.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class MediaSourceInfoDto {
  const MediaSourceInfoDto({this.container, this.bitrate, this.mediaStreams});

  factory MediaSourceInfoDto.fromJson(Map<String, dynamic> json) =>
      _$MediaSourceInfoDtoFromJson(json);

  /// The file's container, e.g. `flac`, `mp3`.
  final String? container;

  /// The source's overall bitrate, used as a fallback when its audio
  /// stream doesn't carry its own.
  final int? bitrate;

  final List<MediaStreamDto>? mediaStreams;
}

/// One stream within a [MediaSourceInfoDto] — Jellyfinity only reads the
/// audio ones ([MediaStreamDto.type] `"Audio"`).
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class MediaStreamDto {
  const MediaStreamDto({
    this.type,
    this.codec,
    this.bitRate,
    this.sampleRate,
    this.bitDepth,
    this.channels,
  });

  factory MediaStreamDto.fromJson(Map<String, dynamic> json) =>
      _$MediaStreamDtoFromJson(json);

  /// `Audio`, `Video`, `Subtitle`, ...
  final String? type;

  final String? codec;
  final int? bitRate;
  final int? sampleRate;
  final int? bitDepth;
  final int? channels;
}

/// A named reference to another item — an artist credit, mostly.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class NameIdPairDto {
  const NameIdPairDto({this.id, this.name});

  factory NameIdPairDto.fromJson(Map<String, dynamic> json) =>
      _$NameIdPairDtoFromJson(json);

  final String? id;
  final String? name;
}

/// The current user's state for one item: how far in they are, and
/// whether they finished it.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class UserItemDataDto {
  const UserItemDataDto({
    this.playbackPositionTicks,
    this.played,
    this.lastPlayedDate,
  });

  factory UserItemDataDto.fromJson(Map<String, dynamic> json) =>
      _$UserItemDataDtoFromJson(json);

  /// Resume position in 100-nanosecond ticks.
  final int? playbackPositionTicks;

  final bool? played;

  final DateTime? lastPlayedDate;
}
