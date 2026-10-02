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

    test(
      'startCast invokes the method channel with url/headers/positionMs',
      () async {
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
      },
    );

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

    test(
      'setButtonFrame invokes the method channel with x/y/width/height',
      () async {
        await channel.setButtonFrame(x: 1, y: 2, width: 3, height: 4);
        expect(calls.single.method, 'setButtonFrame');
        expect(calls.single.arguments, {
          'x': 1.0,
          'y': 2.0,
          'width': 3.0,
          'height': 4.0,
        });
      },
    );

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
