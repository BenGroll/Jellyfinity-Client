import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/service_locator.dart';
import '../../../design/design.dart';
import '../../playback/presentation/DeviceListView.dart';
import '../../playback/presentation/device_picker_cubit.dart';

/// The "Remote" shell destination (v0.6.0) — the other half of what Ben
/// called "most important," alongside auto-detection: somewhere to look
/// on purpose rather than wait to be told. Lists this profile's devices,
/// says which one owns playback, and offers the same takeover/transfer
/// actions the device picker sheet already does (v0.5.5/v0.5.6), reusing
/// [DeviceListView] so the two read identically.
///
/// A page of its own rather than only a sheet: reachable from the shell's
/// bottom navigation/TV rail (`ShellDestination`) the same way Home,
/// Favorites and Library are, so a listener does not have to already be
/// looking at a mini-player to reach it.
class RemotePage extends StatefulWidget {
  const RemotePage({super.key, this.cubit});

  /// Injectable seam for widget tests; the graph supplies one in the app.
  final DevicePickerCubit? cubit;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  late final DevicePickerCubit _cubit = widget.cubit ?? getIt<DevicePickerCubit>();
  late final bool _ownsCubit = widget.cubit == null;

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
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<DevicePickerCubit, DevicePickerState>(
              builder: (context, state) =>
                  DeviceListView(state: state, cubit: _cubit),
            ),
          ),
        ],
      ),
    );
  }
}
