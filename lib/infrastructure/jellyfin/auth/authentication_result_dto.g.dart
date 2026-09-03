// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authentication_result_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthenticationResultDto _$AuthenticationResultDtoFromJson(
  Map<String, dynamic> json,
) => AuthenticationResultDto(
  user: json['User'] == null
      ? null
      : AuthenticatedUserDto.fromJson(json['User'] as Map<String, dynamic>),
  accessToken: json['AccessToken'] as String?,
  serverId: json['ServerId'] as String?,
);

AuthenticatedUserDto _$AuthenticatedUserDtoFromJson(
  Map<String, dynamic> json,
) => AuthenticatedUserDto(
  id: json['Id'] as String?,
  name: json['Name'] as String?,
);
