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

  testWidgets('AnimeCoverCard renders an optional subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            child: AnimeCoverCard(
              imageUrl: 'https://example.com/cover.jpg',
              title: 'Frieren',
              subtitle: '第1话 · 22:00',
            ),
          ),
        ),
      ),
    );

    expect(find.text('第1话 · 22:00'), findsOneWidget);
  });

  testWidgets('AnimeCoverCard renders a supplied score badge on the cover', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            child: AnimeCoverCard(
              imageUrl: 'https://example.com/cover.jpg',
              title: 'Frieren',
              scoreBadge: '7.8',
            ),
          ),
        ),
      ),
    );

    expect(find.text('7.8'), findsOneWidget);
    expect(find.bySemanticsLabel('评分 7.8'), findsOneWidget);
    expect(find.bySemanticsLabel('7.8'), findsNothing);
    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byType(AnimeCoverCard),
        matching: find.byType(Stack),
      ),
    );
    expect(stack.fit, StackFit.expand);
    final positionedFinder = find.descendant(
      of: find.byType(AnimeCoverCard),
      matching: find.byType(Positioned),
    );
    final positioned = tester.widget<Positioned>(positionedFinder);
    expect(positioned.right, 6);
    expect(positioned.bottom, 6);
    expect(
      find.descendant(
        of: positionedFinder,
        matching: find.byType(DecoratedBox),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('AnimeCoverCard omits a null score badge', (tester) async {
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

    expect(
      find.descendant(
        of: find.byType(AnimeCoverCard),
        matching: find.byType(Positioned),
      ),
      findsNothing,
    );
  });

  testWidgets('AnimeCoverCard omits an empty score badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            child: AnimeCoverCard(
              imageUrl: 'https://example.com/cover.jpg',
              title: 'Frieren',
              scoreBadge: '',
            ),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(AnimeCoverCard),
        matching: find.byType(Positioned),
      ),
      findsNothing,
    );
  });

  testWidgets('AnimeCoverCard renders a whitespace-only score badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            child: AnimeCoverCard(
              imageUrl: 'https://example.com/cover.jpg',
              title: 'Frieren',
              scoreBadge: ' ',
            ),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(AnimeCoverCard),
        matching: find.byType(Positioned),
      ),
      findsOneWidget,
    );
  });
}
