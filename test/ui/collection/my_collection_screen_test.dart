import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/my_collections_controller.dart';
import 'package:animeko_flutter/ui/collection/my_collection_screen.dart';
import 'package:animeko_flutter/ui/common/anime_list_item.dart';
import 'package:animeko_flutter/ui/common/empty_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

class _FakeMyCollectionsController extends MyCollectionsController {
  _FakeMyCollectionsController(this._page);

  final MyCollectionsPage _page;

  @override
  Future<MyCollectionsPage> build({required CollectionType? type}) async => _page;
}

Widget _wrap(MyCollectionsPage page, {SubjectApi? subjectApi}) {
  return ProviderScope(
    overrides: [
      myCollectionsControllerProvider.overrideWith2(
        (type) => _FakeMyCollectionsController(page),
      ),
      if (subjectApi != null) subjectApiProvider.overrideWithValue(subjectApi),
    ],
    child: const MaterialApp(home: MyCollectionScreen()),
  );
}

void main() {
  group('MyCollectionScreen', () {
    testWidgets('shows collection items as AnimeListItem', (tester) async {
      const page = MyCollectionsPage(
        items: [
          MyCollectionSubject(subjectId: 1, name: 'Foo', nameCn: 'Foo CN'),
          MyCollectionSubject(subjectId: 2, name: 'Bar', nameCn: 'Bar CN'),
        ],
        hasMore: false,
      );

      await tester.pumpWidget(_wrap(page));
      await tester.pump();

      expect(find.byType(AnimeListItem), findsNWidgets(2));
      expect(find.text('Foo CN'), findsOneWidget);
      expect(find.text('Bar CN'), findsOneWidget);
    });

    testWidgets('shows EmptyView when there are no items', (tester) async {
      const page = MyCollectionsPage(items: [], hasMore: false);

      await tester.pumpWidget(_wrap(page));
      await tester.pump();

      expect(find.byType(EmptyView), findsOneWidget);
    });

    testWidgets('tapping the edit icon shows a status menu on each item', (tester) async {
      const page = MyCollectionsPage(
        items: [MyCollectionSubject(subjectId: 1, name: 'Foo', nameCn: 'Foo CN')],
        hasMore: false,
      );

      await tester.pumpWidget(_wrap(page));
      await tester.pump();

      expect(find.byType(PopupMenuButton<String>), findsNothing);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('selecting a new status in edit mode calls updateCollection', (tester) async {
      final api = MockSubjectApi();
      when(
        () => api.updateCollection(any(), collectionType: any(named: 'collectionType')),
      ).thenAnswer((_) async {});
      const page = MyCollectionsPage(
        items: [MyCollectionSubject(subjectId: 1, name: 'Foo', nameCn: 'Foo CN')],
        hasMore: false,
      );

      await tester.pumpWidget(_wrap(page, subjectApi: api));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('看过').last);
      await tester.pumpAndSettle();

      verify(() => api.updateCollection(1, collectionType: CollectionType.done)).called(1);
    });

    testWidgets('selecting 移除收藏 in edit mode calls deleteCollection', (tester) async {
      final api = MockSubjectApi();
      when(() => api.deleteCollection(any())).thenAnswer((_) async {});
      const page = MyCollectionsPage(
        items: [MyCollectionSubject(subjectId: 1, name: 'Foo', nameCn: 'Foo CN')],
        hasMore: false,
      );

      await tester.pumpWidget(_wrap(page, subjectApi: api));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      final removeItem = find.text('移除收藏', skipOffstage: false);
      await tester.ensureVisible(removeItem);
      await tester.pump();
      await tester.tap(removeItem);
      await tester.pumpAndSettle();

      verify(() => api.deleteCollection(1)).called(1);
    });
  });
}
