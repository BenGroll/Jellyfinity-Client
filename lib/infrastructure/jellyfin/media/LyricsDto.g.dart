// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'LyricsDto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LyricsDto _$LyricsDtoFromJson(Map<String, dynamic> json) => LyricsDto(
  lyrics: (json['Lyrics'] as List<dynamic>?)
      ?.map((e) => LyricLineDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

LyricLineDto _$LyricLineDtoFromJson(Map<String, dynamic> json) => LyricLineDto(
  text: json['Text'] as String?,
  start: (json['Start'] as num?)?.toInt(),
);
