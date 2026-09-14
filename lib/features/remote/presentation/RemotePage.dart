import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/connected_playback/SyncPlayGroupCubit.dart';
import '../../../app/connected_playback/SyncPlayGroupState.dart';
import '../../../app/di/service_locator.dart';
import '../../../design/design.dart';
import '../../../domain/connected_playback/sync_play_group_status.dart';
import '../../playback/presentation/DeviceListView.dart';
import '../../playback/presentation/device_picker_cubit.dart';

/// The "Remote" shell destination (v0.6.0) — the other half of what Ben
/// called "most important," alongside auto-detection: somewhere to look
/// on purpose rather than wait to be told. Lists this profile's devices,
/// says which one owns playback, and offers the same takeover/transfer
/// actions the device picker sheet already does (v0.5.5/v0.5.6), reusing
/// [DeviceListView] so the two read identically. Also where "play on all
/// devices" (ADR-0045) is started and where the group it opens is seen —
/// [SyncPlayGroupCubit] is a `@lazySingleton`, so this page reads the one
/// app-wide group instead of owning a session-scoped one the way
/// [DevicePickerCubit] is owned below.
///
/// A page of its own rather than only a sheet: reachable from the shell's
/// bottom navigation/TV rail (`ShellDestination`) the same way Home,
/// Favorites and Library are, so a listener does not have to already be
/// looking at a mini-player to reach it.
class RemotePage extends StatefulWidget {
  const RemotePage({super.key, this.cubit, this.groupCubit});

  /// Injectable seams for widget tests; the graph supplies these in the
  /// app.
  final DevicePickerCubit? cubit;
  final SyncPlayGroupCubit? groupCubit;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  late final DevicePickerCubit _cubit = widget.cubit ?? getIt<DevicePickerCubit>();
  late final bool _ownsCubit = widget.cubit == null;
  late final SyncPlayGroupCubit _groupCubit =
      widget.groupCubit ?? getIt<SyncPlayGroupCubit>();

  @override
  void dispose() {
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocProvider<DevicePickerCubit>.value(
      value: _cubit,
      child: BlocProvider<SyncPlayGroupCubit>.value(
        value: _groupCubit,
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
                  BlocBuilder<DevicePickerCubit, DevicePickerState>(
                    builder: (context, pickerState) =>
                        BlocBuilder<SyncPlayGroupCubit, SyncPlayGroupState>(
                          builder: (context, groupState) => TextButton.icon(
                            onPressed: pickerState.localHasQueue &&
                                    groupState.status != SyncPlayGroupStatus.joining
                                ? _groupCubit.playOnAllDevices
                                : null,
                            icon: const Icon(Icons.speaker_group_rounded),
                            label: Text(
                              groupState.status == SyncPlayGroupStatus.joined
                                  ? 'Playing on all devices'
                                  : 'Play on all devices',
                            ),
                          ),
                        ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.spacing.md,
                0,
                t.spacing.md,
                t.spacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'This profile\'s devices, and where your music is playing.',
                  style: t.typography.bodyMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
            ),
            BlocBuilder<SyncPlayGroupCubit, SyncPlayGroupState>(
              builder: (context, groupState) {
                final banner = _groupBanner(groupState);
                if (banner == null) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.md,
                    0,
                    t.spacing.md,
                    t.spacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        groupState.status == SyncPlayGroupStatus.failed
                            ? Icons.error_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: groupState.status == SyncPlayGroupStatus.failed
                            ? t.colors.danger
                            : t.colors.textSecondary,
                      ),
                      SizedBox(width: t.spacing.xs),
                      Expanded(
                        child: Text(
                          banner,
                          style: t.typography.caption.copyWith(
                            color:
                                groupState.status == SyncPlayGroupStatus.failed
                                ? t.colors.danger
                                : t.colors.textSecondary,
                          ),
                        ),
                      ),
                      if (groupState.status == SyncPlayGroupStatus.joined)
                        TextButton(
                          onPressed: _groupCubit.leave,
                          child: const Text('Leave'),
                        ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: BlocBuilder<DevicePickerCubit, DevicePickerState>(
                builder: (context, state) =>
                    DeviceListView(state: state, cubit: _cubit),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _groupBanner(SyncPlayGroupState state) => switch (state.status) {
    SyncPlayGroupStatus.none => null,
    SyncPlayGroupStatus.joining => 'Starting a group…',
    SyncPlayGroupStatus.leaving => 'Leaving the group…',
    SyncPlayGroupStatus.joined => switch (state.members.length) {
      0 => 'In "${state.groupName}", playing here for now.',
      1 => 'In "${state.groupName}" with 1 other device.',
      final n => 'In "${state.groupName}" with $n other devices.',
    },
    SyncPlayGroupStatus.failed =>
      state.failureMessage ?? 'Could not start a group.',
  };
}
