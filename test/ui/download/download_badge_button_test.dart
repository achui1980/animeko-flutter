import 'package:animeko_flutter/ui/download/download_badge_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildButton({
    DownloadButtonState state = DownloadButtonState.idle,
    int activeCount = 0,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DownloadBadgeButton(
          downloadState: state,
          activeCount: activeCount,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  for (final (state, icon) in [
    (DownloadButtonState.idle, Icons.download_outlined),
    (DownloadButtonState.queued, Icons.schedule),
    (DownloadButtonState.downloading, Icons.downloading),
    (DownloadButtonState.completed, Icons.download_done),
  ]) {
    testWidgets('shows the correct icon for $state', (tester) async {
      await tester.pumpWidget(buildButton(state: state));

      expect(find.byIcon(icon), findsOneWidget);
    });
  }

  testWidgets('tapping the button invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildButton(onTap: () => tapped = true));

    await tester.tap(find.byType(IconButton));

    expect(tapped, isTrue);
  });

  testWidgets('shows a numeric badge when activeCount is greater than zero', (
    tester,
  ) async {
    await tester.pumpWidget(buildButton(activeCount: 3));

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('hides the badge when activeCount is zero', (tester) async {
    await tester.pumpWidget(buildButton(activeCount: 0));

    expect(find.text('0'), findsNothing);
  });

  testWidgets('uses a custom tooltip when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadBadgeButton(
            downloadState: DownloadButtonState.idle,
            activeCount: 0,
            onTap: () {},
            tooltip: '下载管理',
          ),
        ),
      ),
    );

    expect(find.byTooltip('下载管理'), findsOneWidget);
  });
}
