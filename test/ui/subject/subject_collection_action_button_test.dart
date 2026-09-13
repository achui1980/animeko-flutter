import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_collection_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectDetail detailWith(CollectionType? type) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: '2026-01-01',
  tags: const [],
  collectionType: type,
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

  setUpAll(() {
    registerFallbackValue(CollectionType.wish);
  });

  setUp(() {
    api = MockSubjectApi();
  });

  Future<void> pump(WidgetTester tester, CollectionType? type) async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detailWith(type));
    await tester.pumpWidget(
      wrap(
        const SubjectCollectionActionButton(subjectId: 1, imageUrl: 'u'),
        overrides: [subjectApiProvider.overrideWithValue(api)],
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SubjectCollectionActionButton', () {
    testWidgets('未收藏时显示「追番」', (tester) async {
      await pump(tester, null);

      expect(find.text('追番'), findsOneWidget);
      expect(find.text('在看'), findsNothing);
    });

    testWidgets('点击「追番」以 wish 调用 updateCollection', (tester) async {
      when(
        () => api.updateCollection(
          any(),
          collectionType: any(named: 'collectionType'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester, null);

      await tester.tap(find.text('追番'));
      await tester.pumpAndSettle();

      verify(
        () => api.updateCollection(1, collectionType: CollectionType.wish),
      ).called(1);
    });

    testWidgets('已收藏时显示当前状态标签', (tester) async {
      await pump(tester, CollectionType.doing);

      expect(find.text('在看'), findsOneWidget);
      expect(find.text('追番'), findsNothing);
    });

    testWidgets('展开菜单列出其余状态与「移除」，不含当前状态', (tester) async {
      await pump(tester, CollectionType.doing);

      await tester.tap(find.text('在看'));
      await tester.pumpAndSettle();

      expect(find.text('想看'), findsOneWidget);
      expect(find.text('看过'), findsOneWidget);
      expect(find.text('搁置'), findsOneWidget);
      expect(find.text('弃番'), findsOneWidget);
      expect(find.text('移除'), findsOneWidget);
      // 「在看」只剩下按钮上那一个，菜单里不重复出现。
      expect(find.text('在看'), findsOneWidget);
    });

    testWidgets('菜单里选「看过」以 done 调用 updateCollection', (tester) async {
      when(
        () => api.updateCollection(
          any(),
          collectionType: any(named: 'collectionType'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester, CollectionType.doing);

      await tester.tap(find.text('在看'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('看过'));
      await tester.pumpAndSettle();

      verify(
        () => api.updateCollection(1, collectionType: CollectionType.done),
      ).called(1);
    });

    testWidgets('菜单里选「移除」调用 deleteCollection', (tester) async {
      when(() => api.deleteCollection(1)).thenAnswer((_) async {});
      await pump(tester, CollectionType.doing);

      await tester.tap(find.text('在看'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移除'));
      await tester.pumpAndSettle();

      verify(() => api.deleteCollection(1)).called(1);
    });

    testWidgets('更新失败时弹出 SnackBar', (tester) async {
      when(
        () => api.updateCollection(
          any(),
          collectionType: any(named: 'collectionType'),
        ),
      ).thenThrow(Exception('boom'));
      await pump(tester, null);

      await tester.tap(find.text('追番'));
      await tester.pumpAndSettle();

      expect(find.textContaining('更新收藏状态失败'), findsOneWidget);
    });
  });
}
