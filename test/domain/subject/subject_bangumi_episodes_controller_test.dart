import 'package:animeko_flutter/data/subject/bangumi_episode_models.dart';
import 'package:animeko_flutter/data/subject/bangumi_episodes_api.dart';
import 'package:animeko_flutter/domain/subject/subject_bangumi_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockBangumiEpisodesApi extends Mock implements BangumiEpisodesApi {}

void main() {
  group('SubjectBangumiEpisodesController', () {
    late MockBangumiEpisodesApi api;
    late ProviderContainer container;

    setUp(() {
      api = MockBangumiEpisodesApi();
      container = ProviderContainer(
        overrides: [bangumiEpisodesApiProvider.overrideWithValue(api)],
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
    });

    Future<List<BangumiEpisode>> read() => container.read(
      subjectBangumiEpisodesControllerProvider(subjectId: 400602).future,
    );

    test(
      'filters out non-main episodes (SP/OP/ED) and sorts by sort ascending',
      () async {
        when(() => api.listEpisodes(400602)).thenAnswer(
          (_) async => [
            const BangumiEpisode(
              id: 3,
              sort: 2,
              name: 'ep2',
              nameCn: '第2集',
              airdate: '',
              type: 0,
            ),
            const BangumiEpisode(
              id: 1,
              sort: 0,
              name: 'SP',
              nameCn: 'SP',
              airdate: '',
              type: 1,
            ),
            const BangumiEpisode(
              id: 2,
              sort: 1,
              name: 'ep1',
              nameCn: '第1集',
              airdate: '',
              type: 0,
            ),
          ],
        );

        final result = await read();

        expect(result.map((e) => e.id), [2, 3]);
      },
    );

    test('propagates the underlying API exception', () async {
      when(() => api.listEpisodes(400602)).thenThrow(Exception('network down'));

      await expectLater(read(), throwsA(isA<Exception>()));
    });
  });
}
