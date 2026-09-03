import '../../core/result/result.dart';
import 'media_id.dart';
import 'media_item.dart';

/// Looking up a single item when its type is not known in advance.
///
/// This is the entry point for anything that starts from an id rather
/// than from a browsing context: a deep link, a queue entry restored from
/// the database, a search result being opened. The returned [MediaItem]
/// is one of the concrete entities, so the caller can switch on
/// `kind`/type to decide where to go.
abstract class MediaMetadataRepository {
  /// The item with [id].
  ///
  /// `Err(UnavailableFailure)` when the item no longer exists or is of a
  /// type Jellyfinity does not model — both are "this link goes nowhere"
  /// from the user's point of view.
  Future<Result<MediaItem>> item(MediaId id);
}
