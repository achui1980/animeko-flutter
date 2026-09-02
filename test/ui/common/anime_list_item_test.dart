import 'package:animeko_flutter/ui/common/anime_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AnimeListItem renders title, subtitle, and is 148dp tall', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimeListItem(
            imageUrl: 'https://example.com/cover.jpg',
            title: 'Frieren',
            subtitle: '第 12 集',
          ),
        ),
      ),
    );

    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('第 12 集'), findsOneWidget);
    final size = tester.getSize(find.byType(AnimeListItem));
    expect(size.height, 148.0);
  });

  testWidgets('AnimeListItem calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeListItem(
            imageUrl: 'https://example.com/cover.jpg',
            title: 'Frieren',
            subtitle: '第 12 集',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AnimeListItem));
    expect(tapped, isTrue);
  });
}
