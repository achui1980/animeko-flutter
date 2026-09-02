import 'package:animeko_flutter/app/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pagePadding returns 16 below the 600px breakpoint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    double? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = pagePadding(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(result, 16.0);
  });

  testWidgets('pagePadding returns 24 at/above the 600px breakpoint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    double? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = pagePadding(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(result, 24.0);
  });
}
