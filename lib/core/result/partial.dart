import 'package:equatable/equatable.dart';

/// One item that was expected but could not be produced as part of an
/// otherwise-successful, larger result.
///
/// Example: loading a 12-track album where 1 track is unavailable. The
/// album load still succeeds (an [Ok] result carrying a [Partial]); the
/// 11 usable tracks are in [Partial.available] and the missing one is
/// recorded in [Partial.unavailable] so the UI can show it, visibly
/// marked, rather than hiding it or failing the whole request.
class Partial<T> extends Equatable {
  const Partial({required this.available, this.unavailable = const []});

  /// The successfully resolved items.
  final List<T> available;

  /// Items that were expected but could not be resolved, with a reason
  /// for each.
  final List<UnavailableItem> unavailable;

  bool get hasUnavailable => unavailable.isNotEmpty;

  @override
  List<Object?> get props => [available, unavailable];
}

/// The [UnavailableItem.reason] a source uses for a collection member that
/// exists but is not on this device (v0.2.3).
///
/// A screen showing a partially-downloaded album or artist offline renders
/// every entry carrying this reason as one "N not available offline" line,
/// rather than a row each — the count is the honest fact, the individual
/// rows are not (their titles were never downloaded).
const String offlineUnavailableReason = 'Not available offline';

/// Describes one item that could not be resolved as part of a [Partial]
/// result.
class UnavailableItem extends Equatable {
  const UnavailableItem({
    required this.id,
    required this.reason,
    this.position,
  });

  /// An identifier for the missing item, meaningful to the caller (e.g. a
  /// Jellyfin item id). Not necessarily presentable to the user as-is.
  final String id;

  /// A short, user-presentable or log-presentable reason. Must never
  /// contain credentials, tokens, or other sensitive data.
  final String reason;

  /// Where this entry sat in the collection it came from — a zero-based
  /// index into the whole collection, not into the window (v0.4.2).
  ///
  /// [Partial] separates the rows a source could read from the rows it
  /// could not, which loses how the two were interleaved. That is
  /// harmless for a grid of covers and wrong for an ordered list the user
  /// built: a playlist's fourth entry is its fourth entry whether or not
  /// Jellyfinity can read it, and Jellyfin's own move endpoint counts it.
  /// A source that knows the slot says so here; `null` where it genuinely
  /// does not (a gap standing in for a member whose file never
  /// downloaded, say).
  final int? position;

  @override
  List<Object?> get props => [id, reason, position];
}
