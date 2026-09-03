import 'package:animeko_flutter/ui/common/app_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('buildStandardActions returns a single collection icon button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              Scaffold(appBar: AppBar(actions: buildStandardActions(context))),
        ),
      ),
    );

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
  });
}
