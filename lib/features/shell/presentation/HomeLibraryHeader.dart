import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/navigation/MediaScopeCubit.dart';
import '../../../app/settings/SettingsCubit.dart';
import '../../../app/settings/ShellNavigationMode.dart';
import '../../../design/design.dart';

/// The chrome shared by every tab of [AppShell]: a menu button that opens
/// [AppSidebar], and a search field that is always reachable at the top of
/// the UI rather than behind a subscreen (ADR-0014). Below it, a row of
/// media-type pills appears only in [ShellNavigationMode.mediaPills] — in
/// [ShellNavigationMode.unified] there is nothing to switch between, so
/// nothing renders there.
///
/// This widget only ever shows the *inactive* search affordance — tapping
/// it hands control to [AppShell], which swaps the whole header out for
/// `InlineMusicSearch` (the real field lives there, so it can own focus
/// and its own close button).
class HomeLibraryHeader extends StatelessWidget {
  const HomeLibraryHeader({super.key, required this.onSearchTap});

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mode = context.watch<SettingsCubit>().state.navigationMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.spacing.sm,
            t.spacing.xs,
            t.spacing.md,
            t.spacing.xs,
          ),
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: onSearchTap,
                  borderRadius: t.radii.mdBorder,
                  child: Container(
                    height: 40,
                    padding: EdgeInsets.symmetric(horizontal: t.spacing.sm),
                    decoration: BoxDecoration(
                      color: t.colors.surfaceSunken,
                      borderRadius: t.radii.mdBorder,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: t.colors.textSecondary,
                        ),
                        SizedBox(width: t.spacing.xs),
                        Text(
                          'Search',
                          style: t.typography.bodyLarge.copyWith(
                            color: t.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (mode == ShellNavigationMode.mediaPills) const _MediaPillRow(),
      ],
    );
  }
}

class _MediaPillRow extends StatelessWidget {
  const _MediaPillRow();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scope = context.watch<MediaScopeCubit>().state;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          t.spacing.md,
          0,
          t.spacing.md,
          t.spacing.sm,
        ),
        children: [
          for (final c in scope.contexts)
            Padding(
              padding: EdgeInsets.only(right: t.spacing.xs),
              child: ChoiceChip(
                label: Text(c.label),
                selected: c.id == scope.activeId,
                onSelected: (_) => context.read<MediaScopeCubit>().select(c.id),
                labelStyle: t.typography.label.copyWith(
                  color: c.id == scope.activeId
                      ? t.colors.onAccent
                      : t.colors.textPrimary,
                ),
                backgroundColor: t.colors.surfaceElevated,
                selectedColor: t.colors.accent,
                shape: StadiumBorder(side: BorderSide(color: t.colors.border)),
                side: BorderSide.none,
              ),
            ),
        ],
      ),
    );
  }
}
