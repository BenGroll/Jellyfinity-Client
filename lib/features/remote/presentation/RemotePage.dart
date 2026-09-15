import 'package:flutter/material.dart';
import 'RemoteControlPanel.dart';
import '../../playback/presentation/device_picker_cubit.dart';
import '../../../app/connected_playback/PlaybackControlCubit.dart';
import '../../../app/connected_playback/SyncPlayGroupCubit.dart';

class RemotePage extends StatefulWidget {
  const RemotePage({super.key, this.cubit, this.groupCubit, this.control});

  final DevicePickerCubit? cubit;
  final SyncPlayGroupCubit? groupCubit;
  final PlaybackControlCubit? control;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  @override
  Widget build(BuildContext context) => RemoteControlPanel(
    cubit: widget.cubit,
    groupCubit: widget.groupCubit,
    control: widget.control,
  );
}
