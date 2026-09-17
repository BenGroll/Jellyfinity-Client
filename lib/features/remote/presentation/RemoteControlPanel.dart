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
import '../../../domain/connected_playback/ConnectedPlaybackTransport.dart';
import '../../../domain/connected_playback/sync_play_group_status.dart';
import '../../../app/platform/television_mode.dart';
import '../../../domain/connected_playback/device_reachability.dart';
import '../../../domain/media/media.dart';
import '../../music/presentation/widgets/MediaArtwork.dart';
import '../../playback/presentation/device_picker_cubit.dart';

/// The device roster and all actions that change remote-play ownership.
/// Shared by the Remote destination and the device action sheet.
class RemoteControlPanel extends StatefulWidget {
  const RemoteControlPanel({
    super.key,
    this.cubit,
    this.groupCubit,
    this.control,
    this.title = 'Remote',
  });

  final DevicePickerCubit? cubit;
  final SyncPlayGroupCubit? groupCubit;
  final PlaybackControlCubit? control;
  final String title;

  @override
  State<RemoteControlPanel> createState() => _RemoteControlPanelState();
}

class _RemoteControlPanelState extends State<RemoteControlPanel> {
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
                    widget.title,
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
              builder: (context, devices) => Column(
                children: [
                  SizedBox(
                    height: 220,
                    child:
                        BlocBuilder<PlaybackControlCubit, PlaybackControlState>(
                          builder: (context, control) => _LocalAndSyncSummary(
                            state: devices,
                            groupCubit: _groupCubit,
                            onPlayAll: _groupCubit.playOnAllDevices,
                            onBringBack: _cubit.bringBackToThisDevice,
                            controlledBy: control.controlledBy,
                          ),
                        ),
                  ),
                  Expanded(
                    child:
                        BlocBuilder<PlaybackControlCubit, PlaybackControlState>(
                          builder: (context, control) => _RemoteDeviceList(
                            devices: devices.devices,
                            controllingSessionId: control.device?.sessionId,
                            controlledBySessionId:
                                control.controlledBy?.sessionId,
                            onControl: _controlDevice,
                            onSync: _syncDevice,
                            onTransfer: _transferToThisDevice,
                            onEnd: _endRemotePlay,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _controlDevice(ConnectedDevice device) async {
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
    final local = getIt<PlaybackCubit>();
    final tracks = projection.queue.entries
        .map((entry) => entry.toTrack())
        .toList();
    await local.adoptTransferredQueue(
      tracks,
      startIndex: projection.queue.currentPlayPosition,
      shuffleEnabled: projection.queue.shuffleEnabled,
      repeatMode: projection.queue.repeatMode,
      startPosition: projection.position,
      startPlaying: projection.isPlaying,
    );
    if (projection.isPlaying && !local.state.isPlaying) return;

    // Playback is here now, so the roles swap: the device that was
    // playing becomes the remote for this one. Asking it to take control
    // before letting go of it means the listener is never briefly holding
    // two devices that are each doing nothing, which is what "End Remote
    // Play with nothing being controlled" looked like.
    await _control.pause();
    final localSessionId = getIt<ConnectedPlaybackTransport>().localSessionId;
    if (localSessionId != null) {
      await _control.handControlBack(localSessionId);
    }
    await _control.stop();
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

class _LocalAndSyncSummary extends StatelessWidget {
  const _LocalAndSyncSummary({
    required this.state,
    required this.groupCubit,
    required this.onPlayAll,
    required this.onBringBack,
    this.controlledBy,
  });

  final DevicePickerState state;
  final SyncPlayGroupCubit groupCubit;
  final Future<void> Function() onPlayAll;
  final Future<void> Function() onBringBack;

  /// The device driving this one, when one is — the other half of the
  /// relationship, which this screen previously never showed.
  final ConnectedDevice? controlledBy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return BlocBuilder<SyncPlayGroupCubit, SyncPlayGroupState>(
      bloc: groupCubit,
      builder: (context, group) {
        final action = switch (group.status) {
          SyncPlayGroupStatus.none || SyncPlayGroupStatus.failed => TextButton(
            onPressed: state.localIsPlaying ? onPlayAll : null,
            child: const Text('Play on all devices'),
          ),
          SyncPlayGroupStatus.joining => const TextButton(
            onPressed: null,
            child: Text('Starting a group…'),
          ),
          SyncPlayGroupStatus.joined ||
          SyncPlayGroupStatus.leaving => TextButton(
            onPressed: group.status == SyncPlayGroupStatus.joined
                ? groupCubit.leave
                : null,
            child: const Text('Leave'),
          ),
        };
        return Padding(
          padding: EdgeInsets.fromLTRB(
            t.spacing.md,
            t.spacing.xs,
            t.spacing.md,
            t.spacing.xs,
          ),
          child: Column(
            children: [
              ListTile(
                autofocus: TelevisionModeScope.of(context),
                leading: Icon(
                  state.localIsPlaying
                      ? Icons.play_circle_fill_rounded
                      : Icons.speaker_outlined,
                ),
                title: const Text('This device'),
                subtitle: Text(
                  controlledBy != null
                      ? '${controlledBy!.displayName} is controlling this device'
                      : state.localIsPlaying
                      ? 'Playing here'
                      : state.localHasQueue
                      ? 'Paused here — tap to bring it back'
                      : 'Nothing to play here yet',
                ),
                onTap: state.localHasQueue && !state.localIsPlaying
                    ? onBringBack
                    : null,
              ),
              Align(alignment: Alignment.centerRight, child: action),
              if (group.status == SyncPlayGroupStatus.joined)
                const Text('Playing on all devices'),
              if (group.status == SyncPlayGroupStatus.joined &&
                  group.groupName != null)
                Text('In "${group.groupName}", playing here for now.'),
              if (group.status == SyncPlayGroupStatus.failed &&
                  group.failureMessage != null)
                Text(
                  group.failureMessage!,
                  style: TextStyle(color: t.colors.danger),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RemoteDeviceList extends StatelessWidget {
  const _RemoteDeviceList({
    required this.devices,
    required this.controllingSessionId,
    required this.controlledBySessionId,
    required this.onControl,
    required this.onSync,
    required this.onTransfer,
    required this.onEnd,
  });

  final List<ConnectedDevice> devices;
  final String? controllingSessionId;

  /// The session driving this device, when one is — so a row can stop
  /// offering to bring playback here that is already here.
  final String? controlledBySessionId;
  final Future<void> Function(ConnectedDevice) onControl;
  final Future<void> Function(ConnectedDevice) onSync;
  final Future<void> Function(ConnectedDevice) onTransfer;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Only devices that are actually there and can actually be driven.
    // A row nothing can be done with is worse than no row: a device that
    // the server has listed but that has never answered Jellyfinity's own
    // presence exchange cannot be controlled, and showing it as though it
    // could is how this screen came to be full of devices that did
    // nothing when tapped.
    final visible = [
      for (final device in devices)
        if (!device.isThisDevice && device.reachability.canReceiveCommands)
          device,
    ];
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(t.spacing.lg),
          child: Text(
            'No other Jellyfinity devices found on this server yet.',
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
        final controlsThisDevice = device.sessionId == controlledBySessionId;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(t.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _DeviceArtwork(
                    device: device,
                    controlling: controlling,
                  ),
                  title: Text(device.displayName),
                  subtitle: _subtitle(device, controlling, controlsThisDevice),
                  trailing: Icon(
                    device.isPlaying
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                ),
                Wrap(
                  spacing: t.spacing.xs,
                  runSpacing: t.spacing.xs,
                  children: [
                    // Only what makes sense for the relationship this row
                    // is actually in. "Play on this device" beside a
                    // device that is playing nothing — or that is this
                    // device's own remote — is an instruction with no
                    // meaning, and offering it is how the screen came to
                    // need explaining.
                    if (controlling) ...[
                      FilledButton(
                        onPressed: () => onTransfer(device),
                        child: const Text('Play here instead'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onEnd,
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Stop controlling'),
                      ),
                    ] else if (controlsThisDevice) ...[
                      OutlinedButton(
                        onPressed: () => onControl(device),
                        child: const Text('Control it instead'),
                      ),
                    ] else ...[
                      FilledButton(
                        onPressed: () => onControl(device),
                        child: const Text('Control'),
                      ),
                      if (device.isPlaying) ...[
                        OutlinedButton(
                          onPressed: () => onTransfer(device),
                          child: const Text('Play here'),
                        ),
                        OutlinedButton(
                          onPressed: () => onSync(device),
                          child: const Text('Play on both'),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _subtitle(
    ConnectedDevice device,
    bool controlling,
    bool controlsThisDevice,
  ) {
    final track = _nowPlayingLabel(device);
    final status = controlling
        ? 'You are controlling it'
        : controlsThisDevice
        ? 'It is controlling this device'
        : _statusLabel(device);
    if (track == null) return Text(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(track, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(status),
      ],
    );
  }

  static String? _nowPlayingLabel(ConnectedDevice device) {
    final title = device.nowPlayingTitle;
    final artist = device.nowPlayingArtist;
    if (title == null || title.isEmpty) return null;
    if (artist == null || artist.isEmpty) return title;
    return '$artist • $title';
  }

  static String _statusLabel(ConnectedDevice device) {
    if (device.isPlaying) return 'Playing';
    return switch (device.reachability) {
      DeviceReachability.ready =>
        device.canReceiveTransfer
            ? 'Available'
            : 'Cannot receive a transfer from this app version',
      DeviceReachability.presenceOnly => 'Connecting…',
      DeviceReachability.stale => 'Not seen recently',
      DeviceReachability.incompatible => 'Needs a matching Jellyfinity version',
      DeviceReachability.notPermitted => 'Permission denied',
      DeviceReachability.offline => 'Unavailable',
    };
  }
}

/// The device row's leading visual: real album art for whatever the peer
/// is currently playing, with a small cast badge over it while this
/// device is the one controlling it. Falls back to `MediaArtwork`'s own
/// quiet placeholder when nothing is playing or an older peer has not
/// sent an artwork pointer yet.
class _DeviceArtwork extends StatelessWidget {
  const _DeviceArtwork({required this.device, required this.controlling});

  final ConnectedDevice device;
  final bool controlling;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MediaArtwork(
            image: device.nowPlayingImage,
            kind: MediaKind.track,
            size: _size,
          ),
          if (controlling)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: t.colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cast_connected_rounded,
                  size: 14,
                  color: t.colors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
