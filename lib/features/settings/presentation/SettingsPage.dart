import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/settings/SettingsCubit.dart';
import '../../../app/settings/ShellNavigationMode.dart';
import '../../../design/design.dart';

/// Jellyfinity's settings screen. One real control today — which
/// navigation-mode presentation the shell uses — with room to grow the
/// same way `JellyfinityApp`'s theme-mode comment already anticipates.
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
              _NavigationModeOption(
                mode: ShellNavigationMode.mediaPills,
                title: 'Media pills',
                description:
                    'A row of media-type pills under search lets you '
                    'switch what Home and Library show.',
                selected:
                    state.navigationMode == ShellNavigationMode.mediaPills,
              ),
              _NavigationModeOption(
                mode: ShellNavigationMode.unified,
                title: 'Unified',
                description:
                    'No pill row — Home and Library show one blended '
                    'view across every available media type.',
                selected: state.navigationMode == ShellNavigationMode.unified,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavigationModeOption extends StatelessWidget {
  const _NavigationModeOption({
    required this.mode,
    required this.title,
    required this.description,
    required this.selected,
  });

  final ShellNavigationMode mode;
  final String title;
  final String description;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ListTile(
      onTap: () => context.read<SettingsCubit>().setNavigationMode(mode),
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
