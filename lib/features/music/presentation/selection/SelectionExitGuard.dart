import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Makes a screen's back gesture, Escape key, and TV-remote back button
/// leave selection mode instead of navigating away while [active] is true
/// (v0.7.0) — the same `PopScope` + `CallbackShortcuts` pattern
/// `AppShell` already uses to keep search's back button from leaving the
/// shell mid-search.
///
/// `CallbackShortcuts` only sees a key event when a descendant already
/// holds focus (its own doc comment says so) — true by construction for
/// `AppShell`'s search field, which autofocuses itself, but not for a
/// screen entering selection mode from an ordinary tap or app-bar press.
/// So this widget claims focus on itself the moment [active] turns true,
/// which is enough for Escape/back to resolve immediately, and does not
/// stop a keyboard or D-pad user from then moving focus to a specific row
/// — any descendant holding focus still satisfies `CallbackShortcuts`.
class SelectionExitGuard extends StatefulWidget {
  const SelectionExitGuard({
    super.key,
    required this.active,
    required this.onExit,
    required this.child,
  });

  final bool active;
  final VoidCallback onExit;
  final Widget child;

  @override
  State<SelectionExitGuard> createState() => _SelectionExitGuardState();
}

class _SelectionExitGuardState extends State<SelectionExitGuard> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'SelectionExitGuard');

  @override
  void didUpdateWidget(SelectionExitGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.active) widget.onExit();
      },
      child: CallbackShortcuts(
        bindings: {
          if (widget.active)
            const SingleActivator(LogicalKeyboardKey.escape): widget.onExit,
          if (widget.active)
            const SingleActivator(LogicalKeyboardKey.goBack): widget.onExit,
          if (widget.active)
            const SingleActivator(LogicalKeyboardKey.browserBack):
                widget.onExit,
        },
        child: Focus(
          focusNode: _focusNode,
          skipTraversal: true,
          child: widget.child,
        ),
      ),
    );
  }
}
