// Proves that the v0.0.2 architectural primitives (Result/Failure/Partial,
// a Bloc/Cubit, and DI-resolved dependencies) compose correctly together.
//
// This deliberately lives only in test/ and defines its own throwaway
// repository and Cubit, rather than adding a fake feature under lib/, per
// the v0.0.2 scope: "Do not create a permanent fake product feature merely
// to demonstrate architecture."

import 'package:bloc_test/bloc_test.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:mocktail/mocktail.dart';

abstract class _Repository {
  Future<Result<Partial<String>>> loadItems();
}

class _MockRepository extends Mock implements _Repository {}

sealed class _ItemsState extends Equatable {
  const _ItemsState();

  @override
  List<Object?> get props => [];
}

class _Loading extends _ItemsState {
  const _Loading();
}

class _Loaded extends _ItemsState {
  const _Loaded(this.partial);

  final Partial<String> partial;

  @override
  List<Object?> get props => [partial];
}

class _Failed extends _ItemsState {
  const _Failed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

class _ItemsCubit extends Cubit<_ItemsState> {
  _ItemsCubit(this._repository) : super(const _Loading());

  final _Repository _repository;

  Future<void> load() async {
    emit(const _Loading());
    final result = await _repository.loadItems();
    emit(
      result.when(
        ok: (partial) => _Loaded(partial),
        err: (failure) => _Failed(failure),
      ),
    );
  }
}

void main() {
  group('a Cubit built on Result/Partial', () {
    late _MockRepository repository;

    setUp(() {
      repository = _MockRepository();
    });

    blocTest<_ItemsCubit, _ItemsState>(
      'emits Loading then Loaded with a partial result, unavailable item '
      'preserved',
      setUp: () {
        when(repository.loadItems).thenAnswer(
          (_) async => const Result.ok(
            Partial(
              available: ['track-1', 'track-2'],
              unavailable: [
                UnavailableItem(id: 'track-3', reason: 'removed from server'),
              ],
            ),
          ),
        );
      },
      build: () => _ItemsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const _Loading(),
        isA<_Loaded>()
            .having((s) => s.partial.available, 'available', hasLength(2))
            .having((s) => s.partial.hasUnavailable, 'hasUnavailable', true),
      ],
    );

    blocTest<_ItemsCubit, _ItemsState>(
      'emits Loading then Failed when the repository returns Err',
      setUp: () {
        when(repository.loadItems).thenAnswer(
          (_) async =>
              const Result.err(UnavailableFailure('server unreachable')),
        );
      },
      build: () => _ItemsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const _Loading(),
        isA<_Failed>().having(
          (s) => s.failure.message,
          'message',
          'server unreachable',
        ),
      ],
    );
  });
}
