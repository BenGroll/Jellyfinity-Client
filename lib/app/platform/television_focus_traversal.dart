import 'package:flutter/material.dart';

/// Focus traversal for a ten-foot interface.
///
/// Flutter makes a newly focused control visible by default, but it does so
/// immediately. On a D-pad that turns a horizontal shelf or a long list into
/// a series of jumps. Television navigation keeps the same reading-order
/// geometry while asking enclosing scroll views to animate the reveal.
class TelevisionFocusTraversalPolicy extends ReadingOrderTraversalPolicy {
  TelevisionFocusTraversalPolicy()
    : super(requestFocusCallback: _requestFocusWithMotion);

  static void _requestFocusWithMotion(
    FocusNode node, {
    ScrollPositionAlignmentPolicy? alignmentPolicy,
    double? alignment,
    Duration? duration,
    Curve? curve,
  }) {
    node.requestFocus();
    Scrollable.ensureVisible(
      node.context!,
      alignment: alignment ?? .5,
      alignmentPolicy:
          alignmentPolicy ?? ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      duration: duration ?? const Duration(milliseconds: 220),
      curve: curve ?? Curves.easeOutCubic,
    );
  }
}
