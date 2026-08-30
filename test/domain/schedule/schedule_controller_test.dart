import 'package:animeko_flutter/data/schedule/schedule_api.dart';
import 'package:animeko_flutter/data/schedule/schedule_models.dart';
import 'package:animeko_flutter/domain/schedule/schedule_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockScheduleApi extends Mock implements ScheduleApi {}

void main() {
  group('todayDateString', () {
    test('pads month and day to 2 digits', () {
      expect(todayDateString(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('handles double-digit month and day', () {
      expect(todayDateString(DateTime(2026, 12, 28)), '2026-12-28');
    });
  });

  group('timeZoneOffsetString', () {
    test('formats a positive whole-hour offset', () {
      expect(timeZoneOffsetString(const Duration(hours: 8)), '+08:00');
    });

    test('formats a negative offset', () {
      expect(timeZoneOffsetString(const Duration(hours: -5)), '-05:00');
    });

    test('formats a half-hour offset', () {
      expect(
        timeZoneOffsetString(const Duration(hours: 5, minutes: 30)),
        '+05:30',
      );
    });

    test('formats a zero offset as positive', () {
      expect(timeZoneOffsetString(Duration.zero), '+00:00');
    });
  });

  group('ScheduleController', () {
    late MockScheduleApi api;
    late ProviderContainer container;

    setUp(() {
      api = MockScheduleApi();
      container = ProviderContainer(
        overrides: [scheduleApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
    });

    test('groups subjects by date', () async {
      when(
        () => api.getLatestAiringSchedule(
          today: any(named: 'today'),
          timeZone: any(named: 'timeZone'),
        ),
      ).thenAnswer(
        (_) async => const LatestAiringSchedule(
          list: [
            AiringScheduleForDate(
              date: '2026-08-28',
              list: [
                ScheduledAnimeEpisode(
                  subject: ScheduledAnimeSubject(
                    subjectId: 100,
                    name: 'Frieren',
                    nameCn: '芙莉莲',
                    imageLarge: 'https://example.com/f.jpg',
                  ),
                  episode: ScheduledAnimeEpisodeInfo(
                    episodeId: 1000,
                    name: 'Ep 1',
                    nameCn: '第1话',
                    airDate: '2026-08-28',
                    sort: '1',
                  ),
                  airingTime: '2026-08-28T22:00:00Z',
                ),
              ],
            ),
          ],
        ),
      );

      final result = await container.read(scheduleControllerProvider.future);

      expect(result, hasLength(1));
      expect(result.single.date, '2026-08-28');
      expect(result.single.subjects.single.nameCn, '芙莉莲');
      expect(result.single.subjects.single.id, 100);
    });
  });
}
