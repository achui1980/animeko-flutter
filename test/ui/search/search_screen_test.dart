import 'package:animeko_flutter/domain/search/search_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_list_item.dart';
import 'package:animeko_flutter/ui/common/empty_view.dart';
import 'package:animeko_flutter/ui/search/search_screen.dart';
import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSearchController extends SearchController {
  _FakeSearchController(this._results);
  final List<SubjectCard> _results;

  @override
  Future<List<SubjectCard>> build() async => _results;
}

Widget _wrap(Widget child, List<SubjectCard> results) {
  return ProviderScope(
    overrides: [searchControllerProvider.overrideWith(() => _FakeSearchController(results))],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows search results as AnimeListItem', (tester) async {
    const results = [
      SubjectCard(
        id: 1,
        name: 'Foo',
        nameCn: 'Foo CN',
        imageUrl: 'https://example.com/1.png',
        tags: ['Action', 'Comedy'],
      ),
    ];
    await tester.pumpWidget(_wrap(const SearchScreen(), results));
    await tester.pumpAndSettle();

    expect(find.byType(AnimeListItem), findsOneWidget);
    expect(find.text('Foo CN'), findsOneWidget);
    expect(find.text('Action, Comedy'), findsOneWidget);
  });

  testWidgets('shows EmptyView when there are no results', (tester) async {
    await tester.pumpWidget(_wrap(const SearchScreen(), const []));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
  });

  testWidgets('AppBar shows the collection action', (tester) async {
    await tester.pumpWidget(_wrap(const SearchScreen(), const []));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
