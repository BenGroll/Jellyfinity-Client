import 'package:equatable/equatable.dart';

import '../media/MediaId.dart';
import '../media/MediaImage.dart';
import '../playback/QueueEntry.dart';

/// One entry of a queue as it crosses between two devices.
///
/// This is a separate type from [QueueEntry] for one reason, and it is
/// the arc's sharpest security invariant: **transfer only
/// server-addressable music metadata and identifiers**. Never
/// credentials, never authenticated stream URLs, never download paths,
/// never audio.
///
/// A [QueueEntry] is safe today — it holds display fields and ids — but
/// "safe today" is not a contract. Sending it directly would mean every
/// future field added to the local queue is silently published to another
/// device by whoever adds it. A distinct wire model makes the addition
/// deliberate: a new field only crosses the network if someone puts it
/// here.
///
/// Everything below is an id or something the target could equally have
/// read from the server itself, which is also why the target does not
/// need to trust it for playback. It resolves each [id] independently and
/// picks its own local download or server stream, applying its own
/// quality, normalization and crossfade settings (ADR-0015, ADR-0016,
/// ADR-0017). The metadata is here so a target can draw the queue
/// immediately, not so it can play from it.
///
/// Notably absent: `availability` and `failureMessage`. Both are facts
/// about the *source's* device — a track the phone could not decode may
/// play perfectly on the desktop — and copying them would carry one
/// device's bad luck onto another. The target discovers its own
/// availability.
class RemoteQueueEntry extends Equatable {
  const RemoteQueueEntry({
    required this.id,
    required this.title,
    this.artist,
    this.albumId,
    this.albumName,
    this.duration,
    this.image,
  });

  /// The projection of a local queue entry, keeping only what is safe and
  /// useful to send.
  factory RemoteQueueEntry.fromQueueEntry(QueueEntry entry) => RemoteQueueEntry(
    id: entry.id,
    title: entry.title,
    artist: entry.artist,
    albumId: entry.albumId,
    albumName: entry.albumName,
    duration: entry.duration,
    image: entry.image,
  );

  /// The item, on the server both devices share. The one field a target
  /// genuinely needs; the rest is so it can render before it resolves.
  final MediaId id;

  final String title;
  final String? artist;
  final MediaId? albumId;
  final String? albumName;
  final Duration? duration;

  /// An artwork *pointer* — owning item id, role and content tag. Not a
  /// URL and not image data: the target builds its own address against
  /// its own session, exactly as `ArtworkResolver` already does locally.
  final MediaImage? image;

  /// The local queue entry a receiving device builds from this.
  ///
  /// Availability comes back at its default: the target has not tried to
  /// play this yet, and inheriting the source's verdict would be a guess
  /// about a different device.
  QueueEntry toQueueEntry() => QueueEntry(
    id: id,
    title: title,
    artist: artist,
    albumId: albumId,
    albumName: albumName,
    duration: duration,
    image: image,
  );

  /// The wire form.
  ///
  /// Encoding lives on the model rather than in a separate codec because
  /// the safety rule this class exists for is a rule about *which fields
  /// cross the network*. Keeping the field list and the encoding in one
  /// file is what makes "did we just publish a download path?" a question
  /// with one place to look.
  ///
  /// Ids travel as `MediaId.key`, which already carries the server half —
  /// so an entry decoded against a different server does not silently
  /// resolve to whatever item happens to share its item id.
  Map<String, Object?> toJson() => {
    'id': id.key,
    'title': title,
    if (artist != null) 'artist': artist,
    if (albumId != null) 'albumId': albumId!.key,
    if (albumName != null) 'albumName': albumName,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (image != null)
      'image': {
        'itemId': image!.itemId.key,
        'kind': image!.kind.name,
        'tag': image!.tag,
        if (image!.aspectRatio != null) 'aspectRatio': image!.aspectRatio,
      },
  };

  /// Reverses [toJson]. Returns `null` for anything missing an id or a
  /// title — an entry that cannot be identified or drawn is not an entry
  /// — and drops an unreadable image rather than the whole row, because a
  /// queue row without artwork is still a queue row.
  static RemoteQueueEntry? tryDecode(Object? value) {
    if (value is! Map) return null;
    final id = _mediaId(value['id']);
    final title = _string(value['title']);
    if (id == null || title == null) return null;
    final durationMs = value['durationMs'];
    return RemoteQueueEntry(
      id: id,
      title: title,
      artist: _string(value['artist']),
      albumId: _mediaId(value['albumId']),
      albumName: _string(value['albumName']),
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
      image: _decodeImage(value['image']),
    );
  }

  static MediaImage? _decodeImage(Object? value) {
    if (value is! Map) return null;
    final itemId = _mediaId(value['itemId']);
    final tag = _string(value['tag']);
    final kindName = _string(value['kind']);
    if (itemId == null || tag == null || kindName == null) return null;
    MediaImageKind? kind;
    for (final candidate in MediaImageKind.values) {
      if (candidate.name == kindName) kind = candidate;
    }
    if (kind == null) return null;
    final aspectRatio = value['aspectRatio'];
    return MediaImage(
      itemId: itemId,
      kind: kind,
      tag: tag,
      aspectRatio: aspectRatio is num ? aspectRatio.toDouble() : null,
    );
  }

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static MediaId? _mediaId(Object? value) {
    final key = _string(value);
    return key == null ? null : MediaId.tryParse(key);
  }

  @override
  List<Object?> get props => [
    id,
    title,
    artist,
    albumId,
    albumName,
    duration,
    image,
  ];
}
