// test/ui/subject/subject_reviews_sheet_test.dart
import 'dart:async';

import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/ui/subject/subject_reviews_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectReview review({
  required String id,
  required String nickname,
  String? avatarUrl,
}) => SubjectReview(
  id: id,
  subjectId: 1,
  source: 'bangumi',
  author: ReviewAuthor(id: id, nickname: nickname, avatarUrl: avatarUrl),
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

  testWidgets('disables 加载更多 while the next page is in flight', (tester) async {
    when(() => api.getReviews(subjectId: 1, offset: 0, limit: 20)).thenAnswer(
      (_) async => PaginatedReviews(
        total: 2,
        items: [review(id: 'r1', nickname: 'A')],
      ),
    );
    final completer = Completer<PaginatedReviews>();
    when(
      () => api.getReviews(subjectId: 1, offset: 1, limit: 20),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      wrap(const SubjectReviewsSheet(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('加载更多'));
    await tester.pump();

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '加载更多'),
    );
    expect(button.onPressed, isNull);

    completer.complete(const PaginatedReviews(total: 2, items: []));
    await tester.pumpAndSettle();
  });

  testWidgets('shows a failure SnackBar and re-enables 加载更多 on error', (
    tester,
  ) async {
    when(() => api.getReviews(subjectId: 1, offset: 0, limit: 20)).thenAnswer(
      (_) async => PaginatedReviews(
        total: 2,
        items: [review(id: 'r1', nickname: 'A')],
      ),
    );
    when(
      () => api.getReviews(subjectId: 1, offset: 1, limit: 20),
    ).thenThrow(Exception('network'));

    await tester.pumpWidget(
      wrap(const SubjectReviewsSheet(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();

    expect(find.textContaining('加载更多评价失败'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '加载更多'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    'falls back to the placeholder icon when an avatar fails to load',
    (tester) async {
      when(() => api.getReviews(subjectId: 1, offset: 0, limit: 20)).thenAnswer(
        (_) async => PaginatedReviews(
          total: 1,
          items: [
            review(
              id: 'r1',
              nickname: 'A',
              avatarUrl: 'https://example.com/a.png',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        wrap(const SubjectReviewsSheet(subjectId: 1), overrides: overrides),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
    },
  );
}
