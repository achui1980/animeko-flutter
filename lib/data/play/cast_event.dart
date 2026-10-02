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
  ///
  /// Throws a [FormatException] with a descriptive message if `'type'` is
  /// missing or not a recognized [CastEventType] value, since this parses
  /// data crossing the Dart/Swift boundary where schema drift (e.g. a new
  /// event type added natively before the Dart side is updated) is a real
  /// risk and should fail loudly rather than with a bare [TypeError] or
  /// [StateError].
  factory CastEvent.fromMap(Map<Object?, Object?> map) {
    final rawType = map['type'];
    if (rawType is! String) {
      throw FormatException(
        'CastEvent.fromMap: missing or non-string "type" field: $rawType',
      );
    }
    CastEventType? type;
    for (final value in CastEventType.values) {
      if (value.name == rawType) {
        type = value;
        break;
      }
    }
    if (type == null) {
      throw FormatException(
        'CastEvent.fromMap: unrecognized "type" value: $rawType',
      );
    }
    return CastEvent(
      type: type,
      deviceName: map['deviceName'] as String?,
      lastPositionMs: map['lastPositionMs'] as int?,
      reason: map['reason'] as String?,
    );
  }
}
