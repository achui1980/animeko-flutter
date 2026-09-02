import 'package:animeko_flutter/ui/common/tag_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TagChip renders its label text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TagChip(label: 'TV'))),
    );
    expect(find.text('TV'), findsOneWidget);
  });

  testWidgets('TagChip is 32dp tall with an outlineVariant border', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TagChip(label: 'TV'))),
    );
    final container = tester.widget<Container>(
      find
          .descendant(of: find.byType(TagChip), matching: find.byType(Container))
          .first,
    );
    expect(container.constraints?.maxHeight ?? (container.constraints?.minHeight), 32.0);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect((decoration.borderRadius as BorderRadius).topLeft.x, 8.0);
  });
}
