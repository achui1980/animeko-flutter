import 'package:animeko_flutter/data/play/last_played_episode_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LastPlayedEpisodeStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<LastPlayedEpisodeStorage> storage() async {
      final prefs = await SharedPreferences.getInstance();
      return LastPlayedEpisodeStorage(prefs);
    }

    test('get returns null when nothing is stored', () async {
      final subject = await storage();
      expect(subject.get(1), isNull);
    });

    test('set then get round-trips the episode id', () async {
      final subject = await storage();
      await subject.set(1, 42);
      expect(subject.get(1), 42);
    });

    test('different subjects are stored independently', () async {
      final subject = await storage();
      await subject.set(1, 42);
      await subject.set(2, 7);
      expect(subject.get(1), 42);
      expect(subject.get(2), 7);
    });

    test(
      'set overwrites the previous episode id for the same subject',
      () async {
        final subject = await storage();
        await subject.set(1, 42);
        await subject.set(1, 43);
        expect(subject.get(1), 43);
      },
    );

    test('reads a value written by an earlier app run', () async {
      SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 99});
      final subject = await storage();
      expect(subject.get(1), 99);
    });
  });
}
