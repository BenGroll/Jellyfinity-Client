import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/session/SessionCubit.dart';
import '../../../../app/session/SessionState.dart';
import '../../../../app/session/session_status.dart';
import '../../../../design/design.dart';
import '../../../../infrastructure/jellyfin/server/JellyfinServerInfo.dart';
import '../widgets/AuthTextField.dart';
import '../widgets/InlineError.dart';
import 'login_cubit.dart';

/// Step two of connecting: enter Jellyfin credentials for a server that
/// has already been validated.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.server, this.cubit});

  final JellyfinServerInfo server;

  /// Test seam — production builds resolve the cubit from the locator.
  final LoginCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginCubit>(
      create: (_) => (cubit ?? getIt<LoginCubit>())..forServer(server),
      // Once signed in (first login or "add another account"), leave the
      // onboarding stack for the shell. The router's redirect also gates
      // this, but a pushed route needs an explicit move.
      child: BlocListener<SessionCubit, SessionState>(
        listenWhen: (_, s) => s.status == SessionStatus.authenticated,
        listener: (context, _) => context.go(RoutePaths.home),
        child: _LoginView(server: server),
      ),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.server});

  final JellyfinServerInfo server;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit(
      username: _username.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final serverName = widget.server.serverName?.trim();
    final label = (serverName == null || serverName.isEmpty)
        ? widget.server.baseUrl
        : serverName;

    return AppScaffold(
      title: 'Sign in',
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            )
          : null,
      body: BlocBuilder<LoginCubit, LoginState>(
        builder: (context, state) {
          final busy = state is LoginSubmitting;

          return ListView(
            children: [
              SizedBox(height: t.spacing.lg),
              Text(
                'Sign in to $label',
                style: t.typography.headlineLarge.copyWith(
                  color: t.colors.textPrimary,
                ),
              ),
              SizedBox(height: t.spacing.xs),
              Text(
                'Use the username and password for your Jellyfin account on '
                'this server.',
                style: t.typography.bodyMedium.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
              SizedBox(height: t.spacing.lg),
              AuthTextField(
                label: 'Username',
                controller: _username,
                autofocus: true,
                enabled: !busy,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: t.spacing.md),
              AuthTextField(
                label: 'Password',
                controller: _password,
                obscureText: true,
                enabled: !busy,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
              ),
              if (state is LoginError) ...[
                SizedBox(height: t.spacing.sm),
                InlineError(message: state.failure.message),
              ],
              SizedBox(height: t.spacing.lg),
              AppButton(
                label: busy ? 'Signing in…' : 'Sign in',
                expand: true,
                onPressed: busy ? null : _submit,
              ),
            ],
          );
        },
      ),
    );
  }
}
