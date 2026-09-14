# Jellyfinity v0.6.1-v0.7.0 specifications

Read only the assigned version. Every version requires focused changes,
behavior tests, a current changelog entry, and passing CI. Record durable
navigation, persistence, and platform decisions in an ADR.

## v0.6.1 - Settings as places

**Goal:** Give settings room to grow. The single scrolling page has become the
screen where every new option lands and nothing is findable; this replaces it
with a small set of named places, each of which can hold the options a later
release adds without becoming the same problem again.

**Required:**

- Split settings into subcategory screens with a stable route each, reachable
  from a settings home that shows the categories and a one-line summary of the
  current value where a summary is genuinely useful. Every existing option
  keeps working and keeps its current behavior; this is a re-homing, not a
  redesign of what the options do.
- Categories follow what a listener came to change, not how the code is
  organized. Playback and sound, downloads and storage, connected playback and
  devices, library and offline, account and server, and about/diagnostics are
  the expected shape; an option that fits two places lives in one and is found
  from the other only if search or a cross-link earns its keep.
- The connected-playback category is where v0.6.0's new options live — default
  playback destination, whether this device may be controlled, group playback
  behavior — so that release adds to a structure rather than to a pile.
- Deep links and back behavior are correct on every platform: a category is a
  real destination that can be opened directly, returned from, and restored
  after process recreation. Windowed layouts show the category list and the
  selected category together where there is room; phone and television present
  one at a time, with television keeping D-pad order and initial focus explicit
  per ADR-0036.
- Accessibility and localization-ready copy for every category title, summary,
  and option, with no truncated or ambiguous labels at the smallest supported
  width.

**Done when:** Every existing setting is reachable in at most two steps from a
named category, a new option has an obvious home, and no platform has lost a
route, a back gesture, or a focus order to get there.
