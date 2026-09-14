/// This device's own relationship to a SyncPlay group (v0.6.0, ADR-0045)
/// — the visible states "play on all devices" promises: joining, leaving
/// and a join that could not succeed are never silent.
enum SyncPlayGroupStatus {
  /// Not in a group, and asking for nothing — the ordinary single-device
  /// state every listener who never opens a group stays in.
  none,

  /// `SyncPlayApi.createGroup`/`.joinGroup` is in flight.
  joining,

  /// A member of the group named by `SyncPlayGroupState.info`.
  joined,

  /// `SyncPlayApi.leaveGroup` is in flight.
  leaving,

  /// The most recent join or create was refused or failed — the server
  /// has SyncPlay disabled, the group would not admit this device, or
  /// the request could not reach the server at all.
  failed,
}
