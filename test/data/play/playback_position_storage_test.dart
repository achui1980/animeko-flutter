import 'package:animeko_flutter/data/play/playback_position_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PlaybackPositionStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getPosition returns null when nothing is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = PlaybackPositionStorage(prefs);
      expect(storage.getPosition('ep1'), isNull);
    });

    test('setPosition persists and getPosition reads it back', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = PlaybackPositionStorage(prefs);
      await storage.setPosition('ep1', 12345);
      expect(storage.getPosition('ep1'), 12345);
    });

    test('different keys are stored independently', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = PlaybackPositionStorage(prefs);
      await storage.setPosition('ep1', 1000);
      await storage.setPosition('ep2', 2000);
      expect(storage.getPosition('ep1'), 1000);
      expect(storage.getPosition('ep2'), 2000);
    });

    test('clearPosition removes a stored value', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = PlaybackPositionStorage(prefs);
      await storage.setPosition('ep1', 1000);
      await storage.clearPosition('ep1');
      expect(storage.getPosition('ep1'), isNull);
    });
  });
}
