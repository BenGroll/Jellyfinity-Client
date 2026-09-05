import '../../core/result/result.dart';
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
  Future<Result<void>> setFavorite(MediaId id, {required bool favorite});
}
