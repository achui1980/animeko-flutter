import 'package:animeko_flutter/ui/common/app_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('buildStandardActions returns 3 icon buttons: account, collection, settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              Scaffold(appBar: AppBar(actions: buildStandardActions(context))),
        ),
      ),
    );

    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byType(IconButton), findsNWidgets(3));
  });
}
