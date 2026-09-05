import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/connectivity/OfflineCubit.dart';
import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';
import '../../../domain/connectivity/OfflineMode.dart';

/// Everything that isn't a media-type concern lives here, not in the
/// media-pills row: accounts and app settings today, whatever else
/// Jellyfinity grows (social features, ...) later. Opened by
/// [HomeLibraryHeader]'s menu button, or Flutter's default `Drawer`
/// left-edge swipe — no custom gesture code.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Drawer(
      backgroundColor: t.colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.spacing.md,
                t.spacing.lg,
                t.spacing.md,
                t.spacing.md,
              ),
              child: Text(
                'Jellyfinity',
                style: t.typography.headlineLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
            ),
            Divider(color: t.colors.border, height: 1),
            const _GoOfflineTile(),
            Divider(color: t.colors.border, height: 1),
            ListTile(
              leading: Icon(
                Icons.account_circle_outlined,
                color: t.colors.textSecondary,
              ),
              title: Text(
                'Accounts',
                style: t.typography.bodyLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Switch profile, sign out, manage servers',
                style: t.typography.caption.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.pushNamed(RouteNames.accounts);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.download_done_rounded,
                color: t.colors.textSecondary,
              ),
              title: Text(
                'Downloads',
                style: t.typography.bodyLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Offline music, progress, and storage use',
                style: t.typography.caption.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.pushNamed(RouteNames.downloads);
              },
            ),
            ListTile(
              leading: Icon(Icons.tune_rounded, color: t.colors.textSecondary),
              title: Text(
                'Settings',
                style: t.typography.bodyLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.pushNamed(RouteNames.settings);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Work offline" switch (v0.2.3).
///
/// Editable on a connection: turning it on stops Jellyfinity reaching for
/// the server, so the library and search answer from the device. With no
/// connection it is shown on and disabled — the app is already offline —
/// with a line saying why. Whether it narrows the library to downloads or
/// keeps the whole cached view is the "Offline library" setting.
class _GoOfflineTile extends StatelessWidget {
  const _GoOfflineTile();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocBuilder<OfflineCubit, OfflineStatus>(
      builder: (context, status) {
        final forced = status.isForcedByConnection;
        return SwitchListTile(
          secondary: Icon(
            status.isOffline
                ? Icons.cloud_off_rounded
                : Icons.cloud_queue_rounded,
            color: status.isOffline ? t.colors.accent : t.colors.textSecondary,
          ),
          title: Text(
            'Work offline',
            style: t.typography.bodyLarge.copyWith(color: t.colors.textPrimary),
          ),
          subtitle: Text(
            forced
                ? "No connection — Jellyfinity is offline until one returns."
                : 'Stop using the server. Browse and play what is on this '
                      'device.',
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
          value: status.isOffline,
          activeThumbColor: t.colors.accent,
          onChanged: forced
              ? null
              : (value) =>
                    context.read<OfflineCubit>().setManualOffline(value),
        );
      },
    );
  }
}
