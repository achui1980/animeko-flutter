// test/ui/subject/subject_reviews_card_test.dart
import 'dart:async';

import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/ui/subject/subject_reviews_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectReview review({
  required String id,
  required String nickname,
  String? content,
  int? rating,
}) => SubjectReview(
  id: id,
  subjectId: 1,
  source: 'bangumi',
  author: ReviewAuthor(id: id, nickname: nickname),
  contentBbcode: content,
  rating: rating,
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

  void stubReviews(List<SubjectReview> items, {int? total}) {
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => PaginatedReviews(total: total ?? items.length, items: items),
    );
  }

  testWidgets('renders the nickname and BBCode-stripped content', (
    tester,
  ) async {
    stubReviews([review(id: 'a', nickname: 'Sparrow', content: '[b]太穷了吧[/b]')]);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('热门评价'), findsOneWidget);
    expect(find.text('Sparrow'), findsOneWidget);
    expect(find.text('太穷了吧'), findsOneWidget);
    expect(find.text('[b]太穷了吧[/b]'), findsNothing);
  });

  testWidgets('shows at most maxVisible reviews', (tester) async {
    stubReviews([
      for (var i = 0; i < 6; i++)
        review(id: '$i', nickname: 'user$i', content: 'c$i'),
    ]);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('user0'), findsOneWidget);
    expect(
      find.text('user${SubjectReviewsCard.maxVisible - 1}'),
      findsOneWidget,
    );
    expect(find.text('user${SubjectReviewsCard.maxVisible}'), findsNothing);
  });

  testWidgets('hides the whole card when there are no reviews', (tester) async {
    stubReviews(const []);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('热门评价'), findsNothing);
  });

  testWidgets('hides the whole card when the request fails', (tester) async {
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenThrow(Exception('network error'));

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('热门评价'), findsNothing);
  });

  testWidgets('keeps the card frame with a spinner while loading', (
    tester,
  ) async {
    final completer = Completer<PaginatedReviews>();
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pump();

    expect(find.text('热门评价'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const PaginatedReviews(total: 0, items: []));
    await tester.pumpAndSettle();
  });

  testWidgets('tapping 查看全部 opens the full reviews sheet', (tester) async {
    stubReviews([
      review(id: 'a', nickname: 'Sparrow', content: 'good'),
    ], total: 21);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部 ›'));
    await tester.pumpAndSettle();

    expect(find.text('全部评价'), findsOneWidget);
    expect(find.text('加载更多'), findsOneWidget);
  });
}
