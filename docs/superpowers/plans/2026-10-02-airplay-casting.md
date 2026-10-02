# AirPlay Casting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-app AirPlay casting button to the player screen that lets users send supported sources' video to an AirPlay receiver (Apple TV / AirPlay-capable smart TV), with local playback controls still usable while casting.

**Architecture:** A dedicated native macOS Swift engine (`AirPlayCastEngine`) wraps a second, cast-only `AVPlayer` instance and exposes it to Flutter over a `MethodChannel`/`EventChannel` pair. Device selection uses `AVKit`'s `AVRoutePickerView`, hosted as a native floating `NSView` layered directly on the window's content view (NOT a registered `FlutterPlatformViewFactory` — macOS platform-view gesture passthrough is documented by Flutter itself as unreliable, see Task 5). The Flutter-side `AirPlayButton` widget is a measurement-and-visibility proxy: it reserves layout space and reports its on-screen frame/visibility to native, which positions the real floating button to match. A new `CastController` Riverpod provider holds cast state (idle/casting/failed); `PlayerScreen` reacts to its transitions to swap between the local `media_kit` video and a `CastPlaceholder` widget, forwarding play/pause/seek taps to the native `AVPlayer` while casting.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4, Riverpod 3.3.1 (`@riverpod` codegen), `package:flutter/services.dart` (`MethodChannel`/`EventChannel`, already available, no pubspec change), Swift/AppKit/AVKit/CoreAudio (macOS native, `macos/Runner/`), `mocktail` for Dart-side mocks, `flutter_test` for widget/platform-channel tests.

**Spec:** `docs/superpowers/specs/2026-10-02-airplay-casting-design.md`

## Global Constraints

- Castable sources (allow-list, exact 5 concrete types): `XifanPlaybackSource`, `AgedmPlaybackSource`, `OmofunPlaybackSource` (fully supported — no headers or proxy-bypass issues over AirPlay URL-mode), `YinghuaPlaybackSource`, `DilidiliPlaybackSource` (best-effort — Referer header unconfirmed-necessary; graceful failure handling required).
- Excluded sources (never show the cast button): `Anime1PlaybackSource` (confirmed session-cookie 403 blocker — AirPlay URL-mode cannot carry the required `Cookie` header), `TorrentPlaybackSource` (BT/Mikan — explicit user scope decision), `LocalFilePlaybackSource` (downloaded files, including NAS-mounted-as-path — explicit user scope decision). This is implemented as an allow-list (`is` checks against the 5 castable types only) so these three — and any future unknown `MediaPlaybackSource` subtype — are excluded automatically with no explicit code referencing them.
- No new pub.dev dependency is added for this feature — no Flutter package exists for macOS AirPlay (confirmed: `flutter_to_airplay`/`airplay_button`/`audio_router` are iOS-only).
- Cast button is **fully hidden** (not grayed out) for non-castable sources — no dead/disabled button is ever shown.
- No `stopCast` method exists — a cast session ends only via the native `AVPlayer.isExternalPlaybackActive` flag going false (user disconnects via the system's own AirPlay route picker, or the network drops). There is no public API to force-end an AirPlay route from the sending side.
- Native AVPlayer + real AirPlay device behavior is **manual-test-only** (no physical AirPlay receiver available for automation) — Tasks 4, 5, 6 have no automated test; Task 11 is the manual verification checklist.
- Every new `@riverpod`-annotated file requires `dart run build_runner build --delete-conflicting-outputs` before it compiles — each task that adds one includes this as its own explicit step.

---

### Task 1: Cast eligibility allow-list

**Files:**
- Create: `lib/domain/play/cast_eligibility.dart`
- Test: `test/domain/play/cast_eligibility_test.dart`

**Interfaces:**
- Consumes: `MediaPlaybackSource` (`lib/domain/media/media_source.dart`), `XifanPlaybackSource` (`lib/data/xifan/xifan_models.dart`), `AgedmPlaybackSource` (`lib/data/agedm/agedm_models.dart`), `OmofunPlaybackSource` (`lib/data/omofun/omofun_models.dart`), `YinghuaPlaybackSource` (`lib/data/yinghua/yinghua_models.dart`), `DilidiliPlaybackSource` (`lib/data/dilidili/dilidili_models.dart`).
- Produces: `bool isCastable(MediaPlaybackSource source)` — used by Task 7 (`AirPlayButton.visible`) and Task 10 (`PlayerScreen` build).

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/play/cast_eligibility_test.dart
import 'package:animeko_flutter/data/agedm/agedm_models.dart';
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/data/dilidili/dilidili_models.dart';
import 'package:animeko_flutter/data/omofun/omofun_models.dart';
import 'package:animeko_flutter/data/xifan/xifan_models.dart';
import 'package:animeko_flutter/data/yinghua/yinghua_models.dart';
import 'package:animeko_flutter/domain/download/local_file_playback_source.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/cast_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUnknownSource extends MediaPlaybackSource {
  const _FakeUnknownSource();
  @override
  String get url => 'https://example.com/unknown.m3u8';
  @override
  Map<String, String> get headers => const {};
}

void main() {
  group('isCastable', () {
    test('returns true for xifan', () {
      expect(
        isCastable(const XifanPlaybackSource(url: 'https://example.com/a.m3u8')),
        isTrue,
      );
    });

    test('returns true for agedm', () {
      expect(
        isCastable(
          const AgedmPlaybackSource(url: 'https://example.com/a.m3u8', label: null),
        ),
        isTrue,
      );
    });

    test('returns true for omofun', () {
      expect(
        isCastable(
          const OmofunPlaybackSource(url: 'https://example.com/a.m3u8', label: null),
        ),
        isTrue,
      );
    });

    test('returns true for yinghua', () {
      expect(
        isCastable(const YinghuaPlaybackSource(url: 'https://example.com/a.m3u8')),
        isTrue,
      );
    });

    test('returns true for dilidili', () {
      expect(
        isCastable(const DilidiliPlaybackSource(url: 'https://example.com/a.m3u8')),
        isTrue,
      );
    });

    test('returns false for anime1 (confirmed cookie-blocked)', () {
      expect(
        isCastable(const Anime1PlaybackSource(url: 'https://example.com/a.mp4')),
        isFalse,
      );
    });

    test('returns false for a downloaded local file', () {
      expect(isCastable(const LocalFilePlaybackSource('/tmp/a.mp4')), isFalse);
    });

    test('returns false for any other/unknown source type', () {
      expect(isCastable(const _FakeUnknownSource()), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/play/cast_eligibility_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'cast_eligibility.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/play/cast_eligibility.dart
import '../../data/agedm/agedm_models.dart';
import '../../data/dilidili/dilidili_models.dart';
import '../../data/omofun/omofun_models.dart';
import '../../data/xifan/xifan_models.dart';
import '../../data/yinghua/yinghua_models.dart';
import '../media/media_source.dart';

/// Whether [source] can be cast to an AirPlay receiver.
///
/// Deliberately an allow-list, not a block-list: an AirPlay receiver in
/// standard "URL mode" fetches the video directly over the network
/// itself and does NOT forward the sending app's custom HTTP headers
/// (see `docs/superpowers/specs/2026-10-02-airplay-casting-design.md`
/// §2 "技术约束"). Only sources confirmed to need no headers, or whose
/// only requirement (direct-connection/no-proxy) is naturally satisfied
/// by the receiver fetching over the LAN itself, are listed here.
///
/// `Anime1PlaybackSource` (confirmed session-cookie 403 without the
/// header), `TorrentPlaybackSource` (BT/Mikan), and
/// `LocalFilePlaybackSource` (downloaded files, including NAS-mounted
/// paths) are excluded by omission — along with any future/unknown
/// `MediaPlaybackSource` subtype — rather than being named here.
bool isCastable(MediaPlaybackSource source) {
  return source is XifanPlaybackSource ||
      source is AgedmPlaybackSource ||
      source is OmofunPlaybackSource ||
      source is YinghuaPlaybackSource ||
      source is DilidiliPlaybackSource;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/play/cast_eligibility_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/play/cast_eligibility.dart test/domain/play/cast_eligibility_test.dart
git commit -m "feat(player): add AirPlay cast eligibility allow-list"
```

---

### Task 2: Cast event model + platform channel wrapper

**Files:**
- Create: `lib/data/play/cast_event.dart`
- Create: `lib/data/play/airplay_cast_channel.dart`
- Test: `test/data/play/cast_event_test.dart`
- Test: `test/data/play/airplay_cast_channel_test.dart`

**Interfaces:**
- Consumes: `package:flutter/services.dart` (`MethodChannel`, `EventChannel`), `package:riverpod_annotation/riverpod_annotation.dart`.
- Produces: `enum CastEventType { activated, deactivated, failed }`, `class CastEvent` (fields: `type`, `deviceName` (String?), `lastPositionMs` (int?), `reason` (String?); `factory CastEvent.fromMap(Map<Object?, Object?> map)`), `class AirPlayCastChannel` (methods: `Future<void> startCast({required String url, required Map<String,String> headers, required int positionMs})`, `Future<void> play()`, `Future<void> pause()`, `Future<void> seek(int positionMs)`, `Future<void> setButtonFrame({required double x, required double y, required double width, required double height})`, `Future<void> setButtonVisible(bool visible)`, `Stream<CastEvent> get events`), `@riverpod AirPlayCastChannel airPlayCastChannel(Ref ref)` — consumed by Task 3's `CastController` and Task 7's `AirPlayButton`.

- [ ] **Step 1: Write the failing test for `CastEvent`**

```dart
// test/data/play/cast_event_test.dart
import 'package:animeko_flutter/data/play/cast_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CastEvent.fromMap', () {
    test('parses an activated event with deviceName', () {
      final event = CastEvent.fromMap({
        'type': 'activated',
        'deviceName': '客厅电视',
      });
      expect(event.type, CastEventType.activated);
      expect(event.deviceName, '客厅电视');
    });

    test('parses a deactivated event with lastPositionMs', () {
      final event = CastEvent.fromMap({
        'type': 'deactivated',
        'lastPositionMs': 123456,
      });
      expect(event.type, CastEventType.deactivated);
      expect(event.lastPositionMs, 123456);
    });

    test('parses a failed event with reason', () {
      final event = CastEvent.fromMap({
        'type': 'failed',
        'reason': 'The requested URL was not found',
      });
      expect(event.type, CastEventType.failed);
      expect(event.reason, 'The requested URL was not found');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/play/cast_event_test.dart`
Expected: FAIL — `cast_event.dart` doesn't exist yet.

- [ ] **Step 3: Write minimal `CastEvent` implementation**

```dart
// lib/data/play/cast_event.dart

/// Which kind of native cast lifecycle event fired. Mirrors the three
/// cases the `AirPlayCastEngine` native side emits over the
/// `animeko/airplay_cast_events` `EventChannel` (see
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4-5).
enum CastEventType { activated, deactivated, failed }

/// One event from the native AirPlay cast engine.
class CastEvent {
  const CastEvent({required this.type, this.deviceName, this.lastPositionMs, this.reason});

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/play/cast_event_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing test for `AirPlayCastChannel`**

```dart
// test/data/play/airplay_cast_channel_test.dart
import 'package:animeko_flutter/data/play/airplay_cast_channel.dart';
import 'package:animeko_flutter/data/play/cast_event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AirPlayCastChannel', () {
    late AirPlayCastChannel channel;
    late List<MethodCall> calls;
    const methodChannel = MethodChannel('animeko/airplay_cast');
    const eventChannel = EventChannel('animeko/airplay_cast_events');

    setUp(() {
      calls = [];
      channel = AirPlayCastChannel();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    test('startCast invokes the method channel with url/headers/positionMs', () async {
      await channel.startCast(
        url: 'https://example.com/a.m3u8',
        headers: const {'Referer': 'https://example.com/'},
        positionMs: 5000,
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'startCast');
      expect(calls.single.arguments, {
        'url': 'https://example.com/a.m3u8',
        'headers': {'Referer': 'https://example.com/'},
        'positionMs': 5000,
      });
    });

    test('play invokes the method channel with no args', () async {
      await channel.play();
      expect(calls.single.method, 'play');
      expect(calls.single.arguments, isNull);
    });

    test('pause invokes the method channel with no args', () async {
      await channel.pause();
      expect(calls.single.method, 'pause');
      expect(calls.single.arguments, isNull);
    });

    test('seek invokes the method channel with positionMs', () async {
      await channel.seek(9000);
      expect(calls.single.method, 'seek');
      expect(calls.single.arguments, {'positionMs': 9000});
    });

    test('setButtonFrame invokes the method channel with x/y/width/height', () async {
      await channel.setButtonFrame(x: 1, y: 2, width: 3, height: 4);
      expect(calls.single.method, 'setButtonFrame');
      expect(calls.single.arguments, {
        'x': 1.0,
        'y': 2.0,
        'width': 3.0,
        'height': 4.0,
      });
    });

    test('setButtonVisible invokes the method channel with visible', () async {
      await channel.setButtonVisible(true);
      expect(calls.single.method, 'setButtonVisible');
      expect(calls.single.arguments, {'visible': true});
    });

    test('events stream parses incoming EventChannel payloads', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            eventChannel,
            MockStreamHandler.inline(
              onListen: (arguments, events) {
                events.success({'type': 'activated', 'deviceName': '客厅电视'});
              },
            ),
          );

      final event = await channel.events.first;
      expect(event.type, CastEventType.activated);
      expect(event.deviceName, '客厅电视');
    });
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/data/play/airplay_cast_channel_test.dart`
Expected: FAIL — `airplay_cast_channel.dart` doesn't exist yet.

- [ ] **Step 7: Write minimal `AirPlayCastChannel` implementation**

```dart
// lib/data/play/airplay_cast_channel.dart
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
  AirPlayCastChannel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel('animeko/airplay_cast'),
       _eventChannel = eventChannel ?? const EventChannel('animeko/airplay_cast_events');

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

  /// Reports the on-screen frame of the Flutter-side [AirPlayButton]
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
  Stream<CastEvent> get events => _eventChannel
      .receiveBroadcastStream()
      .map((raw) => CastEvent.fromMap(raw as Map<Object?, Object?>));
}

@riverpod
AirPlayCastChannel airPlayCastChannel(Ref ref) => AirPlayCastChannel();
```

- [ ] **Step 8: Generate the Riverpod code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/data/play/airplay_cast_channel.g.dart` is generated with no errors.

- [ ] **Step 9: Run tests to verify they pass**

Run: `flutter test test/data/play/cast_event_test.dart test/data/play/airplay_cast_channel_test.dart`
Expected: PASS (3 + 7 tests).

- [ ] **Step 10: Commit**

```bash
git add lib/data/play/cast_event.dart lib/data/play/airplay_cast_channel.dart lib/data/play/airplay_cast_channel.g.dart test/data/play/cast_event_test.dart test/data/play/airplay_cast_channel_test.dart
git commit -m "feat(player): add AirPlay cast event model and platform channel wrapper"
```

---

### Task 3: CastController (Riverpod state machine)

**Files:**
- Create: `lib/domain/play/cast_state.dart`
- Create: `lib/domain/play/cast_controller.dart`
- Test: `test/domain/play/cast_controller_test.dart`

**Interfaces:**
- Consumes: `AirPlayCastChannel`/`airPlayCastChannelProvider` (Task 2), `CastEvent`/`CastEventType` (Task 2).
- Produces: `enum CastStatus { idle, casting, failed }`, `class CastState` (fields: `status`, `deviceName` (String?), `errorMessage` (String?), `lastKnownPositionMs` (int?)), `CastController` (`@riverpod class`, `CastState build()`) — consumed by Task 10's `PlayerScreen`.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/play/cast_controller_test.dart
import 'dart:async';

import 'package:animeko_flutter/data/play/airplay_cast_channel.dart';
import 'package:animeko_flutter/data/play/cast_event.dart';
import 'package:animeko_flutter/domain/play/cast_controller.dart';
import 'package:animeko_flutter/domain/play/cast_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockAirPlayCastChannel extends Mock implements AirPlayCastChannel {}

void main() {
  group('CastController', () {
    late MockAirPlayCastChannel channel;
    late StreamController<CastEvent> eventController;
    late ProviderContainer container;

    setUp(() {
      channel = MockAirPlayCastChannel();
      eventController = StreamController<CastEvent>.broadcast();
      when(() => channel.events).thenAnswer((_) => eventController.stream);
      container = ProviderContainer(
        overrides: [airPlayCastChannelProvider.overrideWith((ref) => channel)],
      );
      addTearDown(container.dispose);
      addTearDown(eventController.close);
    });

    test('build starts in idle state', () {
      final state = container.read(castControllerProvider);
      expect(state.status, CastStatus.idle);
    });

    test('an activated event transitions to casting with the device name', () async {
      container.read(castControllerProvider);
      eventController.add(
        const CastEvent(type: CastEventType.activated, deviceName: '客厅电视'),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(castControllerProvider);
      expect(state.status, CastStatus.casting);
      expect(state.deviceName, '客厅电视');
    });

    test('a deactivated event transitions to idle with the last position', () async {
      container.read(castControllerProvider);
      eventController.add(
        const CastEvent(type: CastEventType.activated, deviceName: '客厅电视'),
      );
      await Future<void>.delayed(Duration.zero);
      eventController.add(
        const CastEvent(type: CastEventType.deactivated, lastPositionMs: 42000),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(castControllerProvider);
      expect(state.status, CastStatus.idle);
      expect(state.lastKnownPositionMs, 42000);
    });

    test('a failed event transitions to failed with the reason', () async {
      container.read(castControllerProvider);
      eventController.add(
        const CastEvent(type: CastEventType.failed, reason: '播放失败'),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(castControllerProvider);
      expect(state.status, CastStatus.failed);
      expect(state.errorMessage, '播放失败');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/play/cast_controller_test.dart`
Expected: FAIL — `cast_state.dart`/`cast_controller.dart` don't exist yet.

- [ ] **Step 3: Write `CastState`**

```dart
// lib/domain/play/cast_state.dart

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
```

- [ ] **Step 4: Write `CastController`**

```dart
// lib/domain/play/cast_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/play/airplay_cast_channel.dart';
import '../../data/play/cast_event.dart';
import 'cast_state.dart';

part 'cast_controller.g.dart';

/// Reacts to native `AirPlayCastEngine` lifecycle events (via
/// [airPlayCastChannelProvider]) and exposes the current [CastState] to
/// `PlayerScreen`. See
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4
/// "状态同步与交互流程" for the full state-transition narrative this
/// implements.
@riverpod
class CastController extends _$CastController {
  @override
  CastState build() {
    final channel = ref.watch(airPlayCastChannelProvider);
    final subscription = channel.events.listen(_handleEvent);
    ref.onDispose(subscription.cancel);
    return const CastState(status: CastStatus.idle);
  }

  void _handleEvent(CastEvent event) {
    switch (event.type) {
      case CastEventType.activated:
        state = CastState(status: CastStatus.casting, deviceName: event.deviceName);
      case CastEventType.deactivated:
        state = CastState.idle(lastKnownPositionMs: event.lastPositionMs);
      case CastEventType.failed:
        state = CastState(status: CastStatus.failed, errorMessage: event.reason);
    }
  }
}
```

- [ ] **Step 5: Generate the Riverpod code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/domain/play/cast_controller.g.dart` is generated with no errors.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/domain/play/cast_controller_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/domain/play/cast_state.dart lib/domain/play/cast_controller.dart lib/domain/play/cast_controller.g.dart test/domain/play/cast_controller_test.dart
git commit -m "feat(player): add CastController state machine"
```

---

### Task 4: Native `AirPlayCastEngine` (AVPlayer wrapper)

**Files:**
- Create: `macos/Runner/AirPlayCastEngine.swift`

**Interfaces:**
- Consumes: `AVFoundation` (`AVPlayer`, `AVPlayerItem`, `AVURLAsset`), `CoreAudio` (`AudioObjectGetPropertyData`), `FlutterMacOS` (`FlutterMethodChannel`, `FlutterEventChannel`, `FlutterEventSink`, `FlutterMethodCall`, `FlutterResult`).
- Produces: `class AirPlayCastEngine: NSObject, FlutterStreamHandler` with `init(methodChannel: FlutterMethodChannel)`, `func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)` (routes `startCast`/`play`/`pause`/`seek`), `func onListen(withArguments:eventSink:) -> FlutterError?` / `func onCancel(withArguments:) -> FlutterError?` (the `FlutterStreamHandler` protocol, for the `EventChannel`) — consumed by Task 6's `MainFlutterWindow.swift`.

- [ ] **Step 1: Write the implementation**

No automated test for this task — native AVPlayer behavior against a real AirPlay receiver cannot be exercised by an automated test in this environment (no physical Apple TV/AirPlay receiver available; see Global Constraints and Task 11's manual checklist).

```swift
// macos/Runner/AirPlayCastEngine.swift
import AVFoundation
import CoreAudio
import FlutterMacOS

/// Wraps a dedicated, cast-only `AVPlayer` and bridges its lifecycle to
/// Flutter over a `MethodChannel` (commands) and `EventChannel`
/// (lifecycle events). This is a second playback engine, entirely
/// separate from the app's primary media_kit/libmpv player — libmpv has
/// no AirPlay support and mpv's own maintainers have explicitly rejected
/// adding it (see
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §2),
/// so AirPlay casting requires this standalone `AVPlayer`-based path.
class AirPlayCastEngine: NSObject, FlutterStreamHandler {
  private let player = AVPlayer()
  private let methodChannel: FlutterMethodChannel
  private var eventSink: FlutterEventSink?
  private var statusObservation: NSKeyValueObservation?
  private var externalPlaybackObservation: NSKeyValueObservation?

  init(methodChannel: FlutterMethodChannel) {
    self.methodChannel = methodChannel
    super.init()
    externalPlaybackObservation = player.observe(\.isExternalPlaybackActive, options: [.new]) {
      [weak self] player, change in
      guard let self = self, let isActive = change.newValue else { return }
      if isActive {
        self.eventSink?([
          "type": "activated",
          "deviceName": self.resolveActiveOutputDeviceName(),
        ])
      } else {
        let positionMs = Int(player.currentTime().seconds * 1000)
        self.eventSink?(["type": "deactivated", "lastPositionMs": positionMs])
      }
    }
  }

  /// Routes Flutter method-channel calls to the matching `AVPlayer`
  /// operation. Registered as `methodChannel.setMethodCallHandler` by
  /// `MainFlutterWindow.swift` (Task 6).
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startCast":
      guard let args = call.arguments as? [String: Any],
        let urlString = args["url"] as? String,
        let url = URL(string: urlString),
        let positionMs = args["positionMs"] as? Int
      else {
        result(FlutterError(code: "bad_args", message: "startCast missing url/positionMs", details: nil))
        return
      }
      let headers = args["headers"] as? [String: String] ?? [:]
      startCast(url: url, headers: headers, positionMs: positionMs)
      result(nil)
    case "play":
      player.play()
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "seek":
      guard let args = call.arguments as? [String: Any],
        let positionMs = args["positionMs"] as? Int
      else {
        result(FlutterError(code: "bad_args", message: "seek missing positionMs", details: nil))
        return
      }
      player.seek(to: CMTime(seconds: Double(positionMs) / 1000, preferredTimescale: 1000))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startCast(url: URL, headers: [String: String], positionMs: Int) {
    statusObservation?.invalidate()
    let options: [String: Any] = headers.isEmpty
      ? [:]
      : ["AVURLAssetHTTPHeaderFieldsKey": headers]
    let asset = AVURLAsset(url: url, options: options)
    let item = AVPlayerItem(asset: asset)
    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard item.status == .failed else { return }
      let reason = item.error?.localizedDescription ?? "未知错误"
      self?.eventSink?(["type": "failed", "reason": reason])
    }
    player.replaceCurrentItem(with: item)
    player.seek(to: CMTime(seconds: Double(positionMs) / 1000, preferredTimescale: 1000)) { [weak self] _ in
      self?.player.play()
    }
  }

  /// Resolves the active AirPlay receiver's display name via Core
  /// Audio: while `isExternalPlaybackActive` is true, the receiver is
  /// the system's default audio output device, so querying that
  /// device's name reflects the connected receiver. Falls back to a
  /// generic label if either Core Audio call fails.
  private func resolveActiveOutputDeviceName() -> String {
    var deviceId = AudioDeviceID(0)
    var deviceIdSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &deviceIdSize, &deviceId
    )
    guard status == noErr else { return "AirPlay 设备" }

    var name: CFString = "" as CFString
    var nameSize = UInt32(MemoryLayout<CFString>.size)
    var nameAddress = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    status = AudioObjectGetPropertyData(deviceId, &nameAddress, 0, nil, &nameSize, &name)
    guard status == noErr else { return "AirPlay 设备" }
    return name as String
  }

  // MARK: FlutterStreamHandler (EventChannel)

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter build macos --debug` (from the repo root)
Expected: Build succeeds with no Swift compiler errors in `AirPlayCastEngine.swift`. (This file is not yet referenced by `MainFlutterWindow.swift`, so it will not be linked into any symbol table check beyond basic compilation until Task 6 — if Xcode/`flutter build` doesn't compile unreferenced files in this target configuration, defer this verification step to Task 6's build check instead.)

- [ ] **Step 3: Commit**

```bash
git add macos/Runner/AirPlayCastEngine.swift
git commit -m "feat(player): add native AirPlayCastEngine AVPlayer wrapper"
```

---

### Task 5: Native floating AirPlay button overlay

**Files:**
- Create: `macos/Runner/AirPlayButtonOverlay.swift`

**Interfaces:**
- Consumes: `AVKit` (`AVRoutePickerView`), `AppKit` (`NSView`, `NSWindow`).
- Produces: `class AirPlayButtonOverlay` with `init(contentView: NSView)` (adds the `AVRoutePickerView`-hosting `NSView` as a subview of `contentView`, initially hidden), `func setFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)`, `func setVisible(_ visible: Bool)` — consumed by Task 6's `MainFlutterWindow.swift`.

- [ ] **Step 1: Write the implementation**

No automated test for this task (native `NSView`/AppKit UI, manual-only — see Task 11).

Rationale for this not being a registered `FlutterPlatformViewFactory`: Flutter's own macOS platform-view docs state gesture support isn't fully functional on macOS as of this project's pinned Flutter SDK (3.41.6), and `AVRoutePickerView` requires a genuine native mouse-down to show its system device picker (there is no public API to trigger it programmatically). Adding the hosting `NSView` directly as a window-content-view subview — outside Flutter's compositing/hit-testing pipeline — sidesteps that immaturity entirely; real native mouse events reach it exactly as for any other AppKit view.

```swift
// macos/Runner/AirPlayButtonOverlay.swift
import AVKit
import AppKit

/// Hosts an `AVRoutePickerView` as a floating overlay directly on the
/// window's content view (a sibling of the `FlutterViewController`'s own
/// view), rather than as a registered Flutter platform view -- see this
/// file's own doc comment context in the implementation plan for why.
/// Positioned/shown/hidden to track the Flutter-side `AirPlayButton`
/// placeholder's on-screen frame, reported via
/// `setButtonFrame`/`setButtonVisible` method-channel calls (see
/// `AirPlayCastEngine`'s sibling wiring in `MainFlutterWindow.swift`).
class AirPlayButtonOverlay {
  private let routePickerView: AVRoutePickerView

  init(contentView: NSView) {
    routePickerView = AVRoutePickerView(frame: .zero)
    routePickerView.isHidden = true
    contentView.addSubview(routePickerView)
  }

  func setFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    routePickerView.frame = NSRect(x: x, y: y, width: width, height: height)
  }

  func setVisible(_ visible: Bool) {
    routePickerView.isHidden = !visible
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter build macos --debug` (from the repo root)
Expected: Build succeeds with no Swift compiler errors (same caveat as Task 4 Step 2 — full verification may need to wait for Task 6's wiring).

- [ ] **Step 3: Commit**

```bash
git add macos/Runner/AirPlayButtonOverlay.swift
git commit -m "feat(player): add native floating AirPlay button overlay"
```

---

### Task 6: Wire channels and native objects in `MainFlutterWindow.swift`

**Files:**
- Modify: `macos/Runner/MainFlutterWindow.swift`

**Interfaces:**
- Consumes: `AirPlayCastEngine` (Task 4), `AirPlayButtonOverlay` (Task 5).
- Produces: a live `FlutterMethodChannel("animeko/airplay_cast")` and `FlutterEventChannel("animeko/airplay_cast_events")` on the running Flutter engine, consumed at runtime by Task 2's `AirPlayCastChannel` from the Dart side.

- [ ] **Step 1: Modify the file**

No automated test for this task — this is pure native wiring, verified by a full macOS build and the Task 11 manual checklist.

```swift
// macos/Runner/MainFlutterWindow.swift
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var airPlayCastEngine: AirPlayCastEngine?
  private var airPlayButtonOverlay: AirPlayButtonOverlay?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let messenger = flutterViewController.engine.binaryMessenger
    let methodChannel = FlutterMethodChannel(name: "animeko/airplay_cast", binaryMessenger: messenger)
    let eventChannel = FlutterEventChannel(name: "animeko/airplay_cast_events", binaryMessenger: messenger)

    let engine = AirPlayCastEngine(methodChannel: methodChannel)
    let overlay = AirPlayButtonOverlay(contentView: flutterViewController.view)

    methodChannel.setMethodCallHandler { call, result in
      if call.method == "setButtonFrame", let args = call.arguments as? [String: Any],
        let x = args["x"] as? Double, let y = args["y"] as? Double,
        let width = args["width"] as? Double, let height = args["height"] as? Double
      {
        overlay.setFrame(x: x, y: y, width: width, height: height)
        result(nil)
        return
      }
      if call.method == "setButtonVisible", let args = call.arguments as? [String: Any],
        let visible = args["visible"] as? Bool
      {
        overlay.setVisible(visible)
        result(nil)
        return
      }
      engine.handle(call, result: result)
    }
    eventChannel.setStreamHandler(engine)

    self.airPlayCastEngine = engine
    self.airPlayButtonOverlay = overlay

    super.awakeFromNib()
  }
}
```

- [ ] **Step 2: Build the macOS app**

Run: `flutter build macos --debug` (from the repo root)
Expected: Build succeeds with no errors. This is the first point at which `AirPlayCastEngine.swift` and `AirPlayButtonOverlay.swift` are actually referenced/linked — if Task 4 or 5 had any compile error that didn't surface earlier, it will surface here.

- [ ] **Step 3: Commit**

```bash
git add macos/Runner/MainFlutterWindow.swift
git commit -m "feat(player): wire AirPlay cast channels in MainFlutterWindow"
```

---

### Task 7: `AirPlayButton` Flutter widget (measurement-and-visibility proxy)

**Files:**
- Create: `lib/ui/player/airplay_button.dart`
- Test: `test/ui/player/airplay_button_test.dart`

**Interfaces:**
- Consumes: `airPlayCastChannelProvider` (Task 2).
- Produces: `class AirPlayButton extends ConsumerStatefulWidget` with constructor `AirPlayButton({super.key, required this.visible})` — consumed by Task 8's `PlayerTopBar`.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/player/airplay_button_test.dart
import 'package:animeko_flutter/data/play/airplay_cast_channel.dart';
import 'package:animeko_flutter/ui/player/airplay_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAirPlayCastChannel extends Mock implements AirPlayCastChannel {}

void main() {
  late MockAirPlayCastChannel channel;

  setUp(() {
    channel = MockAirPlayCastChannel();
    when(() => channel.events).thenAnswer((_) => const Stream.empty());
    when(
      () => channel.setButtonFrame(
        x: any(named: 'x'),
        y: any(named: 'y'),
        width: any(named: 'width'),
        height: any(named: 'height'),
      ),
    ).thenAnswer((_) async {});
    when(() => channel.setButtonVisible(any())).thenAnswer((_) async {});
  });

  Widget buildButton({required bool visible}) {
    return ProviderScope(
      overrides: [airPlayCastChannelProvider.overrideWith((ref) => channel)],
      child: MaterialApp(
        home: Scaffold(body: AirPlayButton(visible: visible)),
      ),
    );
  }

  testWidgets('reports setButtonVisible(true) once laid out when visible', (
    tester,
  ) async {
    await tester.pumpWidget(buildButton(visible: true));
    await tester.pumpAndSettle();

    verify(() => channel.setButtonVisible(true)).called(greaterThanOrEqualTo(1));
    verify(
      () => channel.setButtonFrame(
        x: any(named: 'x'),
        y: any(named: 'y'),
        width: any(named: 'width'),
        height: any(named: 'height'),
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('reports setButtonVisible(false) when not visible', (tester) async {
    await tester.pumpWidget(buildButton(visible: false));
    await tester.pumpAndSettle();

    verify(() => channel.setButtonVisible(false)).called(greaterThanOrEqualTo(1));
    verifyNever(
      () => channel.setButtonFrame(
        x: any(named: 'x'),
        y: any(named: 'y'),
        width: any(named: 'width'),
        height: any(named: 'height'),
      ),
    );
  });

  testWidgets('reports setButtonVisible(false) on dispose', (tester) async {
    await tester.pumpWidget(buildButton(visible: true));
    await tester.pumpAndSettle();
    clearInteractions(channel);

    await tester.pumpWidget(const SizedBox());

    verify(() => channel.setButtonVisible(false)).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/player/airplay_button_test.dart`
Expected: FAIL — `airplay_button.dart` doesn't exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/ui/player/airplay_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/play/airplay_cast_channel.dart';

/// Reserves layout space for the native floating AirPlay button (see
/// `macos/Runner/AirPlayButtonOverlay.swift`) and reports this widget's
/// on-screen frame/visibility to native so the real `AVRoutePickerView`
/// can be positioned to match -- this widget itself renders nothing
/// visible. See
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §2 for
/// why a true embedded platform view isn't used instead.
///
/// [visible] should be `false` whenever the current playback candidate
/// isn't cast-eligible (see `isCastable` in
/// `lib/domain/play/cast_eligibility.dart`) -- the native button is
/// fully hidden, not grayed out, in that case.
class AirPlayButton extends ConsumerStatefulWidget {
  const AirPlayButton({super.key, required this.visible});

  final bool visible;

  @override
  ConsumerState<AirPlayButton> createState() => _AirPlayButtonState();
}

class _AirPlayButtonState extends ConsumerState<AirPlayButton> {
  final _key = GlobalKey();

  @override
  void didUpdateWidget(AirPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    ref.read(airPlayCastChannelProvider).setButtonVisible(false);
    super.dispose();
  }

  void _report() {
    final channel = ref.read(airPlayCastChannelProvider);
    unawaited(channel.setButtonVisible(widget.visible));
    if (!widget.visible) return;
    final renderObject = _key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final offset = renderObject.localToGlobal(Offset.zero);
    unawaited(
      channel.setButtonFrame(
        x: offset.dx,
        y: offset.dy,
        width: renderObject.size.width,
        height: renderObject.size.height,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return SizedBox(key: _key, width: 44, height: 44);
  }
}
```

- [ ] **Step 4: Add the missing `unawaited` import**

The implementation above uses `unawaited`, which comes from `dart:async`. Add this import to the top of `lib/ui/player/airplay_button.dart`:

```dart
import 'dart:async';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/ui/player/airplay_button_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/player/airplay_button.dart test/ui/player/airplay_button_test.dart
git commit -m "feat(player): add AirPlayButton measurement-and-visibility proxy widget"
```

---

### Task 8: Add the AirPlay button slot to `PlayerTopBar`

**Files:**
- Modify: `lib/ui/player/player_top_bar.dart`
- Test: Modify `test/ui/player/player_top_bar_test.dart`

**Interfaces:**
- Consumes: `AirPlayButton` (Task 7).
- Produces: `PlayerTopBar` now takes an additional required `castButtonVisible: bool` param — consumed by Task 10's `PlayerScreen`.

- [ ] **Step 1: Write the failing test**

Add this test to the end of the existing `test/ui/player/player_top_bar_test.dart`, inside `main()`, after the two existing `testWidgets` blocks (keep the existing two tests unchanged, just update their `PlayerTopBar(...)` constructor calls to also pass `castButtonVisible: true` so they keep compiling — see Step 1b):

```dart
// Added to test/ui/player/player_top_bar_test.dart
  testWidgets('shows the AirPlay button slot when castButtonVisible is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PlayerTopBar(
              title: '测试标题',
              onBack: () {},
              onScreenshot: () {},
              castButtonVisible: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AirPlayButton), findsOneWidget);
  });
```

Step 1b: update the two existing `testWidgets` blocks' `PlayerTopBar(...)` constructor invocations (both inside `MaterialApp(home: Scaffold(body: PlayerTopBar(...)))`) to add `castButtonVisible: true,` as an argument, and wrap both existing `tester.pumpWidget(MaterialApp(...))` calls in a `ProviderScope(child: ...)` (since `AirPlayButton` is a `ConsumerStatefulWidget` and now always renders inside `PlayerTopBar`). Also add these two imports to the top of the test file:

```dart
import 'package:animeko_flutter/ui/player/airplay_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/player/player_top_bar_test.dart`
Expected: FAIL — `castButtonVisible` is not a parameter of `PlayerTopBar` yet (compile error).

- [ ] **Step 3: Modify `PlayerTopBar`**

```dart
// lib/ui/player/player_top_bar.dart
import 'package:flutter/material.dart';

import 'airplay_button.dart';

/// Custom top bar for [PlayerScreen], replacing the floating back button
/// that used to sit alone in the top-left corner.
///
/// The download button that used to live here has moved to
/// [PlayerBottomBar] (see the download UX overhaul design doc's decision
/// that neither the player's nor the subject page's download entry point
/// belongs in a top-right corner) -- [DownloadButtonState] now lives in
/// `download_badge_button.dart`, shared by the bottom bar, the subject
/// detail page, and the home screen.
///
/// Purely prop-driven so it is testable without a real [Player] or
/// Riverpod [ProviderScope] -- except for [AirPlayButton] itself, which
/// is a [ConsumerStatefulWidget] (see `airplay_button.dart`), so callers
/// must still wrap this widget in a [ProviderScope] in tests.
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onScreenshot,
    required this.castButtonVisible,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onScreenshot;

  /// Whether the current playback candidate is cast-eligible (see
  /// `isCastable` in `lib/domain/play/cast_eligibility.dart`). The
  /// AirPlay button is fully hidden, not grayed out, when false.
  final bool castButtonVisible;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: '返回',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AirPlayButton(visible: castButtonVisible),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              tooltip: '截图',
              onPressed: onScreenshot,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/player/player_top_bar_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/player_top_bar.dart test/ui/player/player_top_bar_test.dart
git commit -m "feat(player): add AirPlay button slot to PlayerTopBar"
```

---

### Task 9: `CastPlaceholder` widget ("正在投屏到 XXX" page)

**Files:**
- Create: `lib/ui/player/cast_placeholder.dart`
- Test: `test/ui/player/cast_placeholder_test.dart`

**Interfaces:**
- Consumes: nothing beyond `package:flutter/material.dart` — purely prop-driven, like `PlayerBottomBar`.
- Produces: `class CastPlaceholder extends StatelessWidget` with constructor `CastPlaceholder({super.key, required this.deviceName, required this.isPlaying, required this.position, required this.duration, required this.onPlayPause, required this.onSeek})` — consumed by Task 10's `PlayerScreen`.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/player/cast_placeholder_test.dart
import 'package:animeko_flutter/ui/player/cast_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildPlaceholder({
    String deviceName = '客厅电视',
    bool isPlaying = false,
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 10),
    VoidCallback? onPlayPause,
    ValueChanged<Duration>? onSeek,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CastPlaceholder(
          deviceName: deviceName,
          isPlaying: isPlaying,
          position: position,
          duration: duration,
          onPlayPause: onPlayPause ?? () {},
          onSeek: onSeek ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('shows the casting-to-device message', (tester) async {
    await tester.pumpWidget(buildPlaceholder(deviceName: '客厅电视'));
    expect(find.text('正在投屏到 客厅电视'), findsOneWidget);
  });

  testWidgets('shows play icon when paused and pause icon when playing', (
    tester,
  ) async {
    await tester.pumpWidget(buildPlaceholder(isPlaying: false));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.pumpWidget(buildPlaceholder(isPlaying: true));
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('tapping play/pause invokes onPlayPause', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildPlaceholder(onPlayPause: () => tapped = true));

    await tester.tap(find.byIcon(Icons.play_arrow));

    expect(tapped, isTrue);
  });

  testWidgets('dragging the progress bar invokes onSeek', (tester) async {
    Duration? seekedTo;
    await tester.pumpWidget(
      buildPlaceholder(
        duration: const Duration(minutes: 10),
        onSeek: (value) => seekedTo = value,
      ),
    );

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(50, 0));

    expect(seekedTo, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/player/cast_placeholder_test.dart`
Expected: FAIL — `cast_placeholder.dart` doesn't exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/ui/player/cast_placeholder.dart
import 'package:flutter/material.dart';

/// Shown in place of the local `media_kit` video while
/// `CastController`'s state is [CastStatus.casting] (see
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4
/// step 4). Play/pause/seek here are forwarded to the native cast
/// `AVPlayer` by `PlayerScreen`, not applied to the local player.
///
/// Purely prop-driven, mirroring [PlayerBottomBar]'s testable shape.
class CastPlaceholder extends StatelessWidget {
  const CastPlaceholder({
    super.key,
    required this.deviceName,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
  });

  final String deviceName;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cast_connected, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            '正在投屏到 $deviceName',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
            onPressed: onPlayPause,
          ),
          SizedBox(
            width: 320,
            child: Slider(
              value: position.inMilliseconds
                  .clamp(0, duration.inMilliseconds)
                  .toDouble(),
              max: duration.inMilliseconds > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1,
              onChanged: (value) =>
                  onSeek(Duration(milliseconds: value.round())),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/player/cast_placeholder_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/cast_placeholder.dart test/ui/player/cast_placeholder_test.dart
git commit -m "feat(player): add CastPlaceholder widget"
```

---

### Task 10: Integrate casting into `PlayerScreen`

**Files:**
- Modify: `lib/ui/player/player_screen.dart`

**Interfaces:**
- Consumes: `isCastable` (Task 1), `castControllerProvider`/`CastState`/`CastStatus` (Task 3), `airPlayCastChannelProvider` (Task 2), `CastPlaceholder` (Task 9), `PlayerTopBar(castButtonVisible: ...)` (Task 8).
- Produces: no new public interface — this is the final integration task, there are no later tasks consuming anything new from here.

No automated widget test for this task: `PlayerScreen` is already untested at the full-screen level in this codebase (verified: no `test/ui/player/player_screen_test.dart` exists; it depends on a real `media_kit` `Player`, which cannot be constructed in `flutter_test`'s environment). This task's correctness is covered by Task 11's manual checklist, plus the fact that every unit it wires together (`isCastable`, `CastController`, `CastPlaceholder`, `AirPlayButton`) already has its own passing automated test from Tasks 1, 3, 7, 9.

- [ ] **Step 1: Add imports**

At the top of `lib/ui/player/player_screen.dart`, add:

```dart
import '../../data/play/airplay_cast_channel.dart';
import '../../domain/play/cast_controller.dart';
import '../../domain/play/cast_eligibility.dart';
import '../../domain/play/cast_state.dart';
import 'cast_placeholder.dart';
```

(Adjust relative import paths if the existing import block in this file uses a different style — match whatever the surrounding imports already use, e.g. `package:animeko_flutter/...` vs relative `../../...`; check the top of the file before adding these.)

- [ ] **Step 2: Add the `ref.listen(castControllerProvider, ...)` side effect**

In `build(BuildContext context)`, immediately after the existing `ref.listen(provider, (previous, next) { ... });` block (ending at line 821 in the pre-change file, right before `final playback = ref.watch(provider);`), add:

```dart
    ref.listen(castControllerProvider, (previous, next) {
      final channel = ref.read(airPlayCastChannelProvider);
      if (next.status == CastStatus.casting &&
          previous?.status != CastStatus.casting) {
        final candidates = _candidates;
        if (candidates == null) return;
        final current = candidates[_candidateIndex];
        unawaited(() async {
          final playableUrl = await current.prepare();
          await channel.startCast(
            url: playableUrl,
            headers: current.headers,
            positionMs: _player.state.position.inMilliseconds,
          );
        }());
        unawaited(_player.pause());
      } else if (previous?.status == CastStatus.casting &&
          next.status == CastStatus.idle) {
        final resumeMs = next.lastKnownPositionMs;
        if (resumeMs != null) {
          unawaited(_player.seek(Duration(milliseconds: resumeMs)));
        }
        unawaited(_player.play());
      } else if (next.status == CastStatus.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage ?? '投屏失败，该来源可能不支持投屏，可尝试切换片源',
            ),
          ),
        );
        unawaited(_player.play());
      }
    });
```

- [ ] **Step 3: Compute cast eligibility for the current candidate**

Immediately after the `ref.listen(castControllerProvider, ...)` block added in Step 2 (still inside `build()`, before `final playback = ref.watch(provider);`), add:

```dart
    final currentCandidate = _candidates != null && _candidates!.isNotEmpty
        ? _candidates![_candidateIndex]
        : null;
    final castButtonVisible =
        currentCandidate != null && isCastable(currentCandidate);
    final castState = ref.watch(castControllerProvider);
```

- [ ] **Step 4: Pass `castButtonVisible` to `PlayerTopBar`**

Find the existing `PlayerTopBar(...)` construction (inside the `if (_controlsVisible) Positioned(... child: PlayerTopBar(...))` block) and add the new required parameter:

```dart
                      child: PlayerTopBar(
                        title:
                            '${widget.subjectName} · ${_currentEpisode.title}',
                        onBack: () => Navigator.of(context).pop(),
                        onScreenshot: _takeScreenshot,
                        castButtonVisible: castButtonVisible,
                      ),
```

- [ ] **Step 5: Swap in `CastPlaceholder` while casting**

Find the `data: (_) => _playbackError != null ? ErrorRetryView(...) : Stack(children: [Video(...), if (_isBuffering) ...])` branch inside `playback.when(...)`. Change the ternary's second branch so it checks cast status first:

```dart
                    data: (_) => _playbackError != null
                        ? ErrorRetryView(
                            message: '播放失败：$_playbackError',
                            onRetry: _retry,
                          )
                        : castState.status == CastStatus.casting
                        ? CastPlaceholder(
                            deviceName: castState.deviceName ?? 'AirPlay 设备',
                            isPlaying: _player.state.playing,
                            position: _player.state.position,
                            duration: _player.state.duration,
                            onPlayPause: () {
                              final channel = ref.read(
                                airPlayCastChannelProvider,
                              );
                              if (_player.state.playing) {
                                unawaited(channel.pause());
                              } else {
                                unawaited(channel.play());
                              }
                            },
                            onSeek: (value) => unawaited(
                              ref
                                  .read(airPlayCastChannelProvider)
                                  .seek(value.inMilliseconds),
                            ),
                          )
                        // media_kit_video's default AdaptiveVideoControls is
                        // disabled (controls: NoVideoControls) -- this app
                        // renders its own custom top/bottom control bars
                        // instead (see PlayerTopBar/PlayerBottomBar).
                        //
                        // `_isBuffering` overlay covers the gap between
                        // `episodePlayControllerProvider` resolving a
                        // playback URL (this `data` branch) and
                        // media_kit actually opening/buffering that URL
                        // and rendering a first frame -- without it, the
                        // screen would otherwise go black with no
                        // indication that it's still loading (also
                        // covers mid-playback rebuffering stalls).
                        : Stack(
                            children: [
                              Video(
                                controller: _controller,
                                controls: NoVideoControls,
                              ),
                              if (_isBuffering)
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            ],
                          ),
```

Note: `CastPlaceholder`'s `isPlaying`/`position`/`duration` read `_player.state.*` once per `build()` rather than via `StreamBuilder` like `PlayerBottomBar` does — this is an intentional simplification since the placeholder's play/pause/seek operate on the native cast player, not the local one, so sub-second local-state staleness while casting is not pointed out as a defect by the spec and is acceptable; `PlayerBottomBar` remains driven by the live `StreamBuilder` chain unchanged for local playback.

- [ ] **Step 6: Add the `setButtonVisible(false)` safety net to `dispose()`**

In the existing `dispose()` method, add a line right before `unawaited(_disposePlayer());`:

```dart
    unawaited(ref.read(airPlayCastChannelProvider).setButtonVisible(false));
    unawaited(_disposePlayer());
```

- [ ] **Step 7: Verify the app still builds and the existing test suite passes**

Run: `flutter analyze`
Expected: no new errors (pre-existing infos are fine per `AGENTS.md`).

Run: `flutter test`
Expected: all existing tests pass (full suite, ~359+ tests given the new tests added in Tasks 1-3 and 7-9).

- [ ] **Step 8: Commit**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "feat(player): integrate AirPlay casting into PlayerScreen"
```

---

### Task 11: Manual QA checklist (real AirPlay device verification)

**Files:**
- Create: `docs/superpowers/plans/2026-10-02-airplay-casting-manual-qa.md`

**Interfaces:** None — documentation-only task, no code.

This satisfies the spec's §9 "测试策略" requirement that native `AVPlayer`+real-AirPlay-device behavior is manual-test-only (no physical Apple TV/AirPlay receiver is available for automation in this environment).

- [ ] **Step 1: Write the manual QA checklist document**

```markdown
# AirPlay Casting — Manual QA Checklist

Run on a real Mac with a real AirPlay receiver (Apple TV or AirPlay-capable
smart TV) available on the same network. None of this is automatable (no
physical receiver in CI/dev-sandbox environments) — see
`docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §9.

Build and run first: `flutter build macos --release` (or `flutter run -d macos`),
then for each item below, play an episode from the relevant source and tap the
AirPlay icon in the player's top bar.

## Castable sources — verify casting works

- [ ] **xifan**: cast starts, video plays on the receiver, no error.
- [ ] **agedm**: cast starts, video plays on the receiver, no error.
- [ ] **omofun**: cast starts, video plays on the receiver, no error.
- [ ] **yinghua**: cast starts and plays (best-effort — if it fails with a
      403/hotlink error, that confirms the Referer header is in fact required
      and the graceful-failure path below is what should be observed instead).
- [ ] **dilidili**: same as yinghua above.

## Placeholder page controls (while casting, for any one source above)

- [ ] The local window switches to the "正在投屏到 <device name>" placeholder;
      the device name shown matches the real receiver's name.
- [ ] Tapping play/pause on the placeholder pauses/resumes playback on the
      receiver (not on the (hidden) local player).
- [ ] Dragging the placeholder's progress slider seeks playback on the
      receiver.

## Graceful failure (yinghua or dilidili, if either fails to play on the receiver)

- [ ] A SnackBar with an error message appears ("投屏失败，该来源可能不支持投屏，
      可尝试切换片源" or the native failure reason).
- [ ] Local playback automatically resumes after the failure (window returns
      to the normal video view, not stuck on the placeholder).

## Hidden-button sources — verify the button is absent, not disabled

- [ ] **anime1**: no AirPlay icon appears in the top bar at all.
- [ ] **BT/Mikan** source: no AirPlay icon appears in the top bar at all.
- [ ] **Downloaded local file** playback: no AirPlay icon appears in the top
      bar at all.

## Disconnect / navigation recovery

- [ ] While casting, open the system AirPlay menu and disconnect (select
      "此 Mac") — local playback resumes automatically from the position the
      receiver had reached.
- [ ] While casting, physically turn off/disconnect the receiver from the
      network — the app does not get stuck on the placeholder page (same
      automatic local-resume behavior as the explicit disconnect above).
- [ ] While casting, navigate back out of the player screen (tap the back
      button) — the native floating AirPlay button does not remain visible
      as an orphaned overlay over the rest of the app.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-10-02-airplay-casting-manual-qa.md
git commit -m "docs: add AirPlay casting manual QA checklist"
```
