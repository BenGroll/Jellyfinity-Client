import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/service_locator.dart';
import '../../../design/design.dart';
import '../../../domain/connected_playback/ConnectedDevice.dart';
import '../../../domain/connected_playback/connection_state.dart';
import '../../../domain/connected_playback/device_reachability.dart';
import 'device_picker_cubit.dart';

/// Opens the device picker (v0.5.5) — "This device" plus every compatible
/// Jellyfinity install presence knows about, and the action to move
/// playback between them.
///
/// Pass [cubit] to reuse one already subscribed to presence (the device
/// action button below does, so opening the sheet does not start a
/// second subscription); omitted, the sheet resolves and disposes its
/// own.
Future<void> showDevicePickerSheet(
  BuildContext context, {
  DevicePickerCubit? cubit,
}) {
  final ownsCubit = cubit == null;
  final resolved = cubit ?? getIt<DevicePickerCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => BlocProvider<DevicePickerCubit>.value(
      value: resolved,
      child: const _DevicePickerSheetContent(),
    ),
  ).whenComplete(() {
    if (ownsCubit) unawaited(resolved.close());
  });
}

class _DevicePickerSheetContent extends StatelessWidget {
  const _DevicePickerSheetContent();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // No shared breakpoint module exists yet (every screen picks its own
    // threshold); a width-capped, centered sheet is the same "docked
    // panel" treatment Now Playing's queue editor already uses for a
    // windowed desktop rather than letting a phone-width sheet stretch
    // edge to edge.
    final compact = MediaQuery.sizeOf(context).width < 600;
    final height = (MediaQuery.sizeOf(context).height * 0.7).clamp(
      320.0,
      560.0,
    );

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 480,
          ),
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.md,
                    t.spacing.sm,
                    t.spacing.xs,
                    t.spacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Devices',
                          style: t.typography.titleLarge.copyWith(
                            color: t.colors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: BlocBuilder<DevicePickerCubit, DevicePickerState>(
                    builder: (context, state) => _DeviceList(
                      state: state,
                      cubit: context.read<DevicePickerCubit>(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.state, required this.cubit});

  final DevicePickerState state;
  final DevicePickerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final banner = _connectionMessage(state.connection);
    final thisDevice = [
      for (final device in state.devices)
        if (device.isThisDevice) device,
    ];
    final others = [
      for (final device in state.devices)
        if (!device.isThisDevice) device,
    ];

    return Column(
      children: [
        if (banner != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacing.md,
              t.spacing.sm,
              t.spacing.md,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: t.colors.textSecondary,
                ),
                SizedBox(width: t.spacing.xs),
                Expanded(
                  child: Text(
                    banner,
                    style: t.typography.caption.copyWith(
                      color: t.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final device in thisDevice)
                _DeviceRow(device: device, state: state, cubit: cubit),
              if (others.isNotEmpty) const Divider(height: 1),
              for (final device in others)
                _DeviceRow(device: device, state: state, cubit: cubit),
              if (others.isEmpty)
                Padding(
                  padding: EdgeInsets.all(t.spacing.lg),
                  child: Text(
                    'No other Jellyfinity devices found on this server yet.',
                    textAlign: TextAlign.center,
                    style: t.typography.bodyMedium.copyWith(
                      color: t.colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String? _connectionMessage(
    ConnectedPlaybackConnection connection,
  ) => switch (connection) {
    ConnectedPlaybackConnection.idle ||
    ConnectedPlaybackConnection.connected => null,
    ConnectedPlaybackConnection.connecting => 'Looking for your other devices…',
    ConnectedPlaybackConnection.reconnecting => 'Reconnected — reconnecting…',
    ConnectedPlaybackConnection.resynchronizing => 'Syncing with your server…',
    ConnectedPlaybackConnection.offline =>
      'Connecting to other devices needs your server. Playback on this '
          'device is unaffected.',
    ConnectedPlaybackConnection.unsupported =>
      'Your server can\'t carry the live connection Jellyfinity needs '
          'to see your other devices.',
    ConnectedPlaybackConnection.notPermitted =>
      'This account isn\'t allowed to see other devices on this server.',
  };
}

/// One row's visual state — separate from [ConnectedDevice] and
/// [DevicePickerState] because it folds two different sources (presence's
/// [DeviceReachability] for a peer, this device's own [PlaybackUiState]
/// for its own row) into the one vocabulary `Roadmap to v0.6.md` asks
/// the picker to show: active, available, connecting, unavailable,
/// stale, incompatible, and permission-denied.
class _RowStatus {
  const _RowStatus({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final _RowTone tone;

  Color color(AppColors colors) => switch (tone) {
    _RowTone.active => colors.success,
    _RowTone.neutral => colors.textSecondary,
    _RowTone.caution => colors.warning,
    _RowTone.danger => colors.danger,
  };
}

enum _RowTone { active, neutral, caution, danger }

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.state,
    required this.cubit,
  });

  final ConnectedDevice device;
  final DevicePickerState state;
  final DevicePickerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final busy = state.transfer.phase == DeviceTransferPhase.inProgress;
    final isThisTransfer = state.transfer.deviceSessionId == device.sessionId;
    final controlling =
        !device.isThisDevice && state.controllingSessionId == device.sessionId;
    // Controlling an active player is this row's primary action once the
    // device is actually producing audio (v0.5.6) — offering a transfer to
    // a device already playing something else would only queue a refusal
    // behind a choice the listener did not ask to make.
    final canControl =
        !device.isThisDevice && device.isPlaying && device.canBeControlled;
    final status = device.isThisDevice
        ? _statusForThisDevice(state)
        : controlling
        ? const _RowStatus(
            icon: Icons.settings_remote_rounded,
            label: 'Controlling — tap to stop',
            tone: _RowTone.active,
          )
        : _statusForRemote(device);

    final VoidCallback? action = device.isThisDevice
        ? (state.localHasQueue && !state.localIsPlaying
              ? cubit.bringBackToThisDevice
              : null)
        : controlling
        ? cubit.stopControlling
        : canControl
        ? () => cubit.control(device)
        : (device.canReceiveTransfer && state.localHasQueue && !busy
              ? () => cubit.transferTo(device)
              : null);

    Widget? trailing;
    String? failureMessage;
    if (isThisTransfer) {
      switch (state.transfer.phase) {
        case DeviceTransferPhase.inProgress:
          trailing = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        case DeviceTransferPhase.succeeded:
          trailing = Icon(Icons.check_circle_rounded, color: t.colors.success);
        case DeviceTransferPhase.failed:
          trailing = IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Try again',
            onPressed: () => cubit.transferTo(device),
          );
          failureMessage = state.transfer.message;
        case DeviceTransferPhase.idle:
          break;
      }
    }

    return ListTile(
      enabled: !busy || isThisTransfer,
      leading: Icon(status.icon, color: status.color(t.colors)),
      title: Text(
        device.isThisDevice ? 'This device' : device.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        failureMessage ?? status.label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: failureMessage != null ? t.colors.danger : null,
        ),
      ),
      trailing: trailing,
      onTap: action == null || busy ? null : action,
    );
  }

  static _RowStatus _statusForThisDevice(DevicePickerState state) {
    if (state.localIsPlaying) {
      return const _RowStatus(
        icon: Icons.play_circle_fill_rounded,
        label: 'Playing here',
        tone: _RowTone.active,
      );
    }
    if (state.localHasQueue) {
      return const _RowStatus(
        icon: Icons.pause_circle_filled_rounded,
        label: 'Paused here — tap to bring it back',
        tone: _RowTone.neutral,
      );
    }
    return const _RowStatus(
      icon: Icons.speaker_outlined,
      label: 'Nothing to play here yet',
      tone: _RowTone.neutral,
    );
  }

  static _RowStatus _statusForRemote(ConnectedDevice device) {
    if (device.isPlaying) {
      return _RowStatus(
        icon: Icons.play_circle_fill_rounded,
        label: device.reachability == DeviceReachability.ready
            ? 'Active'
            : 'Active — connection unstable',
        tone: _RowTone.active,
      );
    }
    switch (device.reachability) {
      case DeviceReachability.ready:
        return device.canReceiveTransfer
            ? const _RowStatus(
                icon: Icons.speaker_group_outlined,
                label: 'Available',
                tone: _RowTone.neutral,
              )
            : const _RowStatus(
                icon: Icons.speaker_group_outlined,
                label: 'Can\'t receive a transfer from this app version',
                tone: _RowTone.caution,
              );
      case DeviceReachability.presenceOnly:
        return const _RowStatus(
          icon: Icons.sync_rounded,
          label: 'Connecting…',
          tone: _RowTone.caution,
        );
      case DeviceReachability.stale:
        return const _RowStatus(
          icon: Icons.history_toggle_off_rounded,
          label: 'Not seen recently',
          tone: _RowTone.caution,
        );
      case DeviceReachability.incompatible:
        return const _RowStatus(
          icon: Icons.devices_other_rounded,
          label: 'Needs a matching Jellyfinity version',
          tone: _RowTone.danger,
        );
      case DeviceReachability.notPermitted:
        return const _RowStatus(
          icon: Icons.lock_outline_rounded,
          label: 'Permission denied',
          tone: _RowTone.danger,
        );
      case DeviceReachability.offline:
        return const _RowStatus(
          icon: Icons.cloud_off_rounded,
          label: 'Unavailable',
          tone: _RowTone.danger,
        );
    }
  }
}

/// The device action for [MiniPlayer]/[NowPlayingPage]: names where
/// playback actually is and opens the picker. Owns a single
/// [DevicePickerCubit] for as long as the button stays mounted, and hands
/// that same instance to the sheet it opens rather than starting a second
/// presence subscription for the duration the sheet is open.
class DeviceActionButton extends StatefulWidget {
  const DeviceActionButton({super.key, this.iconSize = 24, this.color});

  final double iconSize;
  final Color? color;

  @override
  State<DeviceActionButton> createState() => _DeviceActionButtonState();
}

class _DeviceActionButtonState extends State<DeviceActionButton> {
  late final DevicePickerCubit _cubit = getIt<DevicePickerCubit>();

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DevicePickerCubit>.value(
      value: _cubit,
      child: BlocBuilder<DevicePickerCubit, DevicePickerState>(
        builder: (context, state) {
          final controlling = _byId(state.devices, state.controllingSessionId);
          final activeRemote =
              controlling ?? _activeRemoteDevice(state.devices);
          final tooltip = controlling != null
              ? 'Controlling ${controlling.displayName}'
              : activeRemote == null
              ? 'Devices'
              : 'Playing on ${activeRemote.displayName}';
          return IconButton(
            icon: Icon(
              activeRemote == null
                  ? Icons.cast_rounded
                  : Icons.cast_connected_rounded,
            ),
            iconSize: widget.iconSize,
            color: widget.color,
            tooltip: tooltip,
            onPressed: () => showDevicePickerSheet(context, cubit: _cubit),
          );
        },
      ),
    );
  }

  static ConnectedDevice? _activeRemoteDevice(List<ConnectedDevice> devices) {
    for (final device in devices) {
      if (!device.isThisDevice && device.isPlaying) return device;
    }
    return null;
  }

  static ConnectedDevice? _byId(List<ConnectedDevice> devices, String? id) {
    if (id == null) return null;
    for (final device in devices) {
      if (device.sessionId == id) return device;
    }
    return null;
  }
}
