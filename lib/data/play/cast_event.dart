/// Which kind of native cast lifecycle event fired. Mirrors the three
/// cases the `AirPlayCastEngine` native side emits over the
/// `animeko/airplay_cast_events` `EventChannel` (see
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4-5).
enum CastEventType { activated, deactivated, failed }

/// One event from the native AirPlay cast engine.
class CastEvent {
  const CastEvent({
    required this.type,
    this.deviceName,
    this.lastPositionMs,
    this.reason,
  });

  final CastEventType type;

  /// Populated only when [type] is [CastEventType.activated]. The
  /// Core-Audio-resolved display name of the active AirPlay receiver,
  /// or a fallback string if that lookup failed natively.
  final String? deviceName;

  /// Populated only when [type] is [CastEventType.deactivated]. The cast
  /// `AVPlayer`'s last known position in milliseconds, so local playback
  /// can resume from exactly where casting left off.
  final int? lastPositionMs;

  /// Populated only when [type] is [CastEventType.failed]. A
  /// human-readable description of the native playback failure.
  final String? reason;

  /// Parses the raw map payload delivered by the `EventChannel`.
  factory CastEvent.fromMap(Map<Object?, Object?> map) {
    final rawType = map['type'] as String;
    final type = CastEventType.values.firstWhere((v) => v.name == rawType);
    return CastEvent(
      type: type,
      deviceName: map['deviceName'] as String?,
      lastPositionMs: map['lastPositionMs'] as int?,
      reason: map['reason'] as String?,
    );
  }
}
