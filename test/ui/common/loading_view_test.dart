import 'package:animeko_flutter/ui/common/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LoadingView shows a centered CircularProgressIndicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LoadingView())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Center), findsWidgets);
  });
}
