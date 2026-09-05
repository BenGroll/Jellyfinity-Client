// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_item_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaseItemDto _$BaseItemDtoFromJson(Map<String, dynamic> json) => BaseItemDto(
  id: json['Id'] as String?,
  name: json['Name'] as String?,
  type: json['Type'] as String?,
  locationType: json['LocationType'] as String?,
  productionYear: (json['ProductionYear'] as num?)?.toInt(),
  indexNumber: (json['IndexNumber'] as num?)?.toInt(),
  parentIndexNumber: (json['ParentIndexNumber'] as num?)?.toInt(),
  runTimeTicks: (json['RunTimeTicks'] as num?)?.toInt(),
  overview: json['Overview'] as String?,
  childCount: (json['ChildCount'] as num?)?.toInt(),
  albumId: json['AlbumId'] as String?,
  album: json['Album'] as String?,
  albumPrimaryImageTag: json['AlbumPrimaryImageTag'] as String?,
  albumArtists: (json['AlbumArtists'] as List<dynamic>?)
      ?.map((e) => NameIdPairDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  artistItems: (json['ArtistItems'] as List<dynamic>?)
      ?.map((e) => NameIdPairDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  artists: (json['Artists'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  seriesId: json['SeriesId'] as String?,
  seriesName: json['SeriesName'] as String?,
  seriesPrimaryImageTag: json['SeriesPrimaryImageTag'] as String?,
  seasonId: json['SeasonId'] as String?,
  seasonName: json['SeasonName'] as String?,
  imageTags: (json['ImageTags'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  backdropImageTags: (json['BackdropImageTags'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  primaryImageAspectRatio: (json['PrimaryImageAspectRatio'] as num?)
      ?.toDouble(),
  userData: json['UserData'] == null
      ? null
      : UserItemDataDto.fromJson(json['UserData'] as Map<String, dynamic>),
  mediaSources: (json['MediaSources'] as List<dynamic>?)
      ?.map((e) => MediaSourceInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  normalizationGain: (json['NormalizationGain'] as num?)?.toDouble(),
);

MediaSourceInfoDto _$MediaSourceInfoDtoFromJson(Map<String, dynamic> json) =>
    MediaSourceInfoDto(
      container: json['Container'] as String?,
      bitrate: (json['Bitrate'] as num?)?.toInt(),
      mediaStreams: (json['MediaStreams'] as List<dynamic>?)
          ?.map((e) => MediaStreamDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

MediaStreamDto _$MediaStreamDtoFromJson(Map<String, dynamic> json) =>
    MediaStreamDto(
      type: json['Type'] as String?,
      codec: json['Codec'] as String?,
      bitRate: (json['BitRate'] as num?)?.toInt(),
      sampleRate: (json['SampleRate'] as num?)?.toInt(),
      bitDepth: (json['BitDepth'] as num?)?.toInt(),
      channels: (json['Channels'] as num?)?.toInt(),
    );

NameIdPairDto _$NameIdPairDtoFromJson(Map<String, dynamic> json) =>
    NameIdPairDto(id: json['Id'] as String?, name: json['Name'] as String?);

UserItemDataDto _$UserItemDataDtoFromJson(Map<String, dynamic> json) =>
    UserItemDataDto(
      playbackPositionTicks: (json['PlaybackPositionTicks'] as num?)?.toInt(),
      played: json['Played'] as bool?,
      lastPlayedDate: json['LastPlayedDate'] == null
          ? null
          : DateTime.parse(json['LastPlayedDate'] as String),
    );
