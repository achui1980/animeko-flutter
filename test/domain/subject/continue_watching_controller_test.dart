import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/continue_watching_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectEpisode episode({required int id, required num sort}) => SubjectEpisode(
  episodeId: id,
  sort: sort,
  ep: sort.toString(),
  type: 'MAIN',
  name: 'ep$id',
  nameCn: '',
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

  void createContainer() {
    container = ProviderContainer(
      overrides: [subjectApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  }

  setUp(() {
    api = MockSubjectApi();
    SharedPreferences.setMockInitialValues({});
  });

  Future<SubjectEpisode?> read() =>
      container.read(continueWatchingProvider(subjectId: 1).future);

  test('returns the first episode when nothing has been played', () async {
    when(() => api.getSubject(1)).thenAnswer(
      (_) async =>
          detailWith([episode(id: 11, sort: 1), episode(id: 12, sort: 2)]),
    );
    createContainer();

    final result = await read();

    expect(result?.episodeId, 11);
  });

  test('returns the stored episode when it is still in the list', () async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 12});
    when(() => api.getSubject(1)).thenAnswer(
      (_) async =>
          detailWith([episode(id: 11, sort: 1), episode(id: 12, sort: 2)]),
    );
    createContainer();

    final result = await read();

    expect(result?.episodeId, 12);
  });

  test('falls back to the first episode when the stored id is stale', () async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 999});
    when(() => api.getSubject(1)).thenAnswer(
      (_) async =>
          detailWith([episode(id: 11, sort: 1), episode(id: 12, sort: 2)]),
    );
    createContainer();

    final result = await read();

    expect(result?.episodeId, 11);
  });

  // Guards the family argument itself: without this, the provider could
  // hardcode subject 1 in either `ref.watch` and stay green. Fixture design
  // is load-bearing -- subject 1's stored id (11) is not an episode of
  // subject 2, and subject 2's stored id (22) is not subject 2's *first*
  // episode, so neither a cross-subject read nor a plain first-episode
  // fallback can produce 22.
  test('reads the stored id for the requested subject', () async {
    SharedPreferences.setMockInitialValues({
      'lastPlayedEpisode:1': 11,
      'lastPlayedEpisode:2': 22,
    });
    when(() => api.getSubject(2)).thenAnswer(
      (_) async =>
          detailWith([episode(id: 21, sort: 1), episode(id: 22, sort: 2)]),
    );
    createContainer();

    final result = await container.read(
      continueWatchingProvider(subjectId: 2).future,
    );

    expect(result?.episodeId, 22);
  });

  test('returns null when the subject has no main episodes', () async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detailWith(const []));
    createContainer();

    final result = await read();

    expect(result, isNull);
  });
}
