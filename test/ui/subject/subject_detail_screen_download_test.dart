import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSubjectApi extends Mock implements SubjectApi {}

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);

  @override
  final String sourceId;

  @override
  final String title;
}

class _StubEpisodesController extends SubjectEpisodesController {
  _StubEpisodesController(this.episodes);

  final List<MergedEpisode> episodes;

  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => episodes;
}

class _RecordingDownloadQueueController extends DownloadQueueController {
  final requests =
      <({int subjectId, String subjectName, MergedEpisode episode})>[];

  @override
  Future<Map<String, DownloadQueueItem>> build() async => const {};

  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) {
    requests.add((
      subjectId: subjectId,
      subjectName: subjectName,
      episode: episode,
    ));
  }
}

SubjectDetail _detail() => SubjectDetail(
  id: 1,
  name: 'Original Name',
  nameCn: '中文名',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: const [],
  collectionType: CollectionType.doing,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: const [],
);

void main() {
  testWidgets('queues every episode from the first HTTP source', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = _MockSubjectApi();
    when(() => api.getSubject(1)).thenAnswer((_) async => _detail());
    when(() => api.getCharacters(1)).thenAnswer((_) async => []);
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const PaginatedReviews(total: 0, items: []));
    final episodes = [
      const MergedEpisode(
        episode: _FakeEpisode('anime1', '第1集'),
        sourceId: 'anime1',
      ),
      const MergedEpisode(
        episode: _FakeEpisode('anime1', '第2集'),
        sourceId: 'anime1',
      ),
      const MergedEpisode(
        episode: _FakeEpisode('xifan', '第1集'),
        sourceId: 'xifan',
      ),
    ];
    late _RecordingDownloadQueueController queue;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectApiProvider.overrideWithValue(api),
          subjectEpisodesControllerProvider(
            subjectId: 1,
            subjectName: '中文名',
          ).overrideWith(() => _StubEpisodesController(episodes)),
          downloadQueueControllerProvider.overrideWith(() {
            queue = _RecordingDownloadQueueController();
            return queue;
          }),
        ],
        child: const MaterialApp(
          home: SubjectDetailScreen(subjectId: 1, subjectName: '中文名'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('全部下载'));
    await tester.pumpAndSettle();

    expect(queue.requests.map((request) => request.episode.title), [
      '第1集',
      '第2集',
    ]);
    expect(queue.requests.map((request) => request.episode.sourceId), [
      'anime1',
      'anime1',
    ]);
  });
}
