# ADR-0046: Android background connected-playback service

- Status: Accepted (v0.6.0)
- Date: 2026-09-15

## Decision

When a signed-in Android Jellyfinity session is backgrounded, start a minimal
dataSync foreground service while connected playback is active. The service
owns no Flutter state and no audio; it only keeps the process eligible for the
connected-playback WebSocket and is stopped when the app resumes, signs out, or
a sleeping television takes the existing TV suspend path.

Background presence polling uses a quieter cadence and a longer stale window.
Foreground polling and the television display-sleep behavior are unchanged.

## Rationale

An Android phone that is only controlling or targeting another device has no
audio-service playback foreground service. Doze can therefore suspend the
socket and timers, causing a healthy peer to be reported unavailable after the
presence timeout. A small user-visible foreground service is the platform
mechanism that preserves reachability without pretending remote control is
audio playback.

The service is deliberately separate from audio_service: it must not claim
audio focus, own a media session, or alter playback. The Dart transport remains
authoritative, and service failures are non-fatal to local playback.

## Consequences

The Android build shows a low-priority persistent notification while the app
is backgrounded and connected. Battery use is bounded by the slower background
presence cadence. Android TV/Fire TV continues to suspend when its display is
off, as required by the connected-playback lifecycle rule.
