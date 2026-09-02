import 'package:animeko_flutter/ui/common/anime_cover_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AnimeCoverCard renders the title and an AspectRatio matching 849:1200',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              child: AnimeCoverCard(
                imageUrl: 'https://example.com/cover.jpg',
                title: 'Frieren',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Frieren'), findsOneWidget);
      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, closeTo(849 / 1200, 0.0001));
    },
  );

  testWidgets('AnimeCoverCard calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            child: AnimeCoverCard(
              imageUrl: 'https://example.com/cover.jpg',
              title: 'Frieren',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AnimeCoverCard));
    expect(tapped, isTrue);
  });
}
