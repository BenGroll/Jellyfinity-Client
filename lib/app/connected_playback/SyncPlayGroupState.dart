import 'package:equatable/equatable.dart';

import '../../domain/connected_playback/sync_play_group_status.dart';
import '../../domain/connected_playback/SyncPlayGroupMember.dart';

/// What the device picker and the Remote destination show for "play on
/// all devices" (v0.6.0, ADR-0045) — [SyncPlayGroupCubit]'s own state.
class SyncPlayGroupState extends Equatable {
  const SyncPlayGroupState({
    this.status = SyncPlayGroupStatus.none,
    this.groupId,
    this.groupName,
    this.members = const [],
    this.failureMessage,
  });

  const SyncPlayGroupState.joined({
    required String groupId,
    required String groupName,
    required List<SyncPlayGroupMember> members,
  }) : this(
         status: SyncPlayGroupStatus.joined,
         groupId: groupId,
         groupName: groupName,
         members: members,
       );

  const SyncPlayGroupState.failed(String message)
    : this(status: SyncPlayGroupStatus.failed, failureMessage: message);

  final SyncPlayGroupStatus status;
  final String? groupId;
  final String? groupName;
  final List<SyncPlayGroupMember> members;

  /// Set only when [status] is [SyncPlayGroupStatus.failed] — an honest
  /// label for why joining or creating a group did not work, per
  /// ADR-0045's "visible states" requirement.
  final String? failureMessage;

  bool get isActive =>
      status == SyncPlayGroupStatus.joined ||
      status == SyncPlayGroupStatus.leaving;

  SyncPlayGroupState copyWith({
    SyncPlayGroupStatus? status,
    String? groupId,
    String? groupName,
    List<SyncPlayGroupMember>? members,
    String? failureMessage,
    bool clearFailure = false,
  }) => SyncPlayGroupState(
    status: status ?? this.status,
    groupId: groupId ?? this.groupId,
    groupName: groupName ?? this.groupName,
    members: members ?? this.members,
    failureMessage: clearFailure ? null : (failureMessage ?? this.failureMessage),
  );

  @override
  List<Object?> get props => [
    status,
    groupId,
    groupName,
    members,
    failureMessage,
  ];
}
