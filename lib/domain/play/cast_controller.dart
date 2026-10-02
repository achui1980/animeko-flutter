import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/play/airplay_cast_channel.dart';
import '../../data/play/cast_event.dart';
import 'cast_state.dart';

part 'cast_controller.g.dart';

/// Reacts to native `AirPlayCastEngine` lifecycle events (via
/// [airPlayCastChannelProvider]) and exposes the current [CastState] to
/// `PlayerScreen`. See
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §7
/// "状态同步与交互流程" for the full state-transition narrative this
/// implements.
@riverpod
class CastController extends _$CastController {
  @override
  CastState build() {
    // This controller must keep listening to native cast lifecycle events
    // even while no widget is watching it (e.g. between the player screen
    // being popped and the next time it's pushed), so it must not be torn
    // down by the default autoDispose behavior.
    ref.keepAlive();
    final channel = ref.watch(airPlayCastChannelProvider);
    final subscription = channel.events.listen(
      _handleEvent,
      onError: _handleStreamError,
    );
    ref.onDispose(subscription.cancel);
    return const CastState(status: CastStatus.idle);
  }

  void _handleEvent(CastEvent event) {
    switch (event.type) {
      case CastEventType.activated:
        state = CastState(
          status: CastStatus.casting,
          deviceName: event.deviceName,
        );
      case CastEventType.deactivated:
        state = CastState.idle(lastKnownPositionMs: event.lastPositionMs);
      case CastEventType.failed:
        state = CastState(
          status: CastStatus.failed,
          errorMessage: event.reason,
        );
    }
  }

  /// Converts a stream error (e.g. [CastEvent.fromMap] throwing
  /// [FormatException] on a malformed native payload) into a user-visible
  /// [CastStatus.failed] state, instead of letting it become an unhandled
  /// stream error swallowed by the zone.
  void _handleStreamError(Object error, StackTrace stackTrace) {
    state = CastState(
      status: CastStatus.failed,
      errorMessage: error.toString(),
    );
  }
}
