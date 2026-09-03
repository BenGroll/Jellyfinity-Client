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

/// Describes one item that could not be resolved as part of a [Partial]
/// result.
class UnavailableItem extends Equatable {
  const UnavailableItem({required this.id, required this.reason});

  /// An identifier for the missing item, meaningful to the caller (e.g. a
  /// Jellyfin item id). Not necessarily presentable to the user as-is.
  final String id;

  /// A short, user-presentable or log-presentable reason. Must never
  /// contain credentials, tokens, or other sensitive data.
  final String reason;

  @override
  List<Object?> get props => [id, reason];
}
