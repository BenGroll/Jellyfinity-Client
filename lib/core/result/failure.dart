import 'package:equatable/equatable.dart';

/// Base type for every expected failure Jellyfinity code can produce.
///
/// A [Failure] represents something that went wrong in a way the
/// application anticipated and can present to the user meaningfully.
/// Raw transport/platform exceptions must be caught and translated into a
/// [Failure] before crossing from infrastructure into domain/presentation
/// code; UI code must never receive them directly.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.cause, this.stackTrace});

  /// A short, user-presentable or log-presentable description.
  ///
  /// This must never contain credentials, tokens, or other sensitive data.
  final String message;

  /// The underlying exception/error that produced this failure, if any.
  ///
  /// Kept for logging/diagnostics; never surfaced to UI directly.
  final Object? cause;

  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [message, cause, stackTrace];
}

/// Something failed in a way the user can typically retry (e.g. a timed
/// out request, a transient connection problem).
final class RecoverableFailure extends Failure {
  const RecoverableFailure(super.message, {super.cause, super.stackTrace});
}

/// The requested data is currently unavailable (e.g. the server is
/// unreachable, a track was removed from the library) but the failure
/// itself is well understood and expected.
final class UnavailableFailure extends Failure {
  const UnavailableFailure(super.message, {super.cause, super.stackTrace});
}

/// Something failed in a way that was not anticipated, such as an
/// unhandled exception surfacing from infrastructure code.
///
/// Prefer a more specific [Failure] subtype whenever the cause is known.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}
