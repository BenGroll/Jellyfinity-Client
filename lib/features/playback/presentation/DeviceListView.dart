import 'package:flutter/material.dart';

import '../../../app/platform/television_mode.dart';
import '../../../design/design.dart';
import '../../../domain/connected_playback/ConnectedDevice.dart';
import '../../../domain/connected_playback/connection_state.dart';
import '../../../domain/connected_playback/device_reachability.dart';
import 'device_picker_cubit.dart';

/// The device list body shared by the device picker sheet (v0.5.5) and the
/// Remote destination (v0.6.0) — one rendering of [DevicePickerState] so
/// "who owns playback and what I can do about it" reads identically
/// whether it is reached from a sheet or its own page.
class DeviceListView extends StatelessWidget {
  const DeviceListView({required this.state, required this.cubit, super.key});

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
    // A D-pad remote needs somewhere to land the moment this list appears
    // (ADR-0036's television mode only autofocuses screens reached by
    // navigation, not overlays). The row that already names remote
    // ownership — who is controlling, or failing that this device — is
    // the one a listener is most likely to act on next.
    final primarySessionId =
        state.controllingSessionId ??
        (thisDevice.isEmpty ? null : thisDevice.first.sessionId);
    final television = TelevisionModeScope.of(context);
    bool autofocusFor(ConnectedDevice device) =>
        television && device.sessionId == primarySessionId;

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
                DeviceRow(
                  device: device,
                  state: state,
                  cubit: cubit,
                  autofocus: autofocusFor(device),
                ),
              if (others.isNotEmpty) const Divider(height: 1),
              for (final device in others)
                DeviceRow(
                  device: device,
                  state: state,
                  cubit: cubit,
                  autofocus: autofocusFor(device),
                ),
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
/// [DeviceReachability] for a peer, this device's own `PlaybackUiState`
/// for its own row) into the one vocabulary `Roadmap to v0.6.md` asks a
/// device list to show: active, available, connecting, unavailable,
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

/// One row of [DeviceListView] — this device or one of its peers, with
/// whatever action (bring back, control, transfer) its current state
/// makes available.
class DeviceRow extends StatelessWidget {
  const DeviceRow({
    required this.device,
    required this.state,
    required this.cubit,
    this.autofocus = false,
    super.key,
  });

  final ConnectedDevice device;
  final DevicePickerState state;
  final DevicePickerCubit cubit;

  /// Whether this row should take D-pad focus the moment its list opens.
  /// Set on the one row naming current remote ownership; see
  /// [DeviceListView].
  final bool autofocus;

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
      autofocus: autofocus,
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
