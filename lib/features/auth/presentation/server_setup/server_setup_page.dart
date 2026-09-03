import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../design/design.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/inline_error.dart';
import 'server_setup_cubit.dart';

/// Step one of connecting: enter a Jellyfin server address, validate it,
/// then move on to sign-in.
class ServerSetupPage extends StatelessWidget {
  const ServerSetupPage({super.key, this.cubit});

  /// Test seam — production builds resolve the cubit from the locator.
  final ServerSetupCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ServerSetupCubit>(
      create: (_) => cubit ?? getIt<ServerSetupCubit>(),
      child: const _ServerSetupView(),
    );
  }
}

class _ServerSetupView extends StatefulWidget {
  const _ServerSetupView();

  @override
  State<_ServerSetupView> createState() => _ServerSetupViewState();
}

class _ServerSetupViewState extends State<_ServerSetupView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<ServerSetupCubit>().validate(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return BlocListener<ServerSetupCubit, ServerSetupState>(
      listenWhen: (_, s) => s is ServerSetupValid,
      listener: (context, state) {
        if (state is ServerSetupValid) {
          context.pushNamed(RouteNames.signIn, extra: state.server);
          // Reset so returning to this screen is editable again.
          context.read<ServerSetupCubit>().reset();
        }
      },
      child: AppScaffold(
        title: 'Connect a server',
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        body: BlocBuilder<ServerSetupCubit, ServerSetupState>(
          builder: (context, state) {
            final busy = state is ServerSetupValidating;

            return ListView(
              children: [
                SizedBox(height: t.spacing.lg),
                Text(
                  'Where does your Jellyfin server live?',
                  style: t.typography.headlineLarge.copyWith(
                    color: t.colors.textPrimary,
                  ),
                ),
                SizedBox(height: t.spacing.xs),
                Text(
                  'Enter the address you use to reach it — for example '
                  'https://media.example.com or http://192.168.1.10:8096.',
                  style: t.typography.bodyMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
                SizedBox(height: t.spacing.lg),
                AuthTextField(
                  label: 'Server address',
                  controller: _controller,
                  hintText: 'https://media.example.com',
                  keyboardType: TextInputType.url,
                  autofocus: true,
                  enabled: !busy,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                ),
                if (state is ServerSetupInvalid) ...[
                  SizedBox(height: t.spacing.sm),
                  InlineError(message: state.failure.message),
                ],
                SizedBox(height: t.spacing.lg),
                AppButton(
                  label: busy ? 'Checking…' : 'Continue',
                  icon: busy ? null : Icons.arrow_forward_rounded,
                  expand: true,
                  onPressed: busy ? null : _submit,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
