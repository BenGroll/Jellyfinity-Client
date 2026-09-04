import 'package:get_it/get_it.dart';
import 'package:jellyfinity/app/session/AuthSessionManager.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/session/session.dart';
import 'package:jellyfinity/features/auth/presentation/accounts/accounts_cubit.dart';
import 'package:jellyfinity/features/auth/presentation/login/login_cubit.dart';
import 'package:jellyfinity/features/auth/presentation/server_setup/server_setup_cubit.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinClientIdentity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/JellyfinServerInfo.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/JellyfinServerProbe.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/ServerVersion.dart';
import 'package:flutter_test/flutter_test.dart';

import 'TestLogger.dart';

/// In-memory [ServerRegistry] for tests.
class InMemoryServerRegistry implements ServerRegistry {
  final List<JellyfinServer> _servers = [];

  @override
  Future<List<JellyfinServer>> all() async => List.unmodifiable(_servers);

  @override
  Future<JellyfinServer?> byId(String id) async =>
      _servers.where((s) => s.id == id)._firstOrNull;

  @override
  Future<JellyfinServer?> byBaseUrl(String baseUrl) async =>
      _servers.where((s) => s.baseUrl == baseUrl)._firstOrNull;

  @override
  Future<void> save(JellyfinServer server) async {
    _servers
      ..removeWhere((s) => s.id == server.id)
      ..add(server);
  }

  @override
  Future<void> remove(String id) async =>
      _servers.removeWhere((s) => s.id == id);
}

/// In-memory [AccountStore] for tests.
class InMemoryAccountStore implements AccountStore {
  final List<JellyfinAccount> _accounts = [];
  String? _activeId;

  @override
  Future<List<JellyfinAccount>> all() async => List.unmodifiable(_accounts);

  @override
  Future<List<JellyfinAccount>> forServer(String serverId) async =>
      _accounts.where((a) => a.serverId == serverId).toList();

  @override
  Future<JellyfinAccount?> byId(String id) async =>
      _accounts.where((a) => a.id == id)._firstOrNull;

  @override
  Future<JellyfinAccount?> byServerAndUser(
    String serverId,
    String userId,
  ) async => _accounts
      .where((a) => a.serverId == serverId && a.userId == userId)
      ._firstOrNull;

  @override
  Future<void> save(JellyfinAccount account) async {
    _accounts
      ..removeWhere((a) => a.id == account.id)
      ..add(account);
  }

  @override
  Future<void> remove(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    if (_activeId == id) _activeId = null;
  }

  @override
  Future<String?> activeAccountId() async => _activeId;

  @override
  Future<void> setActiveAccountId(String? id) async => _activeId = id;
}

/// In-memory [CredentialStore] for tests. Exposes its contents so tests
/// can assert a token was written or cleared.
class InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> tokens = {};

  @override
  Future<String?> readToken(String accountId) async => tokens[accountId];

  @override
  Future<void> writeToken(String accountId, String token) async =>
      tokens[accountId] = token;

  @override
  Future<void> deleteToken(String accountId) async => tokens.remove(accountId);
}

/// A [JellyfinAuthenticator] with a scripted outcome.
class FakeJellyfinAuthenticator implements JellyfinAuthenticator {
  FakeJellyfinAuthenticator({this.result});

  /// The outcome the next [authenticate] call returns. Defaults to a
  /// generic success.
  Result<AuthenticatedUser>? result;

  final List<({String username, String password})> calls = [];

  @override
  Future<Result<AuthenticatedUser>> authenticate({
    required JellyfinServer server,
    required String username,
    required String password,
  }) async {
    calls.add((username: username, password: password));
    return result ??
        Result.ok(
          AuthenticatedUser(
            userId: 'user-$username',
            username: username,
            accessToken: 'token-$username',
          ),
        );
  }
}

/// A [JellyfinServerInfo] with sensible defaults for tests.
JellyfinServerInfo fakeServerInfo({
  String baseUrl = 'https://demo.jellyfin.org',
  String version = '10.11.6',
  String? serverName = 'Home Media',
  String? serverId = 'jf-1',
}) => JellyfinServerInfo(
  baseUrl: baseUrl,
  version: ServerVersion.tryParse(version)!,
  serverName: serverName,
  serverId: serverId,
);

/// A fully-wired [AuthSessionManager] + [SessionCubit] over in-memory
/// fakes, for session/router/shell tests.
class TestSessionScope {
  TestSessionScope({
    Result<AuthenticatedUser>? authResult,
    InMemoryServerRegistry? servers,
    InMemoryAccountStore? accounts,
    InMemoryCredentialStore? credentials,
  }) {
    this.servers = servers ?? InMemoryServerRegistry();
    this.accounts = accounts ?? InMemoryAccountStore();
    this.credentials = credentials ?? InMemoryCredentialStore();
    authenticator = FakeJellyfinAuthenticator(result: authResult);
    manager = AuthSessionManager(
      this.servers,
      this.accounts,
      this.credentials,
      authenticator,
      TestLogger(),
    );
    var counter = 0;
    manager.newId = () => 'id-${++counter}';
    cubit = SessionCubit(manager);
  }

  late final InMemoryServerRegistry servers;
  late final InMemoryAccountStore accounts;
  late final InMemoryCredentialStore credentials;
  late final FakeJellyfinAuthenticator authenticator;
  late final AuthSessionManager manager;
  late final SessionCubit cubit;

  /// Authenticates and signs [cubit] in, the way the login screen would.
  Future<void> signIn({
    String username = 'alice',
    String password = 'pw',
    JellyfinServerInfo? server,
  }) async {
    await cubit.logIn(
      server: server ?? fakeServerInfo(),
      username: username,
      password: password,
    );
  }
}

/// Registers the auth-feature cubits in [GetIt] so full-app widget tests
/// can traverse the `/connect`, `/connect/sign-in` and `/accounts` routes.
/// The server probe is inert (never asked to hit a network in these
/// tests); the cubits are wired to [scope]'s fakes.
void registerAuthCubits(TestSessionScope scope) {
  final getIt = GetIt.instance;
  const identity = JellyfinClientIdentity(
    clientName: 'Jellyfinity',
    clientVersion: 'test',
    deviceName: 'Test',
    deviceId: 'dev-1',
  );
  final probe = JellyfinServerProbe(
    identity,
    const NoAuthTokenProvider(),
    TestLogger(),
  );
  getIt
    ..registerFactory<ServerSetupCubit>(() => ServerSetupCubit(probe))
    ..registerFactory<LoginCubit>(() => LoginCubit(scope.cubit))
    ..registerFactory<AccountsCubit>(
      () => AccountsCubit(scope.servers, scope.accounts, scope.cubit),
    );
  addTearDown(getIt.reset);
}

/// Whether [failure] is any [Failure]; a readable matcher helper.
bool isFailure(Object? failure) => failure is Failure;

extension _FirstOrNull<E> on Iterable<E> {
  E? get _firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
