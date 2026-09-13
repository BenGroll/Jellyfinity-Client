# ADR-0044: Auto-detected remote playback

## Status

Accepted (v0.6.0).

## Context

Everything the connected-playback arc built began at the device picker. A
listener whose television was playing could open Jellyfinity on their phone,
see an empty player, and conclude that nothing was connected — the feature
worked, and was invisible. "It should get auto detected if another device
already plays music" is the requirement v0.6.0 added, and it is the one that
decides whether any of the rest is reachable.

The presence roster already carries what is needed: which of this profile's
devices exist, which is playing, and which has advertised what it accepts.
Nothing consumed it except the picker and, once a device was chosen,
`PlaybackControlCubit`.

Binding a device to remote playback by itself is not a free action. It changes
what the mini-player, Now Playing and the queue screen show, and it is wrong
often enough to need rules: a listener already playing music locally, two rooms
both playing, or a listener who has just deliberately stopped controlling
something.

## Considered

**Auto-adopt inside `PlaybackControlCubit`.** It already follows presence. But
only for the device it holds, and its contract is "what this app is
controlling", not "what is worth controlling" — the second question is asked
continuously, from facts (local playback state, the whole roster) the cubit
does not otherwise need. Folding them together would also mean the rule could
only be tested through the cubit's command surface.

**Ask the listener each time** — a banner or a prompt when another device is
found playing. Rejected as the default: the answer is the same nearly every
time, and a prompt on every app open is a worse version of the picker nobody
opened. A listener who disagrees says so once, by stopping, and that is
remembered.

**Adopt the most recently active device when several play.** Rejected: it is a
guess with a speaker attached. Two devices playing is a genuine question, and
the picker is the place it is answered.

## Decision

A separate `@lazySingleton`, `ActiveRemotePlaybackWatcher`, started at the
composition root like the other links. It follows the active scope's roster and
calls `PlaybackControlCubit.control` when, and only when:

- this app is controlling nothing, and is not playing anything itself;
- exactly one peer is playing;
- that peer is `DeviceReachability.ready` — it has advertised, so the controls
  bound to it are real — and says it can play.

Controlling *ending* is the listener's "no", however the binding began, and the
session it ended is not adopted again while it keeps playing. The refusal is
keyed by session id, not device id: a television that reconnects under a new
session, or one whose playback stops and starts again, is a new question rather
than the one already answered. A profile change clears it, because the next
profile's devices have never been offered.

## Consequences

- Opening Jellyfinity anywhere on the account shows the music that is playing,
  which is what makes the picker, the remote transport controls and the queue
  projection discoverable at all.
- The rule is one class with no widget and no server: its whole behaviour is
  covered by unit tests against the presence fake.
- Local playback always wins. The watcher never interrupts, never pauses, and
  never takes a device away from the person holding it.
- Group playback (also v0.6.0) will extend this rather than replace it: a
  member of a group is still a device that is playing, and the same rule binds
  to it.
