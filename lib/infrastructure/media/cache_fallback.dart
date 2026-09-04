import '../../core/result/failure.dart';

/// Whether [failure] means the server never answered, which is the only
/// situation where Jellyfinity's saved copy is a better answer than the
/// failure itself.
///
/// A [RecoverableFailure] is a timeout, an unreachable host, a server
/// error or a cancelled request — nothing was learned about the library,
/// so showing what was saved is strictly more useful than showing an
/// error page.
///
/// Everything else is a real answer and is passed through. An
/// [UnavailableFailure] in particular means the server replied and said
/// the item is not there: falling back to the cache would resurrect an
/// album the user deleted, which is worse than an honest empty screen.
/// An [UnauthorizedFailure] has no cache to read either — without a
/// session there is no server to key it by.
bool canServeFromCache(Failure failure) => failure is RecoverableFailure;
