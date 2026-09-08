import '../../core/result/result.dart';
import 'media_kind.dart';
import 'MediaId.dart';

/// Setting whether an item is one of the user's favorites.
///
/// Reading favorite state is not part of this contract: it arrives already
/// attached to an [Artist]/[Album]/[Track] whenever one is fetched (the
/// same "comes attached, not fetched separately" shape as
/// `PlaybackProgress`), so a screen already showing one of those has
/// nothing more to ask for. This contract exists for the one thing that is
/// not already there: making the change.
abstract class FavoritesRepository {
  /// Sets [id]'s favorite state on the server.
  ///
  /// [kind] is what the caller already knows — every heart button is on a
  /// concrete [Artist], [Album] or [Track]. It lets the local favorites
  /// cache (v0.3.4, ADR-0028) record the change straight away, so an
  /// offline Favorites view reflects a toggle made online without waiting
  /// for the next full sync. Omitting it still writes to the server; only
  /// the local mirror is skipped.
  Future<Result<void>> setFavorite(
    MediaId id, {
    required bool favorite,
    MediaKind? kind,
  });
}
