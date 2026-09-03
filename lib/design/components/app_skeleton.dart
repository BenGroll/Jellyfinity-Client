import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// A single shimmering placeholder block.
///
/// This is the primitive the "render the known structure before the data
/// arrives" rule in `PHILOSOPHY.md` §2 is built from: a screen lays out
/// [AppSkeleton]s in the same shape as its real content instead of showing
/// a centered spinner. [AppSkeletonList] is the common list case.
///
/// The shimmer respects [MediaQuery.disableAnimationsOf] so it holds still
/// when the OS "reduce motion" setting is on.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  /// A circular skeleton (avatars, round buttons).
  const AppSkeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      borderRadius = const BorderRadius.all(Radius.circular(999));

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = widget.borderRadius ?? context.radii.smBorder;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (reduceMotion) {
      return _box(radius, colors.skeletonBase);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final position = _controller.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(position - 1, 0),
              end: Alignment(position + 1, 0),
              colors: [
                colors.skeletonBase,
                colors.skeletonHighlight,
                colors.skeletonBase,
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: _box(radius, colors.skeletonBase),
        );
      },
    );
  }

  Widget _box(BorderRadius radius, Color color) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: color, borderRadius: radius),
    );
  }
}

/// A column of row-shaped skeletons, for list/feed loading states.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.itemCount = 6, this.itemHeight = 56});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < itemCount; i++)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: Row(
              children: [
                AppSkeleton.circle(size: itemHeight - spacing.xs),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppSkeleton(height: 14),
                      SizedBox(height: spacing.xs),
                      const AppSkeleton(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
