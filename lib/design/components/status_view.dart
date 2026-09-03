import 'package:flutter/material.dart';

import '../../core/result/failure.dart';
import '../theme/theme_context.dart';
import 'app_button.dart';

/// A centered icon + title + message block, optionally with one action.
///
/// The shared shape behind [EmptyStateView] and [ErrorStateView] so "no
/// results" and "something went wrong" read as the same family. Not usually
/// used directly — reach for the two named variants.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.tone = StatusTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accentColor = switch (tone) {
      StatusTone.neutral => t.colors.textSecondary,
      StatusTone.danger => t.colors.danger,
    };

    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: accentColor),
            SizedBox(height: t.spacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.typography.titleLarge.copyWith(
                color: t.colors.textPrimary,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: t.spacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: t.typography.bodyMedium.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[SizedBox(height: t.spacing.lg), action!],
          ],
        ),
      ),
    );
  }
}

enum StatusTone { neutral, danger }

/// Shown when a request succeeded but there is nothing to display.
///
/// Distinct from an error: nothing went wrong, the collection is simply
/// empty. Never used for loading or failure.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  });

  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return StatusView(
      icon: icon,
      title: title,
      message: message,
      action: (onAction != null && actionLabel != null)
          ? AppButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: AppButtonVariant.secondary,
            )
          : null,
    );
  }
}

/// Shown when an operation failed.
///
/// Prefer [ErrorStateView.forFailure], which reads the [Failure] subtype:
/// a [RecoverableFailure] gets a "Try again" button automatically, other
/// failures don't (retrying a [RecoverableFailure] is the case where it
/// helps). Message text comes from the failure, which per ADR-0004 never
/// contains sensitive data.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  factory ErrorStateView.forFailure(
    Failure failure, {
    Key? key,
    String? title,
    VoidCallback? onRetry,
  }) {
    final showRetry = failure is RecoverableFailure && onRetry != null;
    return ErrorStateView(
      key: key,
      message: failure.message,
      title: title ?? _titleFor(failure),
      onRetry: showRetry ? onRetry : null,
      icon: switch (failure) {
        RecoverableFailure() => Icons.wifi_off_rounded,
        UnavailableFailure() => Icons.cloud_off_rounded,
        UnexpectedFailure() => Icons.error_outline,
      },
    );
  }

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final IconData icon;

  static String _titleFor(Failure failure) => switch (failure) {
    RecoverableFailure() => 'Connection problem',
    UnavailableFailure() => 'Currently unavailable',
    UnexpectedFailure() => 'Something went wrong',
  };

  @override
  Widget build(BuildContext context) {
    return StatusView(
      icon: icon,
      title: title,
      message: message,
      tone: StatusTone.danger,
      action: onRetry != null
          ? AppButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              variant: AppButtonVariant.secondary,
            )
          : null,
    );
  }
}
