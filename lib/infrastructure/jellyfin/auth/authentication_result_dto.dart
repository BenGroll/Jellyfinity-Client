import 'package:json_annotation/json_annotation.dart';

part 'authentication_result_dto.g.dart';

/// The shape of Jellyfin's `POST /Users/AuthenticateByName` response.
///
/// An **API DTO** (ADR-0001): it stays in `lib/infrastructure/` and is
/// mapped to domain types (`AuthenticatedUser`) by the authenticator — it
/// is never handed to presentation or domain code.
///
/// Every field is nullable; a missing field degrades one check rather
/// than failing the whole parse (same rule as `PublicSystemInfoDto`).
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class AuthenticationResultDto {
  const AuthenticationResultDto({this.user, this.accessToken, this.serverId});

  factory AuthenticationResultDto.fromJson(Map<String, dynamic> json) =>
      _$AuthenticationResultDtoFromJson(json);

  final AuthenticatedUserDto? user;

  /// The access token minted for this device. Sensitive — never logged.
  final String? accessToken;

  final String? serverId;
}

/// The `User` object inside an [AuthenticationResultDto].
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class AuthenticatedUserDto {
  const AuthenticatedUserDto({this.id, this.name});

  factory AuthenticatedUserDto.fromJson(Map<String, dynamic> json) =>
      _$AuthenticatedUserDtoFromJson(json);

  final String? id;
  final String? name;
}
