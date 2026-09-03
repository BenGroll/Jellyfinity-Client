import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../app/session/session_cubit.dart';
import '../../../../domain/session/account_store.dart';
import '../../../../domain/session/jellyfin_account.dart';
import '../../../../domain/session/jellyfin_server.dart';
import '../../../../domain/session/server_registry.dart';

/// Backs the saved servers & profiles screen: list what is saved, mark
/// the active profile, and route switch / sign-out / remove actions
/// through [SessionCubit].
@injectable
class AccountsCubit extends Cubit<AccountsState> {
  AccountsCubit(this._servers, this._accounts, this._session)
    : super(const AccountsLoading());

  final ServerRegistry _servers;
  final AccountStore _accounts;
  final SessionCubit _session;

  Future<void> load() async {
    final servers = await _servers.all();
    final accounts = await _accounts.all();
    final activeId = await _accounts.activeAccountId();

    final groups = [
      for (final server in servers)
        AccountGroup(
          server: server,
          accounts: accounts.where((a) => a.serverId == server.id).toList(),
        ),
    ];
    emit(AccountsLoaded(groups: groups, activeAccountId: activeId));
  }

  Future<void> switchTo(String accountId) async {
    await _session.switchTo(accountId);
    await load();
  }

  Future<void> signOut() async {
    await _session.signOut();
    await load();
  }

  Future<void> removeAccount(String accountId) async {
    await _session.removeAccount(accountId);
    await load();
  }

  Future<void> removeServer(String serverId) async {
    await _session.removeServer(serverId);
    await load();
  }
}

/// One saved server and the profiles saved on it.
class AccountGroup extends Equatable {
  const AccountGroup({required this.server, required this.accounts});

  final JellyfinServer server;
  final List<JellyfinAccount> accounts;

  @override
  List<Object?> get props => [server, accounts];
}

sealed class AccountsState extends Equatable {
  const AccountsState();

  @override
  List<Object?> get props => [];
}

class AccountsLoading extends AccountsState {
  const AccountsLoading();
}

class AccountsLoaded extends AccountsState {
  const AccountsLoaded({required this.groups, this.activeAccountId});

  final List<AccountGroup> groups;
  final String? activeAccountId;

  bool get isEmpty => groups.every((g) => g.accounts.isEmpty);

  @override
  List<Object?> get props => [groups, activeAccountId];
}
