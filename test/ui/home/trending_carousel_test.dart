import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/home/trending_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cards = [
  SubjectCard(id: 1, name: 'Foo', nameCn: 'Foo', imageUrl: 'https://example.com/1.png'),
  SubjectCard(id: 2, name: 'Bar', nameCn: 'Bar', imageUrl: 'https://example.com/2.png'),
  SubjectCard(id: 3, name: 'Baz', nameCn: 'Baz', imageUrl: 'https://example.com/3.png'),
];

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(height: 200, child: child)),
  );
}

void main() {
  testWidgets("renders a CarouselView with each card's title", (tester) async {
    await tester.pumpWidget(_wrap(const TrendingCarousel(cards: _cards, onTap: _noop)));
    await tester.pump();

    expect(find.byType(CarouselView), findsOneWidget);
    // CarouselView.weighted's [1, 7, 1] hero pattern only surfaces a peek
    // of each neighboring item at rest, so with exactly 3 cards only the
    // first two are visible without scrolling -- the third becomes visible
    // once dragged into view, same as it would for a real user.
    expect(find.text('Foo'), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Baz'),
      find.byType(CarouselView),
      const Offset(-50, 0),
      maxIteration: 20,
    );
    await tester.pumpAndSettle();
    expect(find.text('Baz'), findsOneWidget);
  });

  testWidgets('tapping an item calls onTap with that card', (tester) async {
    SubjectCard? tapped;
    await tester.pumpWidget(
      _wrap(TrendingCarousel(cards: _cards, onTap: (card) => tapped = card)),
    );
    await tester.pump();

    await tester.tap(find.text('Foo'));
    await tester.pump();

    expect(tapped?.id, 1);
  });

  testWidgets('renders nothing when there are no cards', (tester) async {
    await tester.pumpWidget(_wrap(const TrendingCarousel(cards: [], onTap: _noop)));
    await tester.pump();

    expect(find.byType(CarouselView), findsNothing);
  });

  testWidgets('auto-advances to the next item after 5 seconds', (tester) async {
    final controller = CarouselController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(TrendingCarousel(cards: _cards, onTap: _noop, controller: controller)),
    );
    await tester.pump();

    expect(controller.offset, 0.0);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 350));

    expect(controller.offset, greaterThan(0.0));
  });
}

void _noop(SubjectCard card) {}
