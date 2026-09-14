import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/connected_playback/PlaybackControlCubit.dart';
import '../../../app/connected_playback/SyncPlayGroupCubit.dart';
import '../../../app/connected_playback/SyncPlayGroupState.dart';
import '../../../app/di/service_locator.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../design/design.dart';
import '../../../domain/connected_playback/ConnectedDevice.dart';
import '../../../domain/connected_playback/sync_play_group_status.dart';
import '../../playback/presentation/device_picker_cubit.dart';

/// The active-device view for connected playback. Unlike the general device
/// picker, this deliberately only shows peers with playback to act on.
class RemotePage extends StatefulWidget {
  const RemotePage({super.key, this.cubit, this.groupCubit, this.control});

  final DevicePickerCubit? cubit;
  final SyncPlayGroupCubit? groupCubit;
  final PlaybackControlCubit? control;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  late final DevicePickerCubit _cubit =
      widget.cubit ?? getIt<DevicePickerCubit>();
  late final bool _ownsCubit = widget.cubit == null;
  late final SyncPlayGroupCubit _groupCubit =
      widget.groupCubit ?? getIt<SyncPlayGroupCubit>();
  late final PlaybackControlCubit _control =
      widget.control ?? getIt<PlaybackControlCubit>();

  @override
  void dispose() {
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MultiBlocProvider(
      providers: [
        BlocProvider<DevicePickerCubit>.value(value: _cubit),
        BlocProvider<SyncPlayGroupCubit>.value(value: _groupCubit),
        BlocProvider<PlaybackControlCubit>.value(value: _control),
      ],
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacing.md,
              t.spacing.sm,
              t.spacing.md,
              t.spacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Remote',
                    style: t.typography.titleLarge.copyWith(
                      color: t.colors.textPrimary,
                    ),
                  ),
                ),
                BlocBuilder<SyncPlayGroupCubit, SyncPlayGroupState>(
                  builder: (context, group) =>
                      group.status == SyncPlayGroupStatus.joined
                      ? TextButton.icon(
                          onPressed: _groupCubit.leave,
                          icon: const Icon(Icons.link_off_rounded),
                          label: const Text('End Sync'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What is playing on your other devices.',
                style: t.typography.bodyMedium.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
            ),
          ),
          SizedBox(height: t.spacing.sm),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<DevicePickerCubit, DevicePickerState>(
              builder: (context, devices) =>
                  BlocBuilder<PlaybackControlCubit, PlaybackControlState>(
                    builder: (context, control) => _RemoteDeviceList(
                      devices: devices.devices,
                      controllingSessionId: control.device?.sessionId,
                      onControl: _controlDevice,
                      onSync: _syncDevice,
                      onTransfer: _transferToThisDevice,
                      onEnd: _endRemotePlay,
                      diagnostic: control.commandError,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _controlDevice(ConnectedDevice device) async {
    // Choosing another output is explicit consent to stop this device's audio;
    // its queue remains intact, exactly like an ordinary pause.
    final local = getIt<PlaybackCubit>();
    if (local.state.isPlaying) await local.pause();
    await _groupCubit.leave();
    await _control.control(device);
  }

  Future<void> _syncDevice(ConnectedDevice device) async {
    final projection = await _readRemoteQueue(device);
    if (projection == null || projection.queue.isEmpty) return;
    if (projection.syncGroupId != null) {
      await _control.stop();
      await _groupCubit.joinGroup(projection.syncGroupId!);
      return;
    }
    final local = getIt<PlaybackCubit>();
    // Joining starts both speakers from the same queue and position. The
    // target keeps playing; only the temporary control relationship ends.
    await local.adoptTransferredQueue(
      projection.queue.entries.map((entry) => entry.toTrack()).toList(),
      startIndex: projection.queue.currentPlayPosition,
      shuffleEnabled: projection.queue.shuffleEnabled,
      repeatMode: projection.queue.repeatMode,
      startPosition: projection.position,
      startPlaying: projection.isPlaying,
    );
    await _control.stop();
    await _groupCubit.playOnAllDevices();
    final joined = await _waitForGroup();
    if (joined == null) return;
    await _control.control(device);
    await _control.joinSyncGroup(joined);
    await _control.stop();
  }

  Future<void> _transferToThisDevice(ConnectedDevice device) async {
    final projection = await _readRemoteQueue(device);
    if (projection == null || projection.queue.isEmpty) return;
    // Resolve the complete local queue before stopping the source. The source
    // is only paused once this device has a usable, display-shaped queue.
    final tracks = projection.queue.entries
        .map((entry) => entry.toTrack())
        .toList();
    final paused = await _control.pause();
    if (paused.isErr) return;
    await _control.stop();
    await getIt<PlaybackCubit>().adoptTransferredQueue(
      tracks,
      startIndex: projection.queue.currentPlayPosition,
      shuffleEnabled: projection.queue.shuffleEnabled,
      repeatMode: projection.queue.repeatMode,
      startPosition: projection.position,
      startPlaying: projection.isPlaying,
    );
  }

  Future<PlaybackControlState?> _readRemoteQueue(ConnectedDevice device) async {
    await _groupCubit.leave();
    await _control.control(device);
    if (_control.state.device?.sessionId == device.sessionId &&
        _control.state.hasQueue) {
      return _control.state;
    }
    try {
      return await _control.stream
          .firstWhere(
            (state) =>
                state.device?.sessionId == device.sessionId && state.hasQueue,
          )
          .timeout(const Duration(seconds: 17));
    } on TimeoutException {
      return null;
    }
  }

  Future<String?> _waitForGroup() async {
    if (_groupCubit.state.status == SyncPlayGroupStatus.joined) {
      return _groupCubit.state.groupId;
    }
    try {
      final state = await _groupCubit.stream
          .firstWhere(
            (state) =>
                state.status == SyncPlayGroupStatus.joined ||
                state.status == SyncPlayGroupStatus.failed,
          )
          .timeout(const Duration(seconds: 17));
      return state.status == SyncPlayGroupStatus.joined ? state.groupId : null;
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _endRemotePlay() async {
    if (_groupCubit.state.status == SyncPlayGroupStatus.joined) {
      await _groupCubit.leave();
    }
    await _control.stop();
  }
}

class _RemoteDeviceList extends StatelessWidget {
  const _RemoteDeviceList({
    required this.devices,
    required this.controllingSessionId,
    required this.onControl,
    required this.onSync,
    required this.onTransfer,
    required this.onEnd,
    this.diagnostic,
  });

  final List<ConnectedDevice> devices;
  final String? controllingSessionId;
  final Future<void> Function(ConnectedDevice) onControl;
  final Future<void> Function(ConnectedDevice) onSync;
  final Future<void> Function(ConnectedDevice) onTransfer;
  final Future<void> Function() onEnd;
  final String? diagnostic;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final visible = [
      for (final device in devices)
        if (!device.isThisDevice &&
            (device.isPlaying || device.sessionId == controllingSessionId))
          device,
    ];
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(t.spacing.lg),
          child: Text(
            'Nothing is loaded on your other devices.',
            textAlign: TextAlign.center,
            style: t.typography.bodyMedium.copyWith(
              color: t.colors.textSecondary,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(t.spacing.sm),
      itemCount: visible.length,
      separatorBuilder: (_, _) => SizedBox(height: t.spacing.xs),
      itemBuilder: (context, index) {
        final device = visible[index];
        final controlling = device.sessionId == controllingSessionId;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(t.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    controlling
                        ? Icons.cast_connected_rounded
                        : Icons.speaker_rounded,
                  ),
                  title: Text(device.displayName),
                  subtitle: Text(
                    controlling ? 'Playing on this device' : 'Playing',
                  ),
                  trailing: Icon(
                    device.isPlaying
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                ),
                if (diagnostic != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: t.spacing.xs),
                    child: SelectableText(
                      "Remote diagnostic: $diagnostic",
                      style: t.typography.caption.copyWith(
                        color: t.colors.danger,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: t.spacing.xs,
                  runSpacing: t.spacing.xs,
                  children: controlling
                      ? [
                          OutlinedButton.icon(
                            onPressed: onEnd,
                            icon: const Icon(Icons.link_off_rounded),
                            label: const Text('End Remote Play'),
                          ),
                        ]
                      : [
                          OutlinedButton(
                            onPressed: () => onControl(device),
                            child: const Text('Control'),
                          ),
                          OutlinedButton(
                            onPressed: () => onSync(device),
                            child: const Text('Sync'),
                          ),
                          FilledButton(
                            onPressed: () => onTransfer(device),
                            child: const Text('Play on this device'),
                          ),
                        ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
