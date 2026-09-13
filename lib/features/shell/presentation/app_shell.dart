import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/platform/television_focus_traversal.dart';
import '../../../app/platform/television_mode.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/router/route_paths.dart';
import '../../../design/design.dart';
import '../../music/presentation/search/InlineMusicSearch.dart';
import '../../playback/presentation/MiniPlayer.dart';
import 'AppSidebar.dart';
import 'HomeLibraryHeader.dart';
import 'ShellDestination.dart';
import 'TelevisionNavigationRail.dart';

/// The persistent frame around every authenticated screen: a shared header
/// (search + media-type pills), a body that swaps per section, a
/// mini-player, and a bottom navigation bar.
///
/// Backed by go_router's [StatefulNavigationShell], so each section keeps
/// its own navigation stack and scroll position when the user switches
/// tabs. The bottom bar is only rendered once there are at least two
/// sections — with Home alone (v0.0.3) the shell is just the page, but the
/// structure is already in place.
///
/// Search is inline (ADR-0014), not a pushed page: activating it swaps the
/// header out for [InlineMusicSearch] in place, so the bottom nav and
/// mini-player stay put underneath it — this is presentation state local
/// to the shell, not a route.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _searching = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _televisionContentKey = GlobalKey();
  final _televisionRailFocusNode = FocusNode(
    debugLabel: 'TV current destination',
  );
  final _televisionSearchFocusNode = FocusNode(debugLabel: 'TV shell search');
  int _branchTransition = 0;
  int _branchDirection = 1;

  void _startSearch() => setState(() => _searching = true);
  void _stopSearch() => setState(() => _searching = false);
  void _openMenu() => _scaffoldKey.currentState?.openDrawer();
  void _openNowPlaying() => context.pushNamed(RouteNames.nowPlaying);

  void _focusTelevisionNavigation() => _televisionRailFocusNode.requestFocus();

  bool _isAtTelevisionContentEdge(
    FocusNode node,
    TraversalDirection direction,
  ) {
    final box = _televisionContentKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return false;
    final origin = box.localToGlobal(Offset.zero);
    return switch (direction) {
      TraversalDirection.up => node.rect.top <= origin.dy + 60,
      TraversalDirection.left => node.rect.left <= origin.dx + 48,
      TraversalDirection.down || TraversalDirection.right => false,
    };
  }

  void _goToBranch(int index) {
    final previousIndex = widget.navigationShell.currentIndex;
    if (index != previousIndex) {
      setState(() {
        _branchDirection = index > previousIndex ? 1 : -1;
        _branchTransition++;
      });
    }
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab again pops it back to its root.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  void dispose() {
    _televisionRailFocusNode.dispose();
    _televisionSearchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showBar = shellDestinations.length > 1;
    final location = GoRouterState.of(context).uri.path;
    final isDetail =
        location.contains('/artist/') ||
        location.contains('/album/') ||
        location.contains('/playlist/');

    final television = TelevisionModeScope.of(context);
    final hasNowPlaying = context.select<PlaybackCubit, bool>(
      (playback) => playback.state.currentEntry != null,
    );
    final mainContent = Column(
      children: [
        if (!_searching && !isDetail)
          HomeLibraryHeader(
            onSearchTap: _startSearch,
            onMenuTap: _openMenu,
            onNavigationTap: television ? _focusTelevisionNavigation : null,
            searchFocusNode: television ? _televisionSearchFocusNode : null,
          ),
        Expanded(
          child: _searching
              ? InlineMusicSearch(onClose: _stopSearch)
              : widget.navigationShell,
        ),
      ],
    );

    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searching) _stopSearch();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _startSearch,
          if (_searching)
            const SingleActivator(LogicalKeyboardKey.escape): _stopSearch,
          if (television)
            const SingleActivator(LogicalKeyboardKey.contextMenu): _openMenu,
          if (television)
            if (_searching)
              const SingleActivator(LogicalKeyboardKey.browserBack):
                  _stopSearch,
          if (_searching)
            const SingleActivator(LogicalKeyboardKey.goBack): _stopSearch,
          const SingleActivator(LogicalKeyboardKey.mediaTopMenu): _openMenu,
          if (television)
            const SingleActivator(LogicalKeyboardKey.gameButtonStart):
                _openMenu,
        },
        child: FocusScope(
          autofocus: true,
          child: AppScaffold(
            scaffoldKey: _scaffoldKey,
            padded: false,
            drawer: const AppSidebar(),
            body: SafeArea(
              bottom: false,
              child: television
                  ? Row(
                      key: const Key('television-navigation'),
                      children: [
                        TelevisionNavigationRail(
                          currentIndex: widget.navigationShell.currentIndex,
                          onSelected: _goToBranch,
                          onMenu: _openMenu,
                          onSearch: _startSearch,
                          onNowPlaying: _openNowPlaying,
                          currentDestinationFocusNode: _televisionRailFocusNode,
                          hasNowPlaying: hasNowPlaying,
                        ),
                        VerticalDivider(
                          width: 1,
                          color: context.tokens.colors.border,
                        ),
                        Expanded(
                          child: FocusTraversalGroup(
                            policy: _TelevisionShellFocusTraversalPolicy(
                              onTopEdge: _startSearch,
                              onLeftEdge: _focusTelevisionNavigation,
                              isAtEdge: _isAtTelevisionContentEdge,
                            ),
                            child: _TelevisionBranchTransition(
                              key: _televisionContentKey,
                              transition: _branchTransition,
                              direction: _branchDirection,
                              child: Column(
                                children: [
                                  Expanded(child: mainContent),
                                  const MiniPlayer(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : mainContent,
            ),
            bottomBar: television
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MiniPlayer(),
                      if (showBar)
                        _ShellNavigationBar(
                          onSelected: _goToBranch,
                          currentIndex: widget.navigationShell.currentIndex,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Adds the shell's two D-pad edge affordances to the smooth TV policy.
///
/// This sits around the shell's header, branch and mini-player—not around a
/// pushed detail route—so top-edge Search stays available from Home,
/// Favorites and Library without changing full-player controls.
class _TelevisionShellFocusTraversalPolicy
    extends TelevisionFocusTraversalPolicy {
  _TelevisionShellFocusTraversalPolicy({
    required this.onTopEdge,
    required this.onLeftEdge,
    required this.isAtEdge,
  });

  final VoidCallback onTopEdge;
  final VoidCallback onLeftEdge;
  final bool Function(FocusNode node, TraversalDirection direction) isAtEdge;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (isAtEdge(currentNode, direction)) {
      switch (direction) {
        case TraversalDirection.up:
          onTopEdge();
          return true;
        case TraversalDirection.left:
          onLeftEdge();
          return true;
        case TraversalDirection.down:
        case TraversalDirection.right:
          break;
      }
    }

    return super.inDirection(currentNode, direction);
  }
}

class _TelevisionBranchTransition extends StatefulWidget {
  const _TelevisionBranchTransition({
    super.key,
    required this.transition,
    required this.direction,
    required this.child,
  });

  final int transition;
  final int direction;
  final Widget child;

  @override
  State<_TelevisionBranchTransition> createState() =>
      _TelevisionBranchTransitionState();
}

class _TelevisionBranchTransitionState
    extends State<_TelevisionBranchTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant _TelevisionBranchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transition != widget.transition) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.tokens.motion;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: motion.emphasizedCurve,
    );
    final offset = Tween<Offset>(
      begin: Offset(.04 * widget.direction, 0),
      end: Offset.zero,
    ).animate(curve);

    return SlideTransition(
      position: offset,
      child: FadeTransition(opacity: curve, child: widget.child),
    );
  }
}

class _ShellNavigationBar extends StatelessWidget {
  const _ShellNavigationBar({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.colors.surface.withValues(alpha: .32),
        border: Border(top: BorderSide(color: t.colors.border)),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final d in shellDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
