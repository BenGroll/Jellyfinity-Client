import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/session/SessionCubit.dart';
import '../../../../app/session/SessionState.dart';
import '../../../../domain/media/MediaId.dart';
import 'TrackSelectionState.dart';

/// Bulk selection of songs on one screen (v0.7.0) — the state behind
/// multi-select in every song list that offers "add to playlist" on more
/// than one row at once.
///
/// Built directly from the already-provided [SessionCubit]
/// (`TrackSelectionCubit(context.read<SessionCubit>())`) rather than
/// through `getIt`: its one dependency is already in every screen's
/// context, so it needs no factory registration. A fresh instance is
/// created by each screen's own `BlocProvider`, so selection is scoped to
/// the active page for free — it lives and dies with the widget that
/// opened it, per the spec's "scoped to the active page" requirement. It
/// still takes [SessionCubit] so a profile or server switch clears an
/// in-progress selection even if the page that started it happens to stay
/// open across the switch, mirroring `DownloadsCubit`'s per-profile reset.
class TrackSelectionCubit extends Cubit<TrackSelectionState> {
  TrackSelectionCubit(this._session)
    : _activeAccountId = _session.state.session?.account.id,
      super(const TrackSelectionState()) {
    _sessionSub = _session.stream.listen(_onSessionChanged);
  }

  final SessionCubit _session;
  String? _activeAccountId;
  late final StreamSubscription<SessionState> _sessionSub;

  void _onSessionChanged(SessionState next) {
    final accountId = next.session?.account.id;
    if (accountId == _activeAccountId) return;
    _activeAccountId = accountId;
    if (state.active || state.selected.isNotEmpty) {
      emit(const TrackSelectionState());
    }
  }

  /// Turns selection mode on with nothing checked — the entry point a
  /// pointer, keyboard, or D-pad user reaches without a long-press
  /// gesture.
  void enter() {
    if (state.active) return;
    emit(state.copyWith(active: true));
  }

  /// Checks or unchecks [id]. Also turns selection mode on if it was off
  /// — a touch long-press on a row both starts selection and selects that
  /// row in one gesture.
  void toggle(MediaId id) {
    final selected = {...state.selected};
    if (!selected.remove(id)) selected.add(id);
    emit(TrackSelectionState(active: true, selected: selected));
  }

  /// Leaves selection mode and drops every check — Cancel, and the
  /// D-pad-safe back/escape handling `SelectionExitGuard` wires up.
  void exit() {
    if (!state.active && state.selected.isEmpty) return;
    emit(const TrackSelectionState());
  }

  /// Narrows the current selection to exactly [ids], staying in selection
  /// mode. Used after a failed bulk add drops rows that turned out to be
  /// unavailable, so a retry does not resend ids the server was never
  /// asked about.
  void retainOnly(Set<MediaId> ids) {
    emit(TrackSelectionState(active: true, selected: ids));
  }

  @override
  Future<void> close() {
    unawaited(_sessionSub.cancel());
    return super.close();
  }
}
