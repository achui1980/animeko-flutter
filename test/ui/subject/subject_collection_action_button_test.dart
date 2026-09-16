import 'dart:async';

import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_image_cache_repository.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_collection_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

class MockSubjectImageCacheRepository extends Mock
    implements SubjectImageCacheRepository {}

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
  late MockSubjectImageCacheRepository imageCacheRepo;

  setUpAll(() {
    registerFallbackValue(CollectionType.wish);
  });

  setUp(() {
    api = MockSubjectApi();
    // `pump` passes `imageUrl: 'u'`, so every successful update also writes
    // the local cover cache. Without this override that write reaches the
    // real `AppDatabase`, which both logs a drift "created the database
    // class multiple times" warning and then fails with
    // `MissingPluginException` (no `getApplicationDocumentsDirectory` under
    // `flutter_test`) -- silently exercising the swallowed failure path
    // instead of the success path.
    imageCacheRepo = MockSubjectImageCacheRepository();
    when(() => imageCacheRepo.save(1, 'u')).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, CollectionType? type) async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detailWith(type));
    await tester.pumpWidget(
      wrap(
        const SubjectCollectionActionButton(subjectId: 1, imageUrl: 'u'),
        overrides: [
          subjectApiProvider.overrideWithValue(api),
          subjectImageCacheRepositoryProvider.overrideWithValue(imageCacheRepo),
        ],
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

    testWidgets('菜单打开期间控件被卸载，再选「移除」不会 setState', (tester) async {
      when(
        () => api.getSubject(1),
      ).thenAnswer((_) async => detailWith(CollectionType.doing));
      when(() => api.deleteCollection(1)).thenAnswer((_) async {});
      final overrides = [
        subjectApiProvider.overrideWithValue(api),
        subjectImageCacheRepositoryProvider.overrideWithValue(imageCacheRepo),
      ];
      await tester.pumpWidget(
        wrap(
          const SubjectCollectionActionButton(subjectId: 1, imageUrl: 'u'),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('在看'));
      await tester.pumpAndSettle();

      // 菜单项活在 Navigator 的 overlay route 里，比本控件活得久：把控件从树上
      // 摘掉（窗口宽度跨过三栏断点导致 pane 重建就会这样）之后菜单还在，而
      // `PopupMenuItem.onTap` 不像 `onSelected` 那样有 framework 的 mounted 兜底。
      await tester.pumpWidget(
        wrap(const SizedBox.shrink(), overrides: overrides),
      );
      await tester.pump();

      await tester.tap(find.text('移除'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('同一帧内连点两次「追番」只调用一次 updateCollection', (tester) async {
      // PATCH 故意挂着不完成，这样第二次点击落在请求进行中的那段窗口里 ——
      // 让 stub 立刻返回是观察不到 [_busy] 的：`await tester.tap` 会把 microtask
      // 冲干净，第一次请求在第二次点击之前就已经跑完、`_busy` 也已经清掉了。
      final pending = Completer<void>();
      when(
        () => api.updateCollection(
          any(),
          collectionType: any(named: 'collectionType'),
        ),
      ).thenAnswer((_) => pending.future);
      await pump(tester, null);

      // 中间不 pump：`_busy` 要到下一帧才会改变 `onPressed`，所以拦第二次点击
      // 只能靠 `_setType` 自己进门先判一次。
      await tester.tap(find.text('追番'));
      await tester.tap(find.text('追番'));
      pending.complete();
      await tester.pumpAndSettle();

      verify(
        () => api.updateCollection(1, collectionType: CollectionType.wish),
      ).called(1);
    });
  });
}
