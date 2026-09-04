import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/session/SessionJellyfinContext.dart';

import '../../support/session_fakes.dart';

void main() {
  test('reports nothing while signed out', () {
    final context = SessionJellyfinContext(TestSessionScope().manager);

    expect(context.serverId, isNull);
    expect(context.baseUrl, isNull);
    expect(context.userId, isNull);
  });

  test("reports the active profile's server and user once signed in", () async {
    final scope = TestSessionScope();
    final context = SessionJellyfinContext(scope.manager);

    await scope.signIn(
      server: fakeServerInfo(baseUrl: 'https://media.example.com'),
    );

    final session = scope.manager.current!;
    // The media layer builds every MediaId from this server id, so it
    // must be Jellyfinity's local id for the saved server rather than the
    // server's own self-reported one.
    expect(context.serverId, session.server.id);
    expect(context.serverId, isNot(session.server.serverId));
    expect(context.baseUrl, 'https://media.example.com');
    expect(context.userId, session.account.userId);
  });

  test('stops reporting a profile after sign-out', () async {
    final scope = TestSessionScope();
    final context = SessionJellyfinContext(scope.manager);

    await scope.signIn();
    await scope.manager.logOut();

    expect(context.serverId, isNull);
    expect(context.baseUrl, isNull);
  });
}
