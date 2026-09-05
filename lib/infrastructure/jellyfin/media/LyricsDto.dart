import 'package:json_annotation/json_annotation.dart';

part 'LyricsDto.g.dart';

/// The shape Jellyfin returns from `/Audio/{itemId}/Lyrics`.
///
/// An **API DTO** (ADR-0001): stays inside `lib/infrastructure/`, never
/// handed to domain or presentation code. [BaseItemMapper.toLyrics] is what
/// turns it into the domain [Lyrics].
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class LyricsDto {
  const LyricsDto({this.lyrics});

  factory LyricsDto.fromJson(Map<String, dynamic> json) =>
      _$LyricsDtoFromJson(json);

  final List<LyricLineDto>? lyrics;
}

/// One entry of [LyricsDto.lyrics].
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class LyricLineDto {
  const LyricLineDto({this.text, this.start});

  factory LyricLineDto.fromJson(Map<String, dynamic> json) =>
      _$LyricLineDtoFromJson(json);

  final String? text;

  /// This line's start position in 100-nanosecond ticks, when the source
  /// lyrics file carried timing (e.g. an `.lrc` file) — absent for a
  /// plain-text lyrics file.
  final int? start;
}
