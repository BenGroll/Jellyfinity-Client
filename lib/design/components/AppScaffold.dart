import 'package:flutter/material.dart';

import '../../app/platform/television_mode.dart';
import '../theme/theme_context.dart';
import 'ArtworkBackdropScope.dart';

/// The standard page frame.
///
/// Every top-level screen uses this instead of a bare [Scaffold] so the
/// background, safe-area handling, title treatment, and default body inset
/// are identical across features. [body] is laid out inside the horizontal
/// [AppSpacing.md] gutter by default; pass `padded: false` for
/// edge-to-edge content (full-bleed artwork, lists that manage their own
/// insets).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions = const [],
    this.leading,
    this.bottomBar,
    this.floatingActionButton,
    this.padded = true,
    this.drawer,
    this.background,
    this.scaffoldKey,
  });

  final Widget body;

  final GlobalKey<ScaffoldState>? scaffoldKey;

  /// Optional page-specific background, painted behind the body and app bar.
  final Widget? background;
  final String? title;
  final List<Widget> actions;
  final Widget? leading;

  /// Persistent bottom area — the shell's navigation bar, and later the
  /// mini-player, live here.
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool padded;

  /// The app sidebar (`AppSidebar`), when this scaffold should offer one.
  /// Flutter's `Scaffold` already gives a `Drawer` both the default
  /// left-edge swipe and (when no custom `leading` is set) an automatic
  /// menu button — no bespoke gesture code needed.
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final television = TelevisionModeScope.of(context);

    final scaffold = Scaffold(
      key: scaffoldKey,
      backgroundColor:
          background == null && ArtworkBackdropScope.of(context) == null
          ? t.colors.background
          : Colors.transparent,
      appBar: title == null && actions.isEmpty && leading == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              centerTitle: false,
              leading: leading,
              titleSpacing: t.spacing.md,
              title: title == null
                  ? null
                  : Text(
                      title!,
                      style: t.typography.headlineLarge.copyWith(
                        color: t.colors.textPrimary,
                      ),
                    ),
              actions: [
                ...actions,
                SizedBox(width: t.spacing.xs),
              ],
            ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      drawer: drawer,
      body: SafeArea(
        top: false,
        minimum: television
            ? EdgeInsets.fromLTRB(
                t.spacing.md,
                t.spacing.sm,
                t.spacing.md,
                t.spacing.md,
              )
            : EdgeInsets.zero,
        child: Padding(
          padding: padded
              ? EdgeInsets.symmetric(horizontal: t.spacing.md)
              : EdgeInsets.zero,
          child: body,
        ),
      ),
    );
    return background == null
        ? scaffold
        : Stack(fit: StackFit.expand, children: [background!, scaffold]);
  }
}
