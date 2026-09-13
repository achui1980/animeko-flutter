import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/subject_main_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectEpisode episode({
  required int id,
  required num sort,
  String type = 'MAIN',
  String nameCn = '',
}) => SubjectEpisode(
  episodeId: id,
  sort: sort,
  ep: sort.toString(),
  type: type,
  name: 'ep$id',
  nameCn: nameCn,
  airdate: '2026-01-01',
);

SubjectDetail detailWith(List<SubjectEpisode>? episodes) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: episodes,
);

void main() {
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

  Future<List<SubjectEpisode>> read() => container.read(
    subjectMainEpisodesControllerProvider(subjectId: 1).future,
  );

  group('SubjectMainEpisodesController', () {
    test('keeps only MAIN episodes, dropping SPECIAL/OP/ED', () async {
      when(() => api.getSubject(1)).thenAnswer(
        (_) async => detailWith([
          episode(id: 1, sort: 1),
          episode(id: 2, sort: 2, type: 'SPECIAL'),
          episode(id: 3, sort: 3, type: 'OP'),
          episode(id: 4, sort: 4, type: 'ED'),
          episode(id: 5, sort: 5),
        ]),
      );

      final result = await read();

      expect(result.map((e) => e.episodeId), [1, 5]);
    });

    // The backend interleaves MAIN and SPECIAL entries rather than grouping
    // them, and does not guarantee ordering, so sorting is not optional.
    test('sorts the surviving episodes ascending by sort', () async {
      when(() => api.getSubject(1)).thenAnswer(
        (_) async => detailWith([
          episode(id: 3, sort: 3),
          episode(id: 1, sort: 1),
          episode(id: 2, sort: 2, type: 'SPECIAL'),
          episode(id: 2, sort: 2),
        ]),
      );

      final result = await read();

      expect(result.map((e) => e.sort), [1, 2, 3]);
    });

    test('sorts fractional sorts between their integer neighbours', () async {
      when(() => api.getSubject(1)).thenAnswer(
        (_) async => detailWith([
          episode(id: 2, sort: 2),
          episode(id: 15, sort: 1.5),
          episode(id: 1, sort: 1),
        ]),
      );

      final result = await read();

      expect(result.map((e) => e.sort), [1, 1.5, 2]);
    });

    test(
      'returns an empty list when the response has no episodes key',
      () async {
        when(() => api.getSubject(1)).thenAnswer((_) async => detailWith(null));

        expect(await read(), isEmpty);
      },
    );

    test(
      'returns an empty list when every episode is a non-MAIN type',
      () async {
        when(() => api.getSubject(1)).thenAnswer(
          (_) async => detailWith([episode(id: 1, sort: 1, type: 'SPECIAL')]),
        );

        expect(await read(), isEmpty);
      },
    );

    // Regression guard for the reason this controller exists: the old
    // api.bgm.tv client capped the list at limit=100, so long-running shows
    // (航海王 has 1155 主线剧集) were silently truncated.
    test('does not truncate long episode lists', () async {
      when(() => api.getSubject(1)).thenAnswer(
        (_) async => detailWith([
          for (var i = 1; i <= 250; i++) episode(id: i, sort: i),
        ]),
      );

      final result = await read();

      expect(result, hasLength(250));
      expect(result.last.sort, 250);
    });

    test('propagates a getSubject failure', () async {
      when(() => api.getSubject(1)).thenThrow(Exception('network error'));

      await expectLater(read(), throwsA(isA<Exception>()));
    });
  });
}
