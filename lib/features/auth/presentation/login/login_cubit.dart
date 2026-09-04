import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../app/session/SessionCubit.dart';
import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/session/AuthSession.dart';
import '../../../../infrastructure/jellyfin/server/JellyfinServerInfo.dart';

/// Drives the credential-entry step for one already-validated server.
///
/// The actual authentication + persistence is [SessionCubit.logIn]; this
/// cubit only owns the form's submitting/error state. On success
/// [SessionCubit] emits `signedIn` and the router moves to the shell, so
/// there is no "success" state to render here.
@injectable
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._session) : super(const LoginState.editing());

  final SessionCubit _session;

  late JellyfinServerInfo _server;

  /// Must be called once with the server the user is signing in to.
  void forServer(JellyfinServerInfo server) => _server = server;

  Future<void> submit({
    required String username,
    required String password,
  }) async {
    if (state is LoginSubmitting) return;
    if (username.trim().isEmpty || password.isEmpty) {
      emit(
        const LoginState.error(
          RecoverableFailure('Enter your username and password.'),
        ),
      );
      return;
    }

    emit(const LoginState.submitting());
    final result = await _session.logIn(
      server: _server,
      username: username.trim(),
      password: password,
    );
    if (result case Err<AuthSession>(:final failure)) {
      emit(LoginState.error(failure));
    }
  }
}

sealed class LoginState extends Equatable {
  const LoginState();

  const factory LoginState.editing() = LoginEditing;
  const factory LoginState.submitting() = LoginSubmitting;
  const factory LoginState.error(Failure failure) = LoginError;

  @override
  List<Object?> get props => [];
}

class LoginEditing extends LoginState {
  const LoginEditing();
}

class LoginSubmitting extends LoginState {
  const LoginSubmitting();
}

class LoginError extends LoginState {
  const LoginError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
