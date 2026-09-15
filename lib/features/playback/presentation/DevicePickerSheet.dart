import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/service_locator.dart';
import '../../../design/design.dart';
import '../../../domain/connected_playback/ConnectedDevice.dart';
import 'DeviceListView.dart';
import '../../remote/presentation/RemoteControlPanel.dart';
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
                    builder: (context, state) => DeviceListView(
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
            onPressed: () => showRemoteControlSheet(context, cubit: _cubit),
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

/// Opens the full remote-control panel in a modal sheet.
Future<void> showRemoteControlSheet(
  BuildContext context, {
  DevicePickerCubit? cubit,
}) {
  final ownsCubit = cubit == null;
  final resolved = cubit ?? getIt<DevicePickerCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SizedBox(
      height: (MediaQuery.sizeOf(sheetContext).height * 0.8).clamp(
        360.0,
        680.0,
      ),
      child: RemoteControlPanel(cubit: resolved, title: 'Devices'),
    ),
  ).whenComplete(() {
    if (ownsCubit) unawaited(resolved.close());
  });
}
