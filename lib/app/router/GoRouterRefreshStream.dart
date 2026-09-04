import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] into a [Listenable] so a bloc/cubit stream can drive
/// `GoRouter`'s `refreshListenable`.
///
/// This is the widely-used go_router pattern for making the router
/// re-evaluate its `redirect` whenever session state changes. It notifies
/// once immediately so the first redirect runs against current state.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<Object?> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
