import 'dart:async';

import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_rating_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectDetail detail({
  String? score,
  int? rank,
  Map<String, int>? scoreDetails,
  SelfRating selfRating = const SelfRating(
    score: 0,
    tags: [],
    isPrivate: false,
  ),
}) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: '2026-07-12',
  tags: const [],
  score: score,
  rank: rank,
  scoreDetails: scoreDetails,
  selfRating: selfRating,
);

Widget wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSubjectApi api;
  late List<Override> overrides;

  setUp(() {
    api = MockSubjectApi();
    overrides = [subjectApiProvider.overrideWithValue(api)];
  });

  testWidgets('shows score, rank and summed rating count', (tester) async {
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => detail(
        score: '7.9',
        rank: 325,
        scoreDetails: {'7': 100, '8': 200, '9': 50},
      ),
    );

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('评分'), findsOneWidget);
    expect(find.text('7.9'), findsOneWidget);
    expect(find.text('#325 · 350 人评分'), findsOneWidget);
  });

  testWidgets('renders one histogram bar per score from 1 to 10', (
    tester,
  ) async {
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => detail(score: '7.9', scoreDetails: {'7': 100, '8': 200}),
    );

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    for (var score = 1; score <= 10; score++) {
      expect(find.text('$score'), findsOneWidget);
    }
  });

  testWidgets('omits the histogram when scoreDetails is empty', (tester) async {
    when(
      () => api.getSubject(1),
    ).thenAnswer((_) async => detail(score: null, scoreDetails: null));

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('评分'), findsOneWidget);
    expect(find.text('暂无评分'), findsOneWidget);
    expect(find.text('10'), findsNothing);
  });

  testWidgets('rating button reads 打分 when not rated yet', (tester) async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detail(score: '7.9'));

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('☆ 打分'), findsOneWidget);
  });

  testWidgets('rating button shows my score when already rated', (
    tester,
  ) async {
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => detail(
        score: '7.9',
        selfRating: const SelfRating(score: 8, tags: [], isPrivate: false),
      ),
    );

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('☆ 已评 8 分'), findsOneWidget);
  });

  testWidgets('tapping the rating button opens the rating dialog', (
    tester,
  ) async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detail(score: '7.9'));

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('☆ 打分'));
    await tester.pumpAndSettle();

    expect(find.text('我的评分'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('renders nothing while the subject is still loading', (
    tester,
  ) async {
    final completer = Completer<SubjectDetail>();
    when(() => api.getSubject(1)).thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pump();

    expect(find.text('评分'), findsNothing);

    completer.complete(detail(score: '7.9'));
    await tester.pumpAndSettle();
  });
}
