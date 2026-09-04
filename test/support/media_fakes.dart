import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/infrastructure/persistence/media/media_cache_store.dart';

/// An in-memory [MediaCacheStore] that behaves like the real one but
/// needs no database, and remembers what it was asked to do.
///
/// The Drift implementation is covered by its own test; everything above
/// it only cares that a page is saved and can come back, so the fake
/// keeps those tests about the layer under test.
class RecordingMediaCacheStore implements MediaCacheStore {
  final Map<String, MediaItem> _items = {};
  final Map<String, List<_Entry>> _collections = {};

  /// The collection keys [savePage] has been called with, in order.
  final List<String> savedPages = [];

  /// Server ids passed to [clearServer].
  final List<String> clearedServers = [];

  @override
  Future<void> savePage(String collectionKey, Page<MediaItem> page) async {
    savedPages.add(collectionKey);
    String? serverId;
    var position = page.startIndex;
    final entries = <_Entry>[];

    for (final item in page.items) {
      serverId ??= item.id.serverId;
      _items[item.id.key] = item;
      entries.add(_Entry(position: position++, itemId: item.id.itemId));
    }
    for (final missing in page.unavailable) {
      entries.add(
        _Entry(
          position: position++,
          itemId: missing.id,
          reason: missing.reason,
        ),
      );
    }
    if (serverId == null) return;

    final key = _key(serverId, collectionKey);
    final existing = _collections[key] ?? <_Entry>[];
    existing
      ..removeWhere(
        (e) => e.position >= page.startIndex && e.position < position,
      )
      ..removeWhere((e) => e.position >= page.totalCount)
      ..addAll(entries)
      ..sort((a, b) => a.position.compareTo(b.position));
    _collections[key] = existing;
  }

  @override
  Future<Page<T>?> readPage<T extends MediaItem>(
    String serverId,
    String collectionKey,
    PageRequest request,
  ) async {
    final all = _collections[_key(serverId, collectionKey)];
    if (all == null) return null;

    final window = all
        .where(
          (e) =>
              e.position >= request.startIndex &&
              e.position < request.startIndex + request.limit,
        )
        .toList();
    if (window.isEmpty) return null;

    final available = <T>[];
    final unavailable = <UnavailableItem>[];
    for (final entry in window) {
      final reason = entry.reason;
      if (reason != null) {
        unavailable.add(UnavailableItem(id: entry.itemId, reason: reason));
        continue;
      }
      final item =
          _items[MediaId(serverId: serverId, itemId: entry.itemId).key];
      if (item is T) {
        available.add(_offline(item) as T);
      } else {
        unavailable.add(
          UnavailableItem(
            id: entry.itemId,
            reason: 'This item is not saved on this device.',
          ),
        );
      }
    }

    return Page<T>(
      content: Partial(available: available, unavailable: unavailable),
      startIndex: request.startIndex,
      totalCount: all.length,
      source: PageSource.cache,
    );
  }

  @override
  Future<void> saveItem(MediaItem item) async {
    if (!_cachedKinds.contains(item.kind)) return;
    _items[item.id.key] = item;
  }

  @override
  Future<MediaItem?> readItem(MediaId id) async {
    final item = _items[id.key];
    return item == null ? null : _offline(item);
  }

  @override
  Future<void> clearServer(String serverId) async {
    clearedServers.add(serverId);
    _items.removeWhere((_, item) => item.id.serverId == serverId);
    _collections.removeWhere((key, _) => key.startsWith('$serverId|'));
  }

  static const _cachedKinds = {
    MediaKind.artist,
    MediaKind.album,
    MediaKind.track,
    MediaKind.playlist,
  };

  static String _key(String serverId, String collectionKey) =>
      '$serverId|$collectionKey';

  /// The real store hands cached media back as unreachable; anything
  /// built on top of it has to cope with that, so the fake does it too.
  static MediaItem _offline(MediaItem item) => switch (item) {
    Artist() => Artist(
      id: item.id,
      name: item.name,
      availability: MediaAvailability.remoteUnavailable,
      image: item.image,
    ),
    Album() => Album(
      id: item.id,
      name: item.name,
      artists: item.artists,
      productionYear: item.productionYear,
      duration: item.duration,
      trackCount: item.trackCount,
      availability: MediaAvailability.remoteUnavailable,
      image: item.image,
    ),
    Track() => Track(
      id: item.id,
      name: item.name,
      artists: item.artists,
      albumId: item.albumId,
      albumName: item.albumName,
      trackNumber: item.trackNumber,
      discNumber: item.discNumber,
      duration: item.duration,
      availability: MediaAvailability.remoteUnavailable,
      image: item.image,
    ),
    Playlist() => Playlist(
      id: item.id,
      name: item.name,
      itemCount: item.itemCount,
      duration: item.duration,
      availability: MediaAvailability.remoteUnavailable,
      image: item.image,
    ),
    _ => item,
  };
}

class _Entry {
  _Entry({required this.position, required this.itemId, this.reason});

  final int position;
  final String itemId;
  final String? reason;
}

/// An [ArtworkResolver] a widget test can steer.
///
/// [available] false stands for the two real cases where an image has no
/// address: signed out, and an image belonging to a saved server that is
/// not the active one.
class FakeArtworkResolver implements ArtworkResolver {
  FakeArtworkResolver({this.available = true});

  final bool available;

  /// Every ([image], width) pair the widget asked to resolve.
  final List<({MediaImage image, int? maxWidth})> requests = [];

  @override
  Uri? imageUrl(MediaImage image, {int? maxWidth, int? maxHeight}) {
    requests.add((image: image, maxWidth: maxWidth));
    if (!available) return null;
    return Uri.parse(
      'https://media.example.com/Items/${image.itemId.itemId}/Images/Primary'
      '?tag=${image.tag}&maxWidth=$maxWidth',
    );
  }
}
