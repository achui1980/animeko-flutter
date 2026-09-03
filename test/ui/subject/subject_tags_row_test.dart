import 'package:animeko_flutter/data/search/search_models.dart';
import 'package:animeko_flutter/ui/common/tag_chip.dart';
import 'package:animeko_flutter/ui/subject/subject_tags_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubjectTagsRow', () {
    testWidgets('renders a TagChip per tag with "name count" labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectTagsRow(
              tags: [
                SubjectTag(name: '战斗', count: 120),
                SubjectTag(name: '奇幻', count: 80),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(TagChip), findsNWidgets(2));
      expect(find.text('战斗 120'), findsOneWidget);
      expect(find.text('奇幻 80'), findsOneWidget);
    });

    testWidgets('renders nothing when there are no tags', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SubjectTagsRow(tags: []))),
      );

      expect(find.byType(TagChip), findsNothing);
    });
  });
}
