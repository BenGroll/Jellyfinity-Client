import 'package:equatable/equatable.dart';

import '../../../../domain/media/MediaId.dart';

/// What [TrackSelectionCubit] holds: whether selection mode is on for the
/// page it is scoped to, and which tracks are currently checked.
///
/// [active] and [selected] are tracked separately rather than inferring
/// mode from a non-empty set, so a keyboard, pointer, or D-pad user can
/// enter selection mode from a button before checking anything — deselecting
/// the last row does not silently drop them back into ordinary playback.
class TrackSelectionState extends Equatable {
  const TrackSelectionState({this.active = false, this.selected = const {}});

  final bool active;
  final Set<MediaId> selected;

  TrackSelectionState copyWith({bool? active, Set<MediaId>? selected}) =>
      TrackSelectionState(
        active: active ?? this.active,
        selected: selected ?? this.selected,
      );

  @override
  List<Object?> get props => [active, selected];
}
