import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/result/result.dart';
import '../../../../domain/connectivity/OfflineMode.dart';
import '../../../../domain/media/media.dart';
import '../offline_reload.dart';

/// "Related artists" on the artist page and "Similar albums" on the album
/// page (v0.3.5, ADR-0029) — a bounded strip drawn straight from the
/// server's own similarity endpoint.
///
/// Modelled on [ArtistStatsCubit]: a secondary section on a detail screen
/// that costs its own query, is read live only, and quietly disappears
/// when there is nothing to show. A server that offers no suggestions —
/// or cannot be reached, or predates the endpoint — is a normal outcome,
/// not a failure, so this state carries no `failure`: the section is
/// either loading, present with [items], or [isAbsent].
class RelatedMediaState<T extends MediaItem> extends Equatable {
  const RelatedMediaState({
    this.items = const [],
    this.isLoading = false,
    this.hasLoaded = false,
  });

  final List<T> items;
  final bool isLoading;

  /// A read has completed at least once. Tells "not asked yet" apart from
  /// "asked, and the server had nothing".
  final bool hasLoaded;

  /// Loaded, with nothing to show — the section renders nothing at all
  /// rather than an empty box.
  bool get isAbsent => hasLoaded && items.isEmpty;

  @override
  List<Object?> get props => [items, isLoading, hasLoaded];
}

/// Loads one detail screen's "you might also like" strip.
abstract class RelatedMediaCubit<T extends MediaItem>
    extends Cubit<RelatedMediaState<T>>
    with OfflineReload<RelatedMediaState<T>> {
  RelatedMediaCubit(OfflineMode? offlineMode) : super(RelatedMediaState<T>()) {
    bindOfflineReload(offlineMode);
  }

  /// How many suggestions to ask for — a strip, not a list.
  static const int limit = 12;

  Future<Result<List<T>>> read(MediaId id);

  MediaId? _id;

  /// Bumped on every [open]; a slow read whose generation is stale drops
  /// its result instead of overwriting the newer one.
  int _generation = 0;

  /// Coming back online is the chance to fill a strip that was empty
  /// because the server could not be reached.
  @override
  void onOfflineChanged() {
    final id = _id;
    if (id == null) return;
    _id = null;
    open(id);
  }

  Future<void> open(MediaId id) async {
    if (id == _id) return;
    _id = id;
    final generation = ++_generation;
    emit(RelatedMediaState<T>(isLoading: true));

    final result = await read(id);
    if (isClosed || generation != _generation) return;

    switch (result) {
      case Ok<List<T>>(:final value):
        emit(RelatedMediaState<T>(items: value, hasLoaded: true));
      // A failure here is not shown — the strip is a bonus, and the detail
      // screen it sits under already rendered. It just stays absent.
      case Err<List<T>>():
        emit(RelatedMediaState<T>(hasLoaded: true));
    }
  }
}

/// Artists the server considers related to the one on screen.
@injectable
class RelatedArtistsCubit extends RelatedMediaCubit<Artist> {
  RelatedArtistsCubit(this._music, OfflineMode offlineMode)
    : super(offlineMode);

  final MusicLibraryRepository _music;

  @override
  Future<Result<List<Artist>>> read(MediaId id) =>
      _music.relatedArtists(id, limit: RelatedMediaCubit.limit);
}

/// Albums the server considers similar to the one on screen.
@injectable
class SimilarAlbumsCubit extends RelatedMediaCubit<Album> {
  SimilarAlbumsCubit(this._music, OfflineMode offlineMode) : super(offlineMode);

  final MusicLibraryRepository _music;

  @override
  Future<Result<List<Album>>> read(MediaId id) =>
      _music.similarAlbums(id, limit: RelatedMediaCubit.limit);
}
