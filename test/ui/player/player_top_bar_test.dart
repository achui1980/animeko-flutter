// test/ui/player/player_top_bar_test.dart
import 'package:animeko_flutter/ui/player/player_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the title and triggers callbacks on tap', (
    tester,
  ) async {
    var backTapped = false;
    var screenshotTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerTopBar(
            title: '测试标题',
            onBack: () => backTapped = true,
            onScreenshot: () => screenshotTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('测试标题'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backTapped, isTrue);

    await tester.tap(find.byIcon(Icons.camera_alt));
    expect(screenshotTapped, isTrue);
  });

  testWidgets('ellipsizes a long title instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: PlayerTopBar(
              title: '一个非常非常非常非常非常非常长的剧集标题用于测试省略号效果',
              onBack: () {},
              onScreenshot: () {},
            ),
          ),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(
      find.text('一个非常非常非常非常非常非常长的剧集标题用于测试省略号效果'),
    );
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
