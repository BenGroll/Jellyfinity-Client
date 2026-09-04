import 'package:equatable/equatable.dart';

import '../media/MediaId.dart';

/// One source [PlaybackEngine] could not play — a bad file, an
/// unsupported codec, a stream that dropped mid-request.
///
/// Reported by index rather than raised as an exception: a failure here
/// must never take the rest of the queue down with it (`PHILOSOPHY.md`
/// §1's "one dead track" rule applies to the queue as much as to any
/// browsed list). `PlaybackCubit` marks [id] unavailable in place and
/// moves on.
class PlaybackFailure extends Equatable {
  const PlaybackFailure({
    required this.sourceIndex,
    required this.id,
    required this.message,
  });

  /// The index within the list last given to [PlaybackEngine.setSources].
  final int sourceIndex;

  final MediaId id;

  /// A short, user-presentable description.
  final String message;

  @override
  List<Object?> get props => [sourceIndex, id, message];
}
