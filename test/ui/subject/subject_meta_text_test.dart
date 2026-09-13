import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/ui/subject/subject_meta_text.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectEpisode ep(int n, String airdate) => SubjectEpisode(
  episodeId: n,
  sort: n,
  ep: '$n',
  type: 'MAIN',
  name: 'E$n',
  nameCn: '第$n集',
  airdate: airdate,
);

/// 固定「今天」，让测试不随真实时间漂移。
final now = DateTime(2026, 9, 12);

void main() {
  group('formatAirDateYearMonth', () {
    test('formats an ISO date as 年月', () {
      expect(formatAirDateYearMonth('2026-07-12'), '2026年7月');
    });

    test('returns null when the date is unparseable', () {
      expect(formatAirDateYearMonth('not-a-date'), isNull);
    });

    test('returns null for an empty string', () {
      expect(formatAirDateYearMonth(''), isNull);
    });
  });

  group('formatEpisodeNumber', () {
    test('drops the decimal part for whole numbers', () {
      expect(formatEpisodeNumber(3), '3');
      expect(formatEpisodeNumber(3.0), '3');
    });

    test('keeps the decimal part for fractional sorts', () {
      expect(formatEpisodeNumber(3.5), '3.5');
    });
  });

  group('airedEpisodeCount', () {
    test('counts episodes airing today or earlier', () {
      final episodes = [
        ep(1, '2026-09-01'),
        ep(2, '2026-09-08'),
        ep(3, '2026-09-12'),
        ep(4, '2026-09-19'),
        ep(5, '2026-09-26'),
      ];
      expect(airedEpisodeCount(episodes, now: now), 3);
    });

    test('skips episodes with an unparseable airdate', () {
      final episodes = [ep(1, '2026-09-01'), ep(2, '')];
      expect(airedEpisodeCount(episodes, now: now), 1);
    });

    test('returns 0 for an empty list', () {
      expect(airedEpisodeCount(const [], now: now), 0);
    });
  });

  group('formatEpisodeProgress', () {
    test('shows both segments while still airing', () {
      final episodes = [
        for (var i = 1; i <= 9; i++) ep(i, '2026-09-01'),
        ep(10, '2026-09-19'),
        ep(11, '2026-09-26'),
      ];
      expect(
        formatEpisodeProgress(episodes: episodes, episodeCount: 11, now: now),
        '连载至 09 · 预定全 11 话',
      );
    });

    test('omits 连载至 once every episode has aired', () {
      final episodes = [for (var i = 1; i <= 11; i++) ep(i, '2026-09-01')];
      expect(
        formatEpisodeProgress(episodes: episodes, episodeCount: 11, now: now),
        '预定全 11 话',
      );
    });

    test('omits 连载至 when nothing has aired yet', () {
      final episodes = [for (var i = 1; i <= 11; i++) ep(i, '2026-12-01')];
      expect(
        formatEpisodeProgress(episodes: episodes, episodeCount: 11, now: now),
        '预定全 11 话',
      );
    });

    test('omits 预定全 when the episode count is unknown', () {
      final episodes = [
        ep(1, '2026-09-01'),
        ep(2, '2026-09-08'),
        ep(3, '2026-09-19'),
      ];
      expect(
        formatEpisodeProgress(episodes: episodes, episodeCount: null, now: now),
        '连载至 02',
      );
    });

    test('returns null when there is nothing to say', () {
      expect(
        formatEpisodeProgress(episodes: const [], episodeCount: null, now: now),
        isNull,
      );
    });
  });

  group('buildSubjectMetaLine', () {
    test('joins every available segment with ` · `', () {
      final episodes = [
        for (var i = 1; i <= 9; i++) ep(i, '2026-09-01'),
        ep(10, '2026-09-19'),
        ep(11, '2026-09-26'),
      ];
      expect(
        buildSubjectMetaLine(
          airDate: '2026-07-12',
          episodes: episodes,
          episodeCount: 11,
          now: now,
        ),
        '2026年7月 · 连载至 09 · 预定全 11 话',
      );
    });

    test('drops the 年月 segment when the air date is unparseable', () {
      final episodes = [
        for (var i = 1; i <= 9; i++) ep(i, '2026-09-01'),
        ep(10, '2026-09-19'),
        ep(11, '2026-09-26'),
      ];
      expect(
        buildSubjectMetaLine(
          airDate: '',
          episodes: episodes,
          episodeCount: 11,
          now: now,
        ),
        '连载至 09 · 预定全 11 话',
      );
    });

    test('keeps only the 年月 segment when there is no episode data', () {
      expect(
        buildSubjectMetaLine(
          airDate: '2026-07-12',
          episodes: const [],
          episodeCount: null,
          now: now,
        ),
        '2026年7月',
      );
    });

    test('returns an empty string when nothing is known', () {
      expect(
        buildSubjectMetaLine(
          airDate: '',
          episodes: const [],
          episodeCount: null,
          now: now,
        ),
        '',
      );
    });
  });
}
