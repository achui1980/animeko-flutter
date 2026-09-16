import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_rating_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

final _detail = SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: '2026-07-12',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
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

  setUpAll(() {
    registerFallbackValue(
      const SelfRating(score: 5, tags: [], isPrivate: false),
    );
  });

  setUp(() {
    api = MockSubjectApi();
    overrides = [subjectApiProvider.overrideWithValue(api)];
    when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
  });

  testWidgets('starts at the initial score', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SubjectRatingDialog(subjectId: 1, initialScore: 8),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8 分'), findsOneWidget);
    expect(find.text('我的评分'), findsOneWidget);
  });

  testWidgets('prefills the comment and privacy toggle', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SubjectRatingDialog(
          subjectId: 1,
          initialScore: 7,
          initialComment: '好看',
          initialIsPrivate: true,
        ),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('好看'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('submitting sends the score and closes the dialog', (
    tester,
  ) async {
    when(
      () => api.updateCollection(1, selfRating: any(named: 'selfRating')),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showSubjectRatingDialog(context, subjectId: 1, initialScore: 9),
            child: const Text('open'),
          ),
        ),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => api.updateCollection(
                1,
                selfRating: captureAny(named: 'selfRating'),
              ),
            ).captured.single
            as SelfRating;
    expect(captured.score, 9);
    expect(find.text('我的评分'), findsNothing);
    expect(find.text('评分已提交'), findsOneWidget);
  });

  testWidgets('keeps the dialog open and shows an error when submit fails', (
    tester,
  ) async {
    when(
      () => api.updateCollection(1, selfRating: any(named: 'selfRating')),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      wrap(
        const SubjectRatingDialog(subjectId: 1, initialScore: 6),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    expect(find.text('我的评分'), findsOneWidget);
    expect(find.textContaining('提交评分失败'), findsOneWidget);
  });

  testWidgets('cancel closes the dialog without calling the api', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showSubjectRatingDialog(context, subjectId: 1, initialScore: 5),
            child: const Text('open'),
          ),
        ),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('我的评分'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('我的评分'), findsNothing);
    verifyNever(
      () => api.updateCollection(1, selfRating: any(named: 'selfRating')),
    );
  });
}
