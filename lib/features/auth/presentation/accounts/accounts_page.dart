import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../design/design.dart';
import '../../../../domain/session/jellyfin_account.dart';
import 'accounts_cubit.dart';

/// Saved servers & profiles: switch the active profile, sign out, or
/// remove a saved profile or server. The first, deliberately simple
/// multi-account surface (roadmap v0.0.5: "the first UI can remain
/// simple").
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, this.cubit});

  final AccountsCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountsCubit>(
      create: (_) => (cubit ?? getIt<AccountsCubit>())..load(),
      child: const _AccountsView(),
    );
  }
}

class _AccountsView extends StatelessWidget {
  const _AccountsView();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppScaffold(
      title: 'Accounts',
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            )
          : null,
      body: BlocBuilder<AccountsCubit, AccountsState>(
        builder: (context, state) {
          if (state is! AccountsLoaded) {
            return const AppSkeletonList(itemCount: 4);
          }

          return ListView(
            padding: EdgeInsets.symmetric(vertical: t.spacing.md),
            children: [
              for (final group in state.groups) ...[
                _ServerHeader(
                  name: group.server.name,
                  baseUrl: group.server.baseUrl,
                  onRemove: () =>
                      _confirmRemoveServer(context, group.server.id),
                ),
                for (final account in group.accounts)
                  _AccountRow(
                    account: account,
                    isActive: account.id == state.activeAccountId,
                    onTap: account.id == state.activeAccountId
                        ? null
                        : () => context.read<AccountsCubit>().switchTo(
                            account.id,
                          ),
                    onRemove: () => _confirmRemoveAccount(context, account.id),
                  ),
                SizedBox(height: t.spacing.md),
              ],
              if (state.isEmpty)
                Padding(
                  padding: EdgeInsets.all(t.spacing.lg),
                  child: Text(
                    'No saved accounts yet.',
                    style: t.typography.bodyMedium.copyWith(
                      color: t.colors.textSecondary,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(t.spacing.md),
                child: AppButton(
                  label: 'Add another account',
                  icon: Icons.add_rounded,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  onPressed: () => context.pushNamed(RouteNames.connect),
                ),
              ),
              if (state.activeAccountId != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
                  child: AppButton(
                    label: 'Sign out',
                    icon: Icons.logout_rounded,
                    variant: AppButtonVariant.ghost,
                    expand: true,
                    onPressed: () => context.read<AccountsCubit>().signOut(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRemoveAccount(BuildContext context, String id) async {
    final cubit = context.read<AccountsCubit>();
    final ok = await _confirm(
      context,
      title: 'Remove this profile?',
      message: 'Its saved sign-in will be deleted from this device.',
    );
    if (ok) await cubit.removeAccount(id);
  }

  Future<void> _confirmRemoveServer(BuildContext context, String id) async {
    final cubit = context.read<AccountsCubit>();
    final ok = await _confirm(
      context,
      title: 'Remove this server?',
      message: 'Every saved profile on it will be removed from this device.',
    );
    if (ok) await cubit.removeServer(id);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ServerHeader extends StatelessWidget {
  const _ServerHeader({
    required this.name,
    required this.baseUrl,
    required this.onRemove,
  });

  final String name;
  final String baseUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.md,
        t.spacing.md,
        t.spacing.xs,
        t.spacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: t.typography.label.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
                Text(
                  baseUrl,
                  style: t.typography.caption.copyWith(
                    color: t.colors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Remove server',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
  });

  final JellyfinAccount account;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spacing.md,
            vertical: t.spacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: t.colors.surfaceElevated,
                child: Text(
                  _initial(account.username),
                  style: t.typography.label.copyWith(
                    color: t.colors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: t.spacing.sm),
              Expanded(
                child: Text(
                  account.username,
                  style: t.typography.titleMedium.copyWith(
                    color: t.colors.textPrimary,
                  ),
                ),
              ),
              if (isActive)
                Padding(
                  padding: EdgeInsets.only(right: t.spacing.xs),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: t.colors.accent,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Remove profile',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
