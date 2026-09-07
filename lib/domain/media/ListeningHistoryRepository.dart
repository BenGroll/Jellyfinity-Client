import 'package:equatable/equatable.dart';

import '../../core/result/result.dart';
import 'ListeningContext.dart';
import 'ListeningHistoryEntry.dart';

/// A single qualifying play, handed to [ListeningHistoryRepository.record].
///
/// "Qualifying" is decided before this is built — `PlaybackCubit` records
/// a play only once the user has genuinely listened to the track (ADR-0025
/// defines the threshold), never when it was queued or skimmed past.
class ListeningPlay extends Equatable {
  const ListeningPlay({required this.context, required this.playedAt});

  final ListeningContext context;

  /// When the play happened (UTC).
  final DateTime playedAt;

  @override
  List<Object?> get props => [context, playedAt];
}

/// Records and reads back what this profile has listened to (ADR-0025).
///
/// A local convenience only: it is never transmitted anywhere and it is
/// not analytics. Recording is a purely local write, so it behaves
/// identically with the server up or down — a downloaded album played on a
/// plane is listening.
///
/// Every method is scoped to the signed-in profile the same way downloads
/// are (ADR-0023): one profile's history never appears under another's,
/// and with nobody signed in a read is empty and [record] is a no-op.
///
/// The record is **bounded** — `CONTEXT.md` forbids unbounded local
/// growth. The implementation keeps at most a fixed number of the
/// most-recently-played contexts per profile and evicts the oldest.
abstract class ListeningHistoryRepository {
  /// Folds [play] into this profile's history: it bumps the matching
  /// [ListeningContext]'s entry when one exists, or adds a new entry, and
  /// evicts the oldest entry if that puts the profile over the cap.
  Future<Result<void>> record(ListeningPlay play);

  /// This profile's history, most recently played first, capped at
  /// [limit].
  Future<Result<List<ListeningHistoryEntry>>> recent({int limit});
}
