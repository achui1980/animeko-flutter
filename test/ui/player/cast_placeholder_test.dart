import 'package:animeko_flutter/ui/player/cast_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildPlaceholder({
    String deviceName = '客厅电视',
    bool isPlaying = false,
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 10),
    VoidCallback? onPlayPause,
    ValueChanged<Duration>? onSeek,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CastPlaceholder(
          deviceName: deviceName,
          isPlaying: isPlaying,
          position: position,
          duration: duration,
          onPlayPause: onPlayPause ?? () {},
          onSeek: onSeek ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('shows the casting-to-device message', (tester) async {
    await tester.pumpWidget(buildPlaceholder(deviceName: '客厅电视'));
    expect(find.text('正在投屏到 客厅电视'), findsOneWidget);
  });

  testWidgets('shows play icon when paused and pause icon when playing', (
    tester,
  ) async {
    await tester.pumpWidget(buildPlaceholder(isPlaying: false));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.pumpWidget(buildPlaceholder(isPlaying: true));
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('tapping play/pause invokes onPlayPause', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildPlaceholder(onPlayPause: () => tapped = true));

    await tester.tap(find.byIcon(Icons.play_arrow));

    expect(tapped, isTrue);
  });

  testWidgets('dragging the progress bar invokes onSeek', (tester) async {
    Duration? seekedTo;
    await tester.pumpWidget(
      buildPlaceholder(
        duration: const Duration(minutes: 10),
        onSeek: (value) => seekedTo = value,
      ),
    );

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(50, 0));

    expect(seekedTo, isNotNull);
  });
}
