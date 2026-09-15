import 'package:animeko_flutter/data/search/search_models.dart';
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/ui/common/error_retry_view.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_left_pane.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_main_pane.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_screen.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_side_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

const _episode = SubjectEpisode(
  episodeId: 11,
  sort: 1,
  ep: '1',
  type: 'MAIN',
  name: 'EN 1',
  nameCn: '第一集',
  airdate: '2026-07-12',
);

SubjectDetail _detail() => SubjectDetail(
  id: 1,
  name: 'Original Name',
  nameCn: '中文名',
  summary: '这是简介正文。',
  airDate: '2026-07-12',
  tags: const [SubjectTag(name: '奇幻', count: 12)],
  score: '7.9',
  rank: 325,
  collectionType: CollectionType.doing,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  favorite: const SubjectFavorite(
    wish: 1449,
    done: 7781,
    doing: 5959,
    onHold: 12,
    dropped: 3,
  ),
  infobox: const SubjectInfobox(
    fields: [
      InfoboxField(
        key: '导演',
        values: [InfoboxValue(v: '某导演')],
      ),
    ],
  ),
  scoreDetails: const {'7': 100},
  episodes: const [_episode],
);

void main() {
  late MockSubjectApi api;
  late List<Override> overrides;

  setUpAll(() {
    registerFallbackValue(CollectionType.wish);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockSubjectApi();
    when(() => api.getSubject(1)).thenAnswer((_) async => _detail());
    when(() => api.getCharacters(1)).thenAnswer((_) async => []);
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const PaginatedReviews(total: 0, items: []));
    overrides = [
      subjectApiProvider.overrideWithValue(api),
      mediaSourcesProvider.overrideWithValue(const <MediaSource>[]),
    ];
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    List<Override>? withOverrides,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: withOverrides ?? overrides,
        child: const MaterialApp(
          home: SubjectDetailScreen(
            subjectId: 1,
            subjectName: '中文名',
            imageUrl: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lays the three panes out side by side at 1400x900', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1400, 900));

    final left = tester.getTopLeft(find.byType(SubjectDetailLeftPane));
    final main = tester.getTopLeft(find.byType(SubjectDetailMainPane));
    final side = tester.getTopLeft(find.byType(SubjectDetailSidePane));

    expect(left.dx, lessThan(main.dx));
    expect(main.dx, lessThan(side.dx));
    expect(tester.getSize(find.byType(SubjectDetailLeftPane)).width, 200);
    expect(tester.getSize(find.byType(SubjectDetailSidePane)).width, 300);
  });

  testWidgets('stacks content in one column at 800x900', (tester) async {
    await pumpAt(tester, const Size(800, 900));

    expect(find.byType(SubjectDetailLeftPane), findsNothing);
    final main = tester.getTopLeft(find.byType(SubjectDetailMainPane));
    final side = tester.getTopLeft(find.byType(SubjectDetailSidePane));
    expect(main.dy, lessThan(side.dy));
    expect(main.dx, equals(side.dx));
  });

  testWidgets('shows the collection stats once in the narrow layout', (
    tester,
  ) async {
    await pumpAt(tester, const Size(800, 900));

    expect(find.text('7,781'), findsOneWidget);
    expect(find.text('中文名'), findsOneWidget);
  });

  testWidgets('shows a whole-page retry when the subject request fails', (
    tester,
  ) async {
    when(() => api.getSubject(1)).thenThrow(Exception('network error'));

    await pumpAt(tester, const Size(1400, 900));

    expect(find.byType(ErrorRetryView), findsOneWidget);
    expect(find.textContaining('加载详情失败'), findsOneWidget);
    expect(find.byType(SubjectDetailMainPane), findsNothing);
  });

  testWidgets('the app bar carries no title', (tester) async {
    await pumpAt(tester, const Size(1400, 900));

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
      findsNothing,
    );
  });
}
