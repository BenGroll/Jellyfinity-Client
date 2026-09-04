import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/result/failure.dart';
import '../../../../infrastructure/jellyfin/server/JellyfinServerInfo.dart';
import '../../../../infrastructure/jellyfin/server/JellyfinServerProbe.dart';

/// Drives the "enter a server address" step: hand a raw string to
/// `JellyfinServerProbe`, surface a clear result.
@injectable
class ServerSetupCubit extends Cubit<ServerSetupState> {
  ServerSetupCubit(this._probe) : super(const ServerSetupState.initial());

  final JellyfinServerProbe _probe;

  Future<void> validate(String rawUrl) async {
    if (state is ServerSetupValidating) return;
    emit(const ServerSetupState.validating());
    final result = await _probe.validate(rawUrl);
    emit(
      result.when(ok: ServerSetupState.valid, err: ServerSetupState.invalid),
    );
  }

  /// Return to the editable state (e.g. the user edited the field after a
  /// failure).
  void reset() {
    if (state is! ServerSetupInitial) {
      emit(const ServerSetupState.initial());
    }
  }
}

sealed class ServerSetupState extends Equatable {
  const ServerSetupState();

  const factory ServerSetupState.initial() = ServerSetupInitial;
  const factory ServerSetupState.validating() = ServerSetupValidating;
  const factory ServerSetupState.valid(JellyfinServerInfo server) =
      ServerSetupValid;
  const factory ServerSetupState.invalid(Failure failure) = ServerSetupInvalid;

  @override
  List<Object?> get props => [];
}

class ServerSetupInitial extends ServerSetupState {
  const ServerSetupInitial();
}

class ServerSetupValidating extends ServerSetupState {
  const ServerSetupValidating();
}

class ServerSetupValid extends ServerSetupState {
  const ServerSetupValid(this.server);

  final JellyfinServerInfo server;

  @override
  List<Object?> get props => [server];
}

class ServerSetupInvalid extends ServerSetupState {
  const ServerSetupInvalid(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
