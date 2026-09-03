import 'package:animeko_flutter/domain/home/home_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_cover_card.dart';
import 'package:animeko_flutter/ui/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHomeController extends HomeController {
  @override
  Future<HomeData> build() async {
    return const HomeData(
      trending: [
        SubjectCard(id: 1, name: 'Foo', nameCn: 'Foo', imageUrl: 'https://example.com/1.png'),
      ],
      recommendations: [
        SubjectCard(id: 2, name: 'Bar', nameCn: 'Bar', imageUrl: 'https://example.com/2.png'),
      ],
    );
  }
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [homeControllerProvider.overrideWith(() => _FakeHomeController())],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows trending and recommended sections using AnimeCoverCard', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Foo'), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);
    expect(find.byType(AnimeCoverCard), findsNWidgets(2));
  });

  testWidgets('AppBar shows the unified account/collection/settings actions', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
