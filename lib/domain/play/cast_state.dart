/// Which phase of the AirPlay cast lifecycle the app is currently in.
/// See `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4.
enum CastStatus { idle, casting, failed }

/// Current AirPlay cast state, driven entirely by native
/// `AirPlayCastEngine` lifecycle events (see `CastController`). There is
/// no app-initiated "stop" — [CastStatus.idle] is reached only via a
/// native `deactivated` event (user disconnected via the system's own
/// AirPlay route picker, or the connection dropped).
class CastState {
  const CastState({
    required this.status,
    this.deviceName,
    this.errorMessage,
    this.lastKnownPositionMs,
  });

  const CastState.idle({int? lastKnownPositionMs})
    : this(status: CastStatus.idle, lastKnownPositionMs: lastKnownPositionMs);

  final CastStatus status;

  /// Populated while [status] is [CastStatus.casting]: the Core-Audio
  /// resolved (or fallback) display name of the connected receiver.
  final String? deviceName;

  /// Populated while [status] is [CastStatus.failed]: a user-facing
  /// description of why native playback failed, used verbatim in the
  /// `SnackBar` shown by `PlayerScreen`.
  final String? errorMessage;

  /// Populated on the [CastStatus.idle] instance that follows a
  /// `deactivated` event: the cast `AVPlayer`'s last reported position
  /// in milliseconds, so `PlayerScreen` can resume local playback at
  /// exactly that position instead of wherever it left off locally.
  final int? lastKnownPositionMs;
}
