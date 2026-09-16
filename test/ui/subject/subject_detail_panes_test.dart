import 'package:animeko_flutter/data/search/search_models.dart';
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/ui/subject/expandable_summary.dart';
import 'package:animeko_flutter/ui/subject/subject_cover.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_left_pane.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_main_pane.dart';
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
  collectionType: CollectionType.done,
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

Widget _wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

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

  group('SubjectCover', () {
    testWidgets('renders a placeholder icon when the url is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SubjectCover(imageUrl: null, width: 200)),
        ),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(tester.getSize(find.byType(SubjectCover)).width, 200);
    });
  });

  group('SubjectDetailLeftPane', () {
    testWidgets('stacks cover, buttons, stats and the info table', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 200,
            child: SubjectDetailLeftPane(
              subjectId: 1,
              subjectName: '中文名',
              imageUrl: null,
            ),
          ),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SubjectCover), findsOneWidget);
      expect(find.text('开始观看'), findsOneWidget);
      expect(find.text('在看'), findsOneWidget);
      expect(find.text('7,781'), findsOneWidget);
      expect(find.text('作品信息'), findsOneWidget);
    });
  });

  group('SubjectDetailMainPane', () {
    testWidgets('stacks title, summary, episodes and characters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SubjectDetailMainPane(subjectId: 1, subjectName: '中文名'),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('中文名'), findsOneWidget);
      expect(find.byType(ExpandableSummary), findsOneWidget);
      expect(find.text('选集'), findsOneWidget);
    });
  });

  group('SubjectDetailSidePane', () {
    testWidgets('stacks the rating card and the staff card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            child: SubjectDetailSidePane(subjectId: 1),
          ),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('评分'), findsOneWidget);
      expect(find.text('制作人员'), findsOneWidget);
      expect(find.text('导演'), findsOneWidget);
    });
  });
}
