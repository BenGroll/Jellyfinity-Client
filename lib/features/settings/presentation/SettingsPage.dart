import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/settings/SettingsCubit.dart';
import '../../../app/settings/ShellNavigationMode.dart';
import '../../../design/design.dart';
import '../../../domain/connectivity/OfflineLibraryScope.dart';
import '../../../domain/playback/CrossfadeSettings.dart';
import '../../../domain/playback/stream_quality.dart';

/// Jellyfinity's settings screen: which navigation-mode presentation the
/// shell uses, which streaming quality playback requests (ADR-0015), the
/// quality and network policy for downloads (ADR-0022), how tracks hand
/// over to one another (ADR-0016), and whether loudness is normalized
/// between them (ADR-0017) — with room to grow the same way
/// `JellyfinityApp`'s theme-mode comment already anticipates.
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
              _StreamQualityDropdown(selected: state.streamQuality),
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
                child: Text(
                  'Downloads',
                  style: t.typography.titleMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
              _DownloadQualityDropdown(selected: state.downloadQuality),
              SwitchListTile(
                value: state.downloadsWifiOnly,
                title: Text(
                  'Download on Wi-Fi only',
                  style: t.typography.bodyLarge.copyWith(
                    color: t.colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Holds downloads until you are on Wi-Fi instead of using '
                  'mobile data. A held download resumes on its own. Enforced '
                  'while the app is open; a transfer already running is not '
                  'interrupted.',
                  style: t.typography.caption.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
                activeThumbColor: t.colors.accent,
                onChanged: (enabled) =>
                    context.read<SettingsCubit>().setDownloadsWifiOnly(enabled),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
                child: Text(
                  'Offline library',
                  style: t.typography.titleMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
              _SettingsOption(
                selected:
                    state.offlineLibraryScope == OfflineLibraryScope.unlimited,
                title: 'Show everything',
                description:
                    'While offline, keep the whole browsed library visible '
                    'and mark what is downloaded. Anything not on the device '
                    'cannot play until you are back online.',
                onTap: () => context
                    .read<SettingsCubit>()
                    .setOfflineLibraryScope(OfflineLibraryScope.unlimited),
              ),
              _SettingsOption(
                selected:
                    state.offlineLibraryScope == OfflineLibraryScope.limited,
                title: 'Downloads only',
                description:
                    'While offline, the library and search show only music '
                    'kept on this device. Online, the full library is back.',
                onTap: () => context
                    .read<SettingsCubit>()
                    .setOfflineLibraryScope(OfflineLibraryScope.limited),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
                child: Text(
                  'Crossfade',
                  style: t.typography.titleMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
              SwitchListTile(
                value: state.crossfade.enabled,
                title: Text(
                  'Crossfade',
                  style: t.typography.bodyLarge.copyWith(
                    color: t.colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Fades one track into the next instead of playing them '
                  'back to back. Off keeps gapless playback exact.',
                  style: t.typography.caption.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
                activeThumbColor: t.colors.accent,
                onChanged: (enabled) =>
                    context.read<SettingsCubit>().setCrossfadeEnabled(enabled),
              ),
              // Shown only while crossfade is on: a duration slider with
              // nothing to apply to is a control that does nothing.
              if (state.crossfade.enabled)
                _CrossfadeDurationSlider(duration: state.crossfade.duration),
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
                child: Text(
                  'Volume normalization',
                  style: t.typography.titleMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
              SwitchListTile(
                value: state.normalization.enabled,
                title: Text(
                  'Volume normalization',
                  style: t.typography.bodyLarge.copyWith(
                    color: t.colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  "Evens out loud and quiet tracks using your server's "
                  'loudness data, when it has any. Tracks with no '
                  'loudness data play unchanged.',
                  style: t.typography.caption.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
                activeThumbColor: t.colors.accent,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .setNormalizationEnabled(enabled),
              ),
            ],
          );
        },
      ),
    );
  }
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

/// A rough, one-hour-of-continuous-playback estimate shown next to each
/// tier in the dropdown, so "smallest downloads" has a concrete number
/// attached. Original/lossless varies by source file — FLAC commonly runs
/// 800 kbps-1.5 Mbps — so it is quoted as a round "~1 GB/hour" rather than
/// a false-precision figure; the transcoded tiers are computed directly
/// from their fixed bitrate above.
String _qualityDataUsage(StreamQuality quality) => switch (quality) {
  StreamQuality.original => '~1 GB/hour',
  StreamQuality.high => '~140 MB/hour',
  StreamQuality.medium => '~85 MB/hour',
  StreamQuality.dataSaver => '~55 MB/hour',
};

/// The streaming-quality picker: a dropdown rather than one row per tier,
/// with the selected tier's description shown beneath it once picked
/// (v0.1.6) — the same information the old radio list carried, in less
/// vertical space.
class _StreamQualityDropdown extends StatelessWidget {
  const _StreamQualityDropdown({required this.selected});

  final StreamQuality selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: t.spacing.sm),
            decoration: BoxDecoration(
              color: t.colors.surfaceSunken,
              borderRadius: t.radii.mdBorder,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<StreamQuality>(
                value: selected,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: t.colors.textSecondary,
                ),
                dropdownColor: t.colors.surfaceElevated,
                borderRadius: t.radii.mdBorder,
                style: t.typography.bodyLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
                items: [
                  for (final quality in StreamQuality.values)
                    DropdownMenuItem(
                      value: quality,
                      child: Row(
                        children: [
                          Expanded(child: Text(_qualityTitle(quality))),
                          Text(
                            _qualityDataUsage(quality),
                            style: t.typography.caption.copyWith(
                              color: t.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (quality) {
                  if (quality == null) return;
                  context.read<SettingsCubit>().setStreamQuality(quality);
                },
              ),
            ),
          ),
          SizedBox(height: t.spacing.xxs),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.spacing.xs),
            child: Text(
              _qualityDescription(selected),
              style: t.typography.caption.copyWith(
                color: t.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _downloadQualityDescription(StreamQuality quality) => switch (quality) {
  StreamQuality.original =>
    'Keeps the original file, exactly as stored on your server. Largest '
        'files; nothing is re-encoded.',
  StreamQuality.high =>
    'Transcodes to AAC 320 kbps when the source is larger — roughly '
        '150 MB per hour of music.',
  StreamQuality.medium =>
    'Transcodes to AAC 192 kbps when the source is larger — roughly '
        '85 MB per hour of music.',
  StreamQuality.dataSaver =>
    'Transcodes to AAC 128 kbps when the source is larger — smallest '
        'files, roughly 55 MB per hour of music.',
};

/// The download-quality picker (v0.2.2). Same shape as
/// [_StreamQualityDropdown], separate preference: it governs the quality
/// a file is kept at, and takes effect for new and retried downloads
/// without touching anything already on the device.
class _DownloadQualityDropdown extends StatelessWidget {
  const _DownloadQualityDropdown({required this.selected});

  final StreamQuality selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: t.spacing.sm),
            decoration: BoxDecoration(
              color: t.colors.surfaceSunken,
              borderRadius: t.radii.mdBorder,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<StreamQuality>(
                value: selected,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: t.colors.textSecondary,
                ),
                dropdownColor: t.colors.surfaceElevated,
                borderRadius: t.radii.mdBorder,
                style: t.typography.bodyLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
                items: [
                  for (final quality in StreamQuality.values)
                    DropdownMenuItem(
                      value: quality,
                      child: Text(
                        'Download quality: ${_qualityTitle(quality)}',
                      ),
                    ),
                ],
                onChanged: (quality) {
                  if (quality == null) return;
                  context.read<SettingsCubit>().setDownloadQuality(quality);
                },
              ),
            ),
          ),
          SizedBox(height: t.spacing.xxs),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.spacing.xs),
            child: Text(
              _downloadQualityDescription(selected),
              style: t.typography.caption.copyWith(
                color: t.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
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

/// The overlap-length control, in whole seconds between
/// [CrossfadeSettings.minimumDuration] and
/// [CrossfadeSettings.maximumDuration].
///
/// Local to the drag so the label tracks the thumb, while the preference
/// is written once the user lets go rather than on every pixel — one
/// persisted value per adjustment, not dozens.
class _CrossfadeDurationSlider extends StatefulWidget {
  const _CrossfadeDurationSlider({required this.duration});

  final Duration duration;

  @override
  State<_CrossfadeDurationSlider> createState() =>
      _CrossfadeDurationSliderState();
}

class _CrossfadeDurationSliderState extends State<_CrossfadeDurationSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final minimum = CrossfadeSettings.minimumDuration.inSeconds.toDouble();
    final maximum = CrossfadeSettings.maximumDuration.inSeconds.toDouble();
    final seconds = _dragging ?? widget.duration.inSeconds.toDouble();

    return ListTile(
      title: Text(
        'Crossfade length: ${seconds.round()}s',
        style: t.typography.bodyLarge.copyWith(color: t.colors.textPrimary),
      ),
      subtitle: Slider(
        value: seconds.clamp(minimum, maximum),
        min: minimum,
        max: maximum,
        divisions: (maximum - minimum).round(),
        label: '${seconds.round()}s',
        activeColor: t.colors.accent,
        onChanged: (value) => setState(() => _dragging = value),
        onChangeEnd: (value) {
          setState(() => _dragging = null);
          context.read<SettingsCubit>().setCrossfadeDuration(
            Duration(seconds: value.round()),
          );
        },
      ),
    );
  }
}
