import 'ConnectedDevice.dart';
import 'ConnectedPlaybackLimits.dart';
import 'ConnectedPlaybackScope.dart';
import 'DeviceAdvertisement.dart';
import 'DeviceCapabilities.dart';
import 'DeviceObservation.dart';
import 'ElapsedClock.dart';
import 'ProtocolVersion.dart';
import 'connection_state.dart';
import 'device_reachability.dart';

/// The presence read model for one server-and-profile scope.
///
/// Two different sources feed it and neither is sufficient alone. The
/// server says which sessions exist, which install each belongs to and
/// whether it will route commands to them; the peers themselves say what
/// protocol they speak and what they will accept. A device seen only by
/// the server is real but not yet usable — [DeviceReachability.presenceOnly]
/// — and saying so is the honest answer, rather than either hiding it
/// until it answers or offering it as ready and discovering otherwise
/// after the listener has chosen it.
///
/// Pure by design: no transport, no timers, no Flutter. Everything that
/// makes presence hard to get right — a device that reconnects under a
/// new session id, two devices the listener gave the same name, a peer
/// that stopped answering, a profile switch — is decided here against an
/// injected [ElapsedClock], so all of it is testable without a server.
///
/// Entries are keyed by [ConnectedDevice.deviceId], never by session id.
/// That is the whole point of the two-part identity: a peer that drops
/// and reconnects is the same row with a new address, not a second row
/// beside a ghost.
class DevicePresenceRegistry {
  DevicePresenceRegistry({
    required this.scope,
    required this.clock,
    Duration? staleAfter,
  }) : staleAfter = staleAfter ?? ConnectedPlaybackLimits.presenceStaleAfter;

  /// The one server and profile this registry may ever describe. A
  /// registry is discarded on logout or account switch rather than
  /// re-scoped, so no entry can outlive the profile it was observed for.
  final ConnectedPlaybackScope scope;

  /// The monotonic source every expiry decision is measured against.
  final ElapsedClock clock;

  Duration staleAfter;
  final Map<String, _PresenceEntry> _entries = {};

  ConnectedPlaybackConnection _link = ConnectedPlaybackConnection.idle;

  /// This device's own link state, which changes what every row means: a
  /// peer last heard from ten seconds ago is `ready` on a live socket and
  /// `offline` when the server cannot be reached at all.
  ConnectedPlaybackConnection get link => _link;

  /// Returns whether the state actually changed, so a caller can avoid
  /// re-emitting an identical device list.
  bool setLink(ConnectedPlaybackConnection link) {
    if (_link == link) return false;
    _link = link;
    return true;
  }

  bool get isEmpty => _entries.isEmpty;

  /// Replaces the roster with a complete server reading.
  ///
  /// Sessions absent from [observations] are forgotten rather than left
  /// to expire: a full `/Sessions` read is the server's authoritative
  /// answer to "what exists", and a device that has signed out should
  /// disappear now, not in five minutes. Their advertised capabilities
  /// are kept for the ones that remain, because a REST resync says
  /// nothing about protocol or capability and must not erase what the
  /// peers themselves said.
  bool replaceAll(Iterable<DeviceObservation> observations) {
    final seen = <String>{};
    var changed = false;
    for (final observation in observations) {
      seen.add(observation.deviceId);
      changed = observe(observation) || changed;
    }
    final removed = _entries.keys.where((id) => !seen.contains(id)).toList();
    for (final deviceId in removed) {
      _entries.remove(deviceId);
      changed = true;
    }
    return changed;
  }

  /// Records one sighting, creating the row or refreshing it in place.
  bool observe(DeviceObservation observation) {
    final existing = _entries[observation.deviceId];
    final entry =
        existing ??
        _PresenceEntry(
          deviceId: observation.deviceId,
          sessionId: observation.sessionId,
          name: observation.name,
        );

    final wasSameSession = entry.sessionId == observation.sessionId;
    final before = existing == null ? null : _describe(entry);

    if (!wasSameSession) {
      // A new session for a known install: the address changed and
      // everything the old session told us about itself is unverified
      // until the new one says it again. Capabilities are the dangerous
      // half — offering a command to a session that never claimed to
      // accept it is exactly the failure the capability handshake
      // exists to prevent.
      entry.sessionId = observation.sessionId;
      entry.advertisement = null;
      entry.protocolVersion = null;
      entry.notPermitted = false;
    }

    entry.observedName = observation.name;
    entry.supportsRemoteControl = observation.supportsRemoteControl;
    entry.isPlaying = observation.isPlaying;
    entry.isThisDevice = observation.isThisDevice;
    entry.lastSeen = clock.elapsed;
    _entries[observation.deviceId] = entry;

    return existing == null || before != _describe(entry);
  }

  /// Records what a peer said about itself, arriving as a presence
  /// envelope from [sessionId].
  ///
  /// Ignored when no session by that id is known: presence is something
  /// the server has to corroborate, so a message from a session that is
  /// not in the roster does not conjure a device into the picker.
  bool applyAdvertisement(
    String sessionId,
    ProtocolVersion protocolVersion,
    DeviceAdvertisement advertisement,
  ) {
    final entry = _bySession(sessionId);
    if (entry == null) return false;
    final before = _describe(entry);
    entry.advertisement = advertisement;
    entry.protocolVersion = protocolVersion;
    entry.isPlaying = advertisement.isPlaying;
    entry.lastSeen = clock.elapsed;
    return before != _describe(entry);
  }

  /// Records that [sessionId] speaks a protocol this build cannot talk
  /// to. Kept listed and labelled: the listener has to know which install
  /// to update, and a device that silently vanished would not tell them.
  bool markIncompatible(String sessionId, ProtocolVersion protocolVersion) {
    final entry = _bySession(sessionId);
    if (entry == null) return false;
    final before = _describe(entry);
    entry.protocolVersion = protocolVersion;
    entry.advertisement = null;
    entry.lastSeen = clock.elapsed;
    return before != _describe(entry);
  }

  /// Records that the server refused to let this profile control
  /// [sessionId].
  bool markNotPermitted(String sessionId) {
    final entry = _bySession(sessionId);
    if (entry == null) return false;
    final before = _describe(entry);
    entry.notPermitted = true;
    return before != _describe(entry);
  }

  /// Drops the entry addressed as [sessionId], if there is one.
  ///
  /// For the one thing a roster read cannot tell in time: the server
  /// refusing a message because that session no longer exists. Waiting
  /// for the next `/Sessions` read would leave a device the listener can
  /// see and cannot use.
  bool forgetSession(String sessionId) {
    final entry = _bySession(sessionId);
    if (entry == null) return false;
    _entries.remove(entry.deviceId);
    return true;
  }

  /// Drops entries last heard from longer ago than
  /// [ConnectedPlaybackLimits.presenceDropAfter].
  ///
  /// Separate from reading [devices] so that presence never changes as a
  /// side effect of being looked at — an expiry that happened because a
  /// widget rebuilt would be impossible to reason about.
  bool prune() {
    final now = clock.elapsed;
    final expired = _entries.values
        .where(
          (entry) =>
              now - entry.lastSeen > ConnectedPlaybackLimits.presenceDropAfter,
        )
        .map((entry) => entry.deviceId)
        .toList();
    for (final deviceId in expired) {
      _entries.remove(deviceId);
    }
    return expired.isNotEmpty;
  }

  /// Forgets everything. Called on logout, account switch and server
  /// removal, where "eventually expires" is not good enough.
  void clear() {
    _entries.clear();
    _link = ConnectedPlaybackConnection.idle;
  }

  /// The devices as a picker should see them, in a stable order, with
  /// duplicate names disambiguated.
  List<ConnectedDevice> get devices {
    final now = clock.elapsed;
    final hints = _nameHints();
    final devices = _entries.values
        .map((entry) => _toDevice(entry, now, hints[entry.deviceId]))
        .toList();
    devices.sort((a, b) {
      final byName = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      return byName != 0 ? byName : a.deviceId.compareTo(b.deviceId);
    });
    return List.unmodifiable(devices);
  }

  ConnectedDevice _toDevice(
    _PresenceEntry entry,
    Duration now,
    String? nameHint,
  ) {
    final advertisement = entry.advertisement;
    return ConnectedDevice(
      scope: scope,
      deviceId: entry.deviceId,
      sessionId: entry.sessionId,
      name: entry.name,
      nameHint: nameHint,
      protocolVersion: entry.protocolVersion ?? ProtocolVersion.current,
      capabilities: advertisement?.capabilities ?? DeviceCapabilities.none,
      reachability: _reachability(entry, now),
      lastSeen: entry.lastSeen,
      isThisDevice: entry.isThisDevice,
      isPlaying: entry.isPlaying,
    );
  }

  /// The order of these tests is the order of how much they matter to the
  /// listener, not the order they are cheapest to check. "Your server is
  /// unreachable" explains an unusable device better than "that device
  /// has not been heard from", and an incompatible install is worth
  /// saying even about a device that also went quiet.
  DeviceReachability _reachability(_PresenceEntry entry, Duration now) {
    if (_link == ConnectedPlaybackConnection.offline) {
      return DeviceReachability.offline;
    }
    final version = entry.protocolVersion;
    if (version != null && !version.isCompatibleWith(ProtocolVersion.current)) {
      return DeviceReachability.incompatible;
    }
    if (entry.notPermitted ||
        _link == ConnectedPlaybackConnection.notPermitted) {
      return DeviceReachability.notPermitted;
    }
    if (now - entry.lastSeen > ConnectedPlaybackLimits.presenceStaleAfter) {
      return DeviceReachability.stale;
    }
    if (!entry.supportsRemoteControl || entry.advertisement == null) {
      return DeviceReachability.presenceOnly;
    }
    // A device this one is only half-connected to is present but not
    // commandable: mid-reconnect, neither end's idea of the state has
    // been verified, and the arc forbids presenting such a peer as a
    // ready target.
    if (!_link.hasLivePresence) return DeviceReachability.presenceOnly;
    return DeviceReachability.ready;
  }

  /// Works out the short suffix each ambiguous row needs.
  ///
  /// Only names that actually collide get one — a hint on a unique name
  /// is noise — and the suffix is chosen to stay the same between
  /// readings. The platform is preferred because it is what the listener
  /// would say themselves; where that does not separate them (two Windows
  /// machines both called "Desktop") the tail of the stable install id
  /// does, and unlike a positional number it does not change when an
  /// unrelated device drops off the list.
  Map<String, String> _nameHints() {
    final byName = <String, List<_PresenceEntry>>{};
    for (final entry in _entries.values) {
      byName.putIfAbsent(entry.name.trim().toLowerCase(), () => []).add(entry);
    }

    final hints = <String, String>{};
    for (final group in byName.values) {
      if (group.length < 2) continue;
      final platformCounts = <String, int>{};
      for (final entry in group) {
        final platform = entry.advertisement?.platform;
        if (platform != null) {
          platformCounts[platform] = (platformCounts[platform] ?? 0) + 1;
        }
      }
      for (final entry in group) {
        final platform = entry.advertisement?.platform;
        hints[entry.deviceId] =
            platform != null && platformCounts[platform] == 1
            ? platform
            : _shortId(entry.deviceId);
      }
    }
    return hints;
  }

  static String _shortId(String deviceId) {
    final tail = deviceId.length <= 4
        ? deviceId
        : deviceId.substring(deviceId.length - 4);
    return tail.toUpperCase();
  }

  _PresenceEntry? _bySession(String sessionId) {
    for (final entry in _entries.values) {
      if (entry.sessionId == sessionId) return entry;
    }
    return null;
  }

  /// A cheap value summary used to answer "did this change" without
  /// rebuilding the whole device list. [lastSeen] is deliberately absent:
  /// a peer being heard from again is not a change a picker should
  /// redraw for.
  static String _describe(_PresenceEntry entry) => [
    entry.sessionId,
    entry.name,
    entry.supportsRemoteControl,
    entry.isPlaying,
    entry.isThisDevice,
    entry.notPermitted,
    entry.protocolVersion,
    entry.advertisement?.platform,
    entry.advertisement?.capabilities,
  ].join('|');
}

/// One device's accumulated presence. Mutable and private: it is a
/// running total of two message streams, and copying it on every
/// keep-alive would be a lot of allocation to express nothing.
class _PresenceEntry {
  _PresenceEntry({
    required this.deviceId,
    required this.sessionId,
    required String name,
  }) : observedName = name,
       lastSeen = Duration.zero;

  final String deviceId;
  String sessionId;

  /// The name the *server* reports for the session.
  String observedName;

  DeviceAdvertisement? advertisement;
  ProtocolVersion? protocolVersion;
  bool supportsRemoteControl = true;
  bool notPermitted = false;
  bool isPlaying = false;
  bool isThisDevice = false;
  Duration lastSeen;

  /// A peer's own word for itself wins over the server's record of it:
  /// the server's copy is whatever the session reported when it
  /// connected, and a device renamed since then is still right about its
  /// own name.
  String get name => advertisement?.name ?? observedName;
}
