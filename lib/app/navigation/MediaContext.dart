import 'package:equatable/equatable.dart';

import 'MediaType.dart';

/// One pill in the media-pills navigation mode: a label over one or more
/// [MediaType]s.
///
/// `types` is already a set rather than a single value so combining media
/// types into one pill (e.g. a future "Movies + TV" or "Music +
/// Audiobooks") is additive later, not a reshape. v0.0.10 seeds exactly one
/// context (Music) and ships no "combine" UI — there is nothing to combine
/// yet — but nothing above this model has to change when there is.
class MediaContext extends Equatable {
  const MediaContext({
    required this.id,
    required this.label,
    required this.types,
  });

  final String id;
  final String label;
  final Set<MediaType> types;

  static final music = MediaContext(
    id: 'music',
    label: MediaType.music.label,
    types: const {MediaType.music},
  );

  @override
  List<Object?> get props => [id, label, types];
}
