import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// A bump counter that ticks every time the signed-in profile favorites or
/// un-favorites something (v0.3.4).
///
/// Favorites can be toggled from the Artist, Album and Now Playing screens
/// (ADR-0019), none of which the Favorites destination or its Home section
/// can see. Rather than a route observer or a lifecycle hook, those views
/// listen to this and re-read when it changes — the same shape Home
/// already uses to refresh "Recently played" off `PlaybackCubit`
/// (ADR-0026).
///
/// It carries no data, only the fact that something changed; a listener
/// reacts by refreshing its own list.
///
/// A registered `@lazySingleton` since v0.4.3 (ADR-0033): `PendingFavorites
/// Sync` bumps it too, from outside the widget tree, once a reconnect has
/// replayed one or more offline favorites — the same instance `Jellyfinity
/// App` puts in the tree, resolved through `getIt` for both rather than
/// created inline as it was when only presentation code ever touched it.
@lazySingleton
class FavoritesRevisionCubit extends Cubit<int> {
  FavoritesRevisionCubit() : super(0);

  /// Records that a favorite was added or removed.
  void bump() => emit(state + 1);
}
