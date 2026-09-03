import 'package:json_annotation/json_annotation.dart';

part 'public_system_info_dto.g.dart';

/// The shape of Jellyfin's `GET /System/Info/Public` response.
///
/// This is an **API DTO**, not a domain model: it lives in
/// `lib/infrastructure/` and must not be handed to presentation or domain
/// code (ADR-0001). `JellyfinServerProbe` maps it to `JellyfinServerInfo`.
///
/// Every field is nullable. The public info endpoint is intentionally
/// generous about what it returns across Jellyfin versions and
/// configurations, and a missing field should degrade one check, not fail
/// the whole parse.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.pascal)
class PublicSystemInfoDto {
  const PublicSystemInfoDto({
    this.localAddress,
    this.serverName,
    this.version,
    this.productName,
    this.id,
    this.startupWizardCompleted,
  });

  factory PublicSystemInfoDto.fromJson(Map<String, dynamic> json) =>
      _$PublicSystemInfoDtoFromJson(json);

  final String? localAddress;
  final String? serverName;
  final String? version;

  /// e.g. `"Jellyfin Server"`. Present on every supported version and the
  /// primary signal that an address really is Jellyfin (and not Emby or an
  /// unrelated service answering on that host).
  final String? productName;

  final String? id;
  final bool? startupWizardCompleted;
}
