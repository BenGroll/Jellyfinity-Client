import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/settings/SettingsCubit.dart';
import '../../../app/settings/ShellNavigationMode.dart';
import '../../../design/design.dart';
import '../../../domain/playback/stream_quality.dart';

/// Jellyfinity's settings screen: which navigation-mode presentation the
/// shell uses, and (ADR-0015) which streaming quality playback requests
/// — with room to grow the same way `JellyfinityApp`'s theme-mode comment
/// already anticipates.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppScaffold(
      title: 'Settings',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
                child: Text(
                  'Navigation style',
                  style: t.typography.titleMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
              _SettingsOption(
                selected:
                    state.navigationMode == ShellNavigationMode.mediaPills,
                title: 'Media pills',
                description:
                    'A row of media-type pills under search lets you '
                    'switch what Home and Library show.',
                onTap: () => context.read<SettingsCubit>().setNavigationMode(
                  ShellNavigationMode.mediaPills,
                ),
              ),
              _SettingsOption(
                selected: state.navigationMode == ShellNavigationMode.unified,
                title: 'Unified',
                description:
                    'No pill row — Home and Library show one blended '
                    'view across every available media type.',
                onTap: () => context.read<SettingsCubit>().setNavigationMode(
                  ShellNavigationMode.unified,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
                child: Text(
                  'Streaming quality',
                  style: t.typography.titleMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
              for (final quality in StreamQuality.values)
                _SettingsOption(
                  selected: state.streamQuality == quality,
                  title: _qualityTitle(quality),
                  description: _qualityDescription(quality),
                  onTap: () =>
                      context.read<SettingsCubit>().setStreamQuality(quality),
                ),
            ],
          );
        },
      ),
    );
  }

  String _qualityTitle(StreamQuality quality) => switch (quality) {
    StreamQuality.original => 'Lossless',
    StreamQuality.high => 'High',
    StreamQuality.medium => 'Medium',
    StreamQuality.dataSaver => 'Data saver',
  };

  String _qualityDescription(StreamQuality quality) => switch (quality) {
    StreamQuality.original =>
      'The original file, exactly as stored on your server. No '
          'transcoding, largest downloads.',
    StreamQuality.high => 'Transcodes to AAC at 320 kbps when needed.',
    StreamQuality.medium => 'Transcodes to AAC at 192 kbps when needed.',
    StreamQuality.dataSaver =>
      'Transcodes to AAC at 128 kbps when needed — smallest downloads, '
          'best for constrained connections.',
  };
}

/// One selectable row in a radio-style settings list — shared by the
/// navigation-mode and streaming-quality sections.
class _SettingsOption extends StatelessWidget {
  const _SettingsOption({
    required this.selected,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? t.colors.accent : t.colors.textSecondary,
      ),
      title: Text(
        title,
        style: t.typography.bodyLarge.copyWith(color: t.colors.textPrimary),
      ),
      subtitle: Text(
        description,
        style: t.typography.caption.copyWith(color: t.colors.textSecondary),
      ),
    );
  }
}
