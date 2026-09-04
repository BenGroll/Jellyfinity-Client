import 'package:json_annotation/json_annotation.dart';

import 'base_item_dto.dart';

part 'ItemsResponseDto.g.dart';

/// The shape Jellyfin returns for every item *collection* request.
///
/// [totalRecordCount] is what makes windowed browsing of a 130k-track
/// library possible: it tells Jellyfinity how much more there is without
/// fetching any of it.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class ItemsResponseDto {
  const ItemsResponseDto({this.items, this.totalRecordCount, this.startIndex});

  factory ItemsResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ItemsResponseDtoFromJson(json);

  final List<BaseItemDto>? items;

  /// How many items match the query in total, ignoring the window.
  final int? totalRecordCount;

  /// The index the returned window starts at.
  final int? startIndex;
}
