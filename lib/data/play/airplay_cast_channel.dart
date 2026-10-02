import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'cast_event.dart';

part 'airplay_cast_channel.g.dart';

/// Thin wrapper around the native macOS `AirPlayCastEngine` (see
/// `macos/Runner/AirPlayCastEngine.swift` and
/// `macos/Runner/AirPlayButtonOverlay.swift`), bridged via a
/// `MethodChannel` (Flutter -> native commands) and an `EventChannel`
/// (native -> Flutter lifecycle events). See
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §2 for
/// the full channel surface this mirrors.
class AirPlayCastChannel {
  AirPlayCastChannel({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _methodChannel =
          methodChannel ?? const MethodChannel('animeko/airplay_cast'),
      _eventChannel =
          eventChannel ?? const EventChannel('animeko/airplay_cast_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  /// Starts casting [url] (with [headers], if any) on the native cast
  /// `AVPlayer`, seeking to [positionMs] before playing.
  Future<void> startCast({
    required String url,
    required Map<String, String> headers,
    required int positionMs,
  }) async {
    await _methodChannel.invokeMethod('startCast', {
      'url': url,
      'headers': headers,
      'positionMs': positionMs,
    });
  }

  Future<void> play() async {
    await _methodChannel.invokeMethod('play');
  }

  Future<void> pause() async {
    await _methodChannel.invokeMethod('pause');
  }

  Future<void> seek(int positionMs) async {
    await _methodChannel.invokeMethod('seek', {'positionMs': positionMs});
  }

  /// Reports the on-screen frame of the Flutter-side `AirPlayButton`
  /// placeholder so the native floating `AVRoutePickerView`-hosting
  /// `NSView` can be positioned to match exactly.
  Future<void> setButtonFrame({
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    await _methodChannel.invokeMethod('setButtonFrame', {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
  }

  Future<void> setButtonVisible(bool visible) async {
    await _methodChannel.invokeMethod('setButtonVisible', {'visible': visible});
  }

  /// Broadcast stream of native cast lifecycle events.
  Stream<CastEvent> get events => _eventChannel.receiveBroadcastStream().map(
    (raw) => CastEvent.fromMap(raw as Map<Object?, Object?>),
  );
}

@riverpod
AirPlayCastChannel airPlayCastChannel(Ref ref) => AirPlayCastChannel();
