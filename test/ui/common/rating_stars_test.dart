import 'package:animeko_flutter/ui/common/rating_stars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RatingStars', () {
    testWidgets('score of 10 shows 5 filled stars and "10.0"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RatingStars(score: 10))),
      );

      expect(find.byIcon(Icons.star), findsNWidgets(5));
      expect(find.byIcon(Icons.star_half), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(find.text('10.0'), findsOneWidget);
    });

    testWidgets('score of 0 shows 5 empty stars', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RatingStars(score: 0))),
      );

      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      expect(find.text('0.0'), findsOneWidget);
    });

    testWidgets('score of 7 shows 3 filled, 1 half, 1 empty star', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RatingStars(score: 7))),
      );

      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_half), findsNWidgets(1));
      expect(find.byIcon(Icons.star_border), findsNWidgets(1));
      expect(find.text('7.0'), findsOneWidget);
    });
  });
}
