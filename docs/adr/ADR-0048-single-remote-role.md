# ADR-0048: One remote role per device, and what a revision means

- Status: Accepted (v0.6.0)
- Date: 2026-09-16

## Context

Device acceptance testing of v0.6.0 found the Remote feature unusable in
ways that shared two root causes.

A target published a snapshot on every `PlaybackCubit` change, including
the once-a-second position tick, and every publication moved
`StateRevision`. Structural commands are arbitrated against the revision
they were composed under, so `setQueue`, `jumpToQueueEntry` and every
queue edit were refused as stale for as long as the target was making
sound. Only the commands carrying no revision — play/pause, next,
previous — ever worked, which is why choosing a song from a controller
always answered "That device has moved on".

Control was also a relationship only the controller knew about. Nothing
was advertised about it, so a device could not tell it was being driven,
both devices could drive each other simultaneously, and "play on this
device" left a session that claimed to be controlling nothing.

## Decision

**A revision counts queue changes; a sequence counts publications.**
`RemotePlaybackSnapshot` carries both. The revision moves only when
`hasSameQueueStructureAs` says the queue, its order or its current index
moved, and is what an index-based command is arbitrated against. The
sequence moves on every publication and is what a controller orders
arriving snapshots by. One counter cannot answer both questions: keyed on
the revision, a playing device either invalidates every in-flight edit or
has its position updates dropped as duplicates.

`setQueue` is exempt from revision arbitration entirely. It names no
existing row, so there is nothing for it to be wrong about, and choosing
a song for another device must work whatever that device is doing.

**A device is a controller or is controlled, never both.** A controller
advertises the session it drives (`DeviceAdvertisement
.controllingSessionId`). Every device reads its own role from presence:
it is being controlled when a peer advertises driving it, and it releases
its own target when that target advertises driving something. Whoever
acted most recently wins, so "control that device" is a complete
instruction on whichever device it is pressed. A freshly chosen target is
given a grace period before that rule applies, so a momentarily stale
advertisement cannot detach a session the listener just started.

`RemoteCommandKind.takeControl` asks the receiver to become the sender's
controller. It is what makes "play on this device" a handover: playback
moves, and the device it came from becomes the remote.

## Consequences

- A controller can change the song and edit the queue of a device that is
  actually playing, which is the only state worth controlling.
- Both ends of a control relationship can show it, and the broken state
  where two devices each believed they were controlling the other is
  unreachable rather than merely unlikely.
- Presence and the timeline tolerate a stutter: a dropped socket or one
  failed poll no longer withdraws every device, and the position is
  corrected only when it drifts further than latency explains.
- Two devices that take control of each other in the same instant both
  stand down rather than deadlocking. Pressing again resolves it, and no
  state is left inconsistent.
- A peer too old to publish a sequence reports zero for every snapshot,
  which falls back to arrival order rather than dropping everything.
