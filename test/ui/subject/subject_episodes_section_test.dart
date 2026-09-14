import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/ui/subject/subject_episodes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

const episodes = [
  SubjectEpisode(
    episodeId: 11,
    sort: 1,
    ep: '1',
    type: 'MAIN',
    name: 'One',
    nameCn: '第一话',
    airdate: '2026-07-12',
  ),
  SubjectEpisode(
    episodeId: 12,
    sort: 2,
    ep: '2',
    type: 'MAIN',
    name: 'Two',
    nameCn: '第二话',
    airdate: '2026-07-19',
  ),
  SubjectEpisode(
    episodeId: 13,
    sort: 3,
    ep: '3',
    type: 'MAIN',
    name: 'Three',
    nameCn: '第三话',
    airdate: '2099-01-01',
  ),
];

SubjectDetail detailWith(List<SubjectEpisode>? eps) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: '2026-07-12',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: eps,
);

Widget wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSubjectApi api;

  /// 覆盖 `mediaSourcesProvider` 为空列表：这样 `SubjectEpisodesController`
  /// 不会去打真实的爬虫源，网格会稳定落在「无源但可点」的状态。
  late List<Override> overrides;

  setUp(() {
    api = MockSubjectApi();
    overrides = [
      subjectApiProvider.overrideWithValue(api),
      mediaSourcesProvider.overrideWithValue(const <MediaSource>[]),
    ];
  });

  testWidgets('renders the 选集 header with the progress text', (tester) async {
    when(
      () => api.getSubject(1),
    ).thenAnswer((_) async => detailWith(episodes.toList()));

    await tester.pumpWidget(
      wrap(
        SubjectEpisodesSection(
          subjectId: 1,
          subjectName: 'A',
          now: DateTime(2026, 7, 20),
        ),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选集'), findsOneWidget);
    expect(find.text('连载至 02 · 预定全 3 话'), findsOneWidget);
  });

  testWidgets('renders one button per episode', (tester) async {
    when(
      () => api.getSubject(1),
    ).thenAnswer((_) async => detailWith(episodes.toList()));

    await tester.pumpWidget(
      wrap(
        const SubjectEpisodesSection(subjectId: 1, subjectName: 'A'),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('03'), findsOneWidget);
  });

  testWidgets('hides itself when there are no main episodes', (tester) async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detailWith(const []));

    await tester.pumpWidget(
      wrap(
        const SubjectEpisodesSection(subjectId: 1, subjectName: 'A'),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选集'), findsNothing);
  });

  testWidgets('shows a retry view when the episode list fails', (tester) async {
    when(() => api.getSubject(1)).thenThrow(Exception('network error'));

    await tester.pumpWidget(
      wrap(
        const SubjectEpisodesSection(subjectId: 1, subjectName: 'A'),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('加载剧集列表失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('tapping an episode opens the playback sheet', (tester) async {
    when(
      () => api.getSubject(1),
    ).thenAnswer((_) async => detailWith(episodes.toList()));

    await tester.pumpWidget(
      wrap(
        const SubjectEpisodesSection(subjectId: 1, subjectName: 'A'),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('01'));
    await tester.pumpAndSettle();

    expect(find.text('暂无播放源'), findsOneWidget);
  });
}
