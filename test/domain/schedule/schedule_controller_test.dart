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
      final today = todayDateString(DateTime.now());
      when(
        () => api.getLatestAiringSchedule(
          today: any(named: 'today'),
          timeZone: any(named: 'timeZone'),
        ),
      ).thenAnswer(
        (_) async => LatestAiringSchedule(
          list: [
            AiringScheduleForDate(
              date: today,
              list: const [
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
      expect(result.single.date, today);
      expect(result.single.subjects.single.nameCn, '芙莉莲');
      expect(result.single.subjects.single.id, 100);
      expect(result.single.subjects.single.episodeSort, '1');
      expect(result.single.subjects.single.airingTime, '2026-08-28T22:00:00Z');
    });

    test(
      'drops days before today, sorts, and caps the result to 7 days starting today',
      () async {
        final now = DateTime.now();
        // 3 days before today (must be dropped) + 10 days from today onward
        // (must be sorted ascending and capped to the first 7), all fed in
        // shuffled order to verify the controller sorts rather than trusting
        // server ordering.
        final allDates = List.generate(
          13,
          (i) => todayDateString(now.add(Duration(days: i - 3))),
        );
        final shuffled = allDates.reversed.toList();
        final days = shuffled
            .map((date) => AiringScheduleForDate(date: date, list: const []))
            .toList();

        when(
          () => api.getLatestAiringSchedule(
            today: any(named: 'today'),
            timeZone: any(named: 'timeZone'),
          ),
        ).thenAnswer((_) async => LatestAiringSchedule(list: days));

        final result = await container.read(scheduleControllerProvider.future);

        expect(result, hasLength(7));
        expect(result.first.date, todayDateString(now));
        expect(
          result.last.date,
          todayDateString(now.add(const Duration(days: 6))),
        );
        for (var i = 1; i < result.length; i++) {
          expect(result[i].date.compareTo(result[i - 1].date) > 0, isTrue);
        }
      },
    );

    test(
      'shows fewer than 7 days when the server has less than a week left',
      () async {
        final now = DateTime.now();
        final days = [
          // Yesterday: must be dropped.
          AiringScheduleForDate(
            date: todayDateString(now.subtract(const Duration(days: 1))),
            list: const [],
          ),
          AiringScheduleForDate(date: todayDateString(now), list: const []),
          AiringScheduleForDate(
            date: todayDateString(now.add(const Duration(days: 1))),
            list: const [],
          ),
        ];
        when(
          () => api.getLatestAiringSchedule(
            today: any(named: 'today'),
            timeZone: any(named: 'timeZone'),
          ),
        ).thenAnswer((_) async => LatestAiringSchedule(list: days));

        final result = await container.read(scheduleControllerProvider.future);

        expect(result, hasLength(2));
        expect(result.first.date, todayDateString(now));
        expect(
          result.last.date,
          todayDateString(now.add(const Duration(days: 1))),
        );
      },
    );
  });
}
