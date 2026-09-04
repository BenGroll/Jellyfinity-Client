// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'items_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ItemsResponseDto _$ItemsResponseDtoFromJson(Map<String, dynamic> json) =>
    ItemsResponseDto(
      items: (json['Items'] as List<dynamic>?)
          ?.map((e) => BaseItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalRecordCount: (json['TotalRecordCount'] as num?)?.toInt(),
      startIndex: (json['StartIndex'] as num?)?.toInt(),
    );
