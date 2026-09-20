import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/schedule/schedule_subject_score.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectDetail detailWithScore(String? score) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: [],
  score: score,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
);

void main() {
  group('formatScheduleSubjectScore', () {
    test('formats a positive score with at most one decimal', () {
      expect(formatScheduleSubjectScore('7.8'), '7.8');
      expect(formatScheduleSubjectScore('8.0'), '8');
      expect(formatScheduleSubjectScore(' 8.46 '), '8.5');
    });

    test('returns null for absent or invalid scores', () {
      for (final score in [
        null,
        '',
        '   ',
        'bad',
        'NaN',
        'Infinity',
        '0',
        '-1',
      ]) {
        expect(formatScheduleSubjectScore(score), isNull);
      }
    });
  });

  group('scheduleSubjectScore', () {
    late MockSubjectApi api;
    late ProviderContainer container;

    setUp(() {
      api = MockSubjectApi();
      container = ProviderContainer(
        overrides: [subjectApiProvider.overrideWithValue(api)],
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
    });

    test('retains a score after its last listener is removed', () async {
      when(
        () => api.getSubject(1),
      ).thenAnswer((_) async => detailWithScore('8.46'));

      final subscription = container.listen(
        scheduleSubjectScoreProvider(1),
        (_, _) {},
      );
      expect(
        await container.read(scheduleSubjectScoreProvider(1).future),
        '8.5',
      );

      subscription.close();
      await container.pump();

      expect(
        await container.read(scheduleSubjectScoreProvider(1).future),
        '8.5',
      );
      verify(() => api.getSubject(1)).called(1);
    });

    test('keeps distinct cache entries for different subject ids', () async {
      when(
        () => api.getSubject(1),
      ).thenAnswer((_) async => detailWithScore('8.46'));
      when(
        () => api.getSubject(2),
      ).thenAnswer((_) async => detailWithScore('7.2'));

      expect(
        await container.read(scheduleSubjectScoreProvider(1).future),
        '8.5',
      );
      expect(
        await container.read(scheduleSubjectScoreProvider(2).future),
        '7.2',
      );
      expect(
        await container.read(scheduleSubjectScoreProvider(1).future),
        '8.5',
      );

      verify(() => api.getSubject(1)).called(1);
      verify(() => api.getSubject(2)).called(1);
    });

    test('resolves null when loading subject detail fails', () async {
      when(() => api.getSubject(1)).thenThrow(Exception('network error'));

      expect(
        await container.read(scheduleSubjectScoreProvider(1).future),
        isNull,
      );
    });
  });
}
