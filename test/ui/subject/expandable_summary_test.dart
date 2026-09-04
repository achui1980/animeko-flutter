import 'package:animeko_flutter/ui/subject/expandable_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpandableSummary', () {
    testWidgets('renders nothing when text is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExpandableSummary(text: ''))),
      );

      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('展开'), findsNothing);
    });

    testWidgets('short text shows no 展开 button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExpandableSummary(text: 'A short summary.'))),
      );

      expect(find.text('展开'), findsNothing);
      expect(find.text('A short summary.'), findsOneWidget);
    });

    testWidgets('long text shows a 展开 button that toggles to 收起', (tester) async {
      final longText = List.generate(50, (i) => 'word$i').join(' ');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 100, child: ExpandableSummary(text: longText, maxLines: 2)),
          ),
        ),
      );

      expect(find.text('展开'), findsOneWidget);

      await tester.tap(find.text('展开'));
      await tester.pump();

      expect(find.text('收起'), findsOneWidget);
      expect(find.text('展开'), findsNothing);
    });
  });
}
