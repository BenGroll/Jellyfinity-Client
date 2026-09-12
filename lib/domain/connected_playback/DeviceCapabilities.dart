import 'package:equatable/equatable.dart';

import 'ConnectedPlaybackLimits.dart';
import 'remote_command_kind.dart';

/// What one device will actually accept — advertised by that device, not
/// inferred from its platform.
///
/// The arc's invariant is that "the UI offers only commands the target
/// currently accepts". Inferring capabilities from a platform name would
/// be wrong on the first day: the same Android build is a phone and a
/// Fire TV, and the same install is a full player while it has audio
/// focus and controller-only while another app holds it. So a device says
/// what it accepts, in its own words, and the answer is allowed to change
/// between advertisements.
///
/// [acceptedCommands] is the authoritative list. [canPlay] and
/// [canControl] are the two coarse roles a picker needs before it looks
/// at individual commands — "can sound come out of this" and "can this
/// drive something else" — and they are stored rather than derived
/// because a device can legitimately be a player that accepts no remote
/// commands at all (playing locally with remote control switched off).
///
/// [unknownCapabilities] keeps capability tokens this build does not
/// recognize instead of discarding them. A newer peer advertising
/// `video` or `outputSwitching` round-trips intact, and a diagnostic
/// screen can say *why* a device offers something this build cannot use,
/// rather than silently showing a shorter list than the other end does.
class DeviceCapabilities extends Equatable {
  const DeviceCapabilities({
    required this.canPlay,
    required this.canControl,
    this.acceptedCommands = const {},
    this.maxQueueEntries = ConnectedPlaybackLimits.maxQueueEntries,
    this.unknownCapabilities = const [],
  });

  /// A device that will not participate at all — what an unreachable,
  /// incompatible or logged-out peer collapses to, so callers never have
  /// to handle a `null` capability set.
  static const DeviceCapabilities none = DeviceCapabilities(
    canPlay: false,
    canControl: false,
  );

  /// What an ordinary Jellyfinity build advertises: it can play, it can
  /// control, and it accepts every command this protocol version defines.
  factory DeviceCapabilities.fullPlayer() => DeviceCapabilities(
    canPlay: true,
    canControl: true,
    acceptedCommands: RemoteCommandKind.values.toSet(),
  );

  /// Whether audio can come out of this device.
  final bool canPlay;

  /// Whether this device can drive another one.
  final bool canControl;

  /// The commands this device will accept right now.
  final Set<RemoteCommandKind> acceptedCommands;

  /// The longest queue this device will accept in a transfer or a
  /// queue-replacing command. Never above
  /// [ConnectedPlaybackLimits.maxQueueEntries]; a device with less memory
  /// may advertise less.
  final int maxQueueEntries;

  /// Advertised capability tokens this build does not understand, kept
  /// verbatim and in advertised order.
  final List<String> unknownCapabilities;

  /// Whether this device is usable as a handoff destination.
  ///
  /// Playing is not enough: a target that cannot be given a queue cannot
  /// receive a transfer, and offering it would produce a refusal after
  /// the listener has already chosen it.
  bool get canReceiveTransfer => canPlay && accepts(RemoteCommandKind.setQueue);

  bool accepts(RemoteCommandKind kind) => acceptedCommands.contains(kind);

  /// The commands a controller may offer for this device, out of the
  /// [desired] set it would like to show.
  ///
  /// This is the negotiation, and it is deliberately an intersection
  /// rather than a subtraction: a peer ahead on protocol minor version
  /// accepting commands this build cannot compose gains nothing by being
  /// offered them.
  Set<RemoteCommandKind> negotiate(Set<RemoteCommandKind> desired) =>
      desired.intersection(acceptedCommands);

  DeviceCapabilities copyWith({
    bool? canPlay,
    bool? canControl,
    Set<RemoteCommandKind>? acceptedCommands,
    int? maxQueueEntries,
    List<String>? unknownCapabilities,
  }) {
    return DeviceCapabilities(
      canPlay: canPlay ?? this.canPlay,
      canControl: canControl ?? this.canControl,
      acceptedCommands: acceptedCommands ?? this.acceptedCommands,
      maxQueueEntries: maxQueueEntries ?? this.maxQueueEntries,
      unknownCapabilities: unknownCapabilities ?? this.unknownCapabilities,
    );
  }

  @override
  List<Object?> get props => [
    canPlay,
    canControl,
    // Sorted so two capability sets advertised in different orders
    // compare equal; a re-advertisement that reorders a set is not a
    // change and must not redraw a picker.
    acceptedCommands.map((kind) => kind.wireName).toList()..sort(),
    maxQueueEntries,
    unknownCapabilities,
  ];
}
