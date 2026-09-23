import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/app/session/SessionState.dart';
import 'package:jellyfinity/features/music/presentation/selection/TrackSelectionCubit.dart';

import '../../../support/music_fakes.dart';
import '../../../support/session_fakes.dart';

void main() {
  late SessionCubit session;
  late TrackSelectionCubit cubit;

  setUp(() {
    session = fakeSessionCubit(signedIn: fakeAuthSession());
    cubit = TrackSelectionCubit(session);
  });

  tearDown(() async {
    await cubit.close();
    await session.close();
  });

  test('starts inactive with nothing selected', () {
    expect(cubit.state.active, isFalse);
    expect(cubit.state.selected, isEmpty);
  });

  test('enter turns selection mode on with nothing checked', () {
    cubit.enter();
    expect(cubit.state.active, isTrue);
    expect(cubit.state.selected, isEmpty);
  });

  test('enter is a no-op once already active', () {
    cubit.toggle(mediaId('t1'));
    cubit.enter();
    expect(cubit.state.selected, {mediaId('t1')});
  });

  test('toggle checks an id and activates selection mode in one step', () {
    cubit.toggle(mediaId('t1'));
    expect(cubit.state.active, isTrue);
    expect(cubit.state.selected, {mediaId('t1')});
  });

  test('toggling the same id twice unchecks it but stays active', () {
    cubit.toggle(mediaId('t1'));
    cubit.toggle(mediaId('t1'));
    expect(cubit.state.active, isTrue);
    expect(cubit.state.selected, isEmpty);
  });

  test('toggle accumulates distinct ids without duplicates', () {
    cubit.toggle(mediaId('t1'));
    cubit.toggle(mediaId('t2'));
    cubit.toggle(mediaId('t1'));
    expect(cubit.state.selected, {mediaId('t2')});
  });

  test('exit clears everything and turns selection mode off', () {
    cubit.toggle(mediaId('t1'));
    cubit.toggle(mediaId('t2'));
    cubit.exit();
    expect(cubit.state.active, isFalse);
    expect(cubit.state.selected, isEmpty);
  });

  test('retainOnly narrows the selection but stays active', () {
    cubit.toggle(mediaId('t1'));
    cubit.toggle(mediaId('t2'));
    cubit.toggle(mediaId('t3'));
    cubit.retainOnly({mediaId('t1'), mediaId('t3')});
    expect(cubit.state.active, isTrue);
    expect(cubit.state.selected, {mediaId('t1'), mediaId('t3')});
  });

  group('profile/server isolation', () {
    test(
      'switching to a different account clears an in-progress selection',
      () async {
        cubit.toggle(mediaId('t1'));
        expect(cubit.state.selected, isNotEmpty);

        session.emit(
          SessionState.signedIn(
            fakeAuthSession(account: fakeJellyfinAccount(id: 'acct-2')),
          ),
        );
        await pumpEventQueue();

        expect(cubit.state.active, isFalse);
        expect(cubit.state.selected, isEmpty);
      },
    );

    test('signing out clears an in-progress selection', () async {
      cubit.toggle(mediaId('t1'));

      session.emit(const SessionState.signedOut());
      await pumpEventQueue();

      expect(cubit.state.selected, isEmpty);
    });

    test(
      'a session event for the same account does not clear selection',
      () async {
        // A token refresh re-emits the same signed-in account — not a
        // profile switch, so an in-progress selection should survive it
        // (mirrors DownloadsCubit's `_activeAccountId` comparison).
        cubit.toggle(mediaId('t1'));

        session.emit(SessionState.signedIn(fakeAuthSession()));
        await pumpEventQueue();

        expect(cubit.state.active, isTrue);
        expect(cubit.state.selected, {mediaId('t1')});
      },
    );
  });
}
