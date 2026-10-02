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

    test(
      'an activated event transitions to casting with the device name',
      () async {
        container.read(castControllerProvider);
        eventController.add(
          const CastEvent(type: CastEventType.activated, deviceName: '客厅电视'),
        );
        await Future<void>.delayed(Duration.zero);

        final state = container.read(castControllerProvider);
        expect(state.status, CastStatus.casting);
        expect(state.deviceName, '客厅电视');
      },
    );

    test(
      'a deactivated event transitions to idle with the last position',
      () async {
        container.read(castControllerProvider);
        eventController.add(
          const CastEvent(type: CastEventType.activated, deviceName: '客厅电视'),
        );
        await Future<void>.delayed(Duration.zero);
        eventController.add(
          const CastEvent(
            type: CastEventType.deactivated,
            lastPositionMs: 42000,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final state = container.read(castControllerProvider);
        expect(state.status, CastStatus.idle);
        expect(state.lastKnownPositionMs, 42000);
      },
    );

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
