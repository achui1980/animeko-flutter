import 'package:animeko_flutter/ui/settings/settings_split_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders the title and every child row', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSplitGroup(
          title: '通用',
          children: [
            ListTile(title: Text('Row A')),
            ListTile(title: Text('Row B')),
            ListTile(title: Text('Row C')),
          ],
        ),
      ),
    );

    expect(find.text('通用'), findsOneWidget);
    expect(find.text('Row A'), findsOneWidget);
    expect(find.text('Row B'), findsOneWidget);
    expect(find.text('Row C'), findsOneWidget);
  });

  testWidgets('the first and last rows use the outer radius, middle rows use the inner radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSplitGroup(
          title: '通用',
          children: [
            ListTile(title: Text('Row A')),
            ListTile(title: Text('Row B')),
            ListTile(title: Text('Row C')),
          ],
        ),
      ),
    );

    final materials = tester
        .widgetList<Material>(find.byType(Material))
        .where((m) => m.borderRadius != null)
        .toList();

    const outer = SettingsSplitGroup.outerRadius;
    const inner = SettingsSplitGroup.innerRadius;

    expect(materials, hasLength(3));
    // First row: top corners are the outer (group-start) radius, bottom
    // corners are the inner radius (since another row follows).
    expect(
      materials[0].borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(outer),
        topRight: Radius.circular(outer),
        bottomLeft: Radius.circular(inner),
        bottomRight: Radius.circular(inner),
      ),
    );
    // Middle row: all four corners are the inner radius.
    expect(materials[1].borderRadius, BorderRadius.circular(inner));
    // Last row: top corners are the inner radius (a row precedes it),
    // bottom corners are the outer (group-end) radius.
    expect(
      materials[2].borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(inner),
        topRight: Radius.circular(inner),
        bottomLeft: Radius.circular(outer),
        bottomRight: Radius.circular(outer),
      ),
    );
  });
}
