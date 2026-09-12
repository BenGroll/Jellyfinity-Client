import 'package:flutter/material.dart';

import '../../../design/design.dart';
import 'ShellDestination.dart';

/// Persistent primary navigation for a ten-foot, D-pad-driven interface.
///
/// The selected destination receives initial focus. Flutter's reading-order
/// traversal then moves right into the header/content and automatically keeps
/// newly focused items visible inside their scrollables.
class TelevisionNavigationRail extends StatefulWidget {
  const TelevisionNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  State<TelevisionNavigationRail> createState() =>
      _TelevisionNavigationRailState();
}

class _TelevisionNavigationRailState extends State<TelevisionNavigationRail> {
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = [
      for (final destination in shellDestinations)
        FocusNode(debugLabel: 'TV ${destination.label}'),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[widget.currentIndex].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 240,
      child: Material(
        color: t.colors.surface.withValues(alpha: .52),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spacing.sm,
            vertical: t.spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.spacing.sm,
                  t.spacing.xs,
                  t.spacing.sm,
                  t.spacing.lg,
                ),
                child: Text(
                  'Jellyfinity',
                  style: t.typography.headlineLarge.copyWith(
                    color: t.colors.textPrimary,
                  ),
                ),
              ),
              for (var index = 0; index < shellDestinations.length; index++)
                Padding(
                  padding: EdgeInsets.only(bottom: t.spacing.xs),
                  child: _TelevisionDestination(
                    destination: shellDestinations[index],
                    selected: index == widget.currentIndex,
                    autofocus: index == widget.currentIndex,
                    focusNode: _focusNodes[index],
                    onTap: () => widget.onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelevisionDestination extends StatelessWidget {
  const _TelevisionDestination({
    required this.destination,
    required this.selected,
    required this.autofocus,
    required this.focusNode,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final bool autofocus;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.colors.surfaceElevated : Colors.transparent,
        borderRadius: t.radii.mdBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('television-destination-${destination.label}'),
          autofocus: autofocus,
          focusNode: focusNode,
          onTap: onTap,
          borderRadius: t.radii.mdBorder,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.spacing.sm,
              vertical: t.spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 30,
                  color: selected ? t.colors.accent : t.colors.textSecondary,
                ),
                SizedBox(width: t.spacing.sm),
                Expanded(
                  child: Text(
                    destination.label,
                    style: t.typography.label.copyWith(
                      color: selected
                          ? t.colors.textPrimary
                          : t.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
