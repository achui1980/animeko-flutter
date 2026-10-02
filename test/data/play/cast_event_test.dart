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
