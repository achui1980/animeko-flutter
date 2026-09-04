import 'package:animeko_flutter/ui/common/empty_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EmptyView renders the given icon and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyView(icon: Icons.inbox_outlined, message: '还没有收藏任何番剧'),
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('还没有收藏任何番剧'), findsOneWidget);
  });

  testWidgets('EmptyView defaults to Icons.inbox_outlined when no icon is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmptyView(message: '没有数据'))),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('EmptyView wraps the icon in a circular tonal badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmptyView(message: '没有数据'))),
    );

    final badge = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(Icons.inbox_outlined),
        matching: find.byType(Container),
      ),
    );
    final decoration = badge.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
  });
}
