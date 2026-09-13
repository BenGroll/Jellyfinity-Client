/// Why a target will not, or could not, take over playback.
///
/// The arc is explicit about this: a transfer is refused *before* the
/// source stops when the target cannot reproduce the queue faithfully,
/// and "local-only items, unsupported media, an unreachable server, an
/// oversized payload, or missing playback permission must have a specific
/// explanation; entries are never silently removed or reordered".
///
/// So every member below is a sentence the listener can be shown and can
/// act on, and none of them is a generic failure. The alternative — drop
/// the three tracks the TV cannot play and hand over the rest — is the
/// behaviour this list exists to prevent: a queue that arrives quietly
/// different from the one the listener was listening to.
enum TransferRefusal {
  /// Some entries exist only on the source device — a sideloaded file, a
  /// download whose server item is gone. The target cannot resolve them
  /// from the server, and Jellyfinity does not send audio between
  /// clients.
  localOnlyItems,

  /// The target cannot play some entries' media at all.
  unsupportedMedia,

  /// The target cannot reach the shared server, so it cannot resolve the
  /// queue even though it understood it.
  serverUnreachable,

  /// The queue is longer than the target accepts — see
  /// `DeviceCapabilities.maxQueueEntries`.
  queueTooLarge,

  /// The target's profile is not allowed to play this content.
  notPermitted,

  /// The target speaks a different protocol major version.
  incompatible,

  /// The target is already receiving a transfer. Serializing handoffs is
  /// the same reasoning as serializing controllers: two sources handing
  /// over at once would leave ownership ambiguous.
  busy,

  /// A step of the handoff was not answered in time.
  timedOut,

  /// The target accepted but then could not actually start playing.
  playbackFailed,

  /// The listener changed their mind, or the source cancelled.
  cancelled;

  /// Whether trying the same transfer again could succeed.
  ///
  /// False for the refusals that are facts about the queue or the pair of
  /// devices: offering a retry that will be refused identically is worse
  /// than saying plainly that this will not work.
  bool get isRetryable => switch (this) {
    TransferRefusal.serverUnreachable ||
    TransferRefusal.busy ||
    TransferRefusal.timedOut ||
    TransferRefusal.playbackFailed ||
    TransferRefusal.cancelled => true,
    _ => false,
  };
}
