import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'MediaContext.dart';

class MediaScopeState extends Equatable {
  const MediaScopeState({required this.contexts, required this.activeId});

  final List<MediaContext> contexts;
  final String activeId;

  MediaContext get active => contexts.firstWhere(
    (c) => c.id == activeId,
    orElse: () => contexts.first,
  );

  @override
  List<Object?> get props => [contexts, activeId];
}

/// Which media-type pill is active in the "media pills" navigation mode.
///
/// Deliberately **not** persisted, unlike `SettingsCubit`'s
/// `NavigationMode`: this is a lightweight browsing context for the current
/// session, not a durable preference. Seeded with the one context that
/// exists today (Music); the same list is where a future "Combine" sheet
/// would append user-built contexts once a second `MediaType` ships.
@injectable
class MediaScopeCubit extends Cubit<MediaScopeState> {
  MediaScopeCubit()
    : super(
        MediaScopeState(
          contexts: [MediaContext.music],
          activeId: MediaContext.music.id,
        ),
      );

  void select(String contextId) {
    if (contextId == state.activeId) return;
    if (!state.contexts.any((c) => c.id == contextId)) return;
    emit(MediaScopeState(contexts: state.contexts, activeId: contextId));
  }
}
