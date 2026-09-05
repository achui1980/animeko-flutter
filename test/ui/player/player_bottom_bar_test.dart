// test/ui/player/player_bottom_bar_test.dart
import 'package:animeko_flutter/ui/player/player_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildBar({
    bool isPlaying = false,
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 10),
    VoidCallback? onPlayPause,
    ValueChanged<Duration>? onSeek,
    double currentSpeed = 1.0,
    ValueChanged<double>? onSpeedSelected,
    VoidCallback? onDrawerToggle,
    VoidCallback? onFullscreenToggle,
    bool isFullscreen = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PlayerBottomBar(
          isPlaying: isPlaying,
          position: position,
          duration: duration,
          onPlayPause: onPlayPause ?? () {},
          onSeek: onSeek ?? (_) {},
          currentSpeed: currentSpeed,
          speedOptions: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
          onSpeedSelected: onSpeedSelected ?? (_) {},
          onDrawerToggle: onDrawerToggle ?? () {},
          onFullscreenToggle: onFullscreenToggle ?? () {},
          isFullscreen: isFullscreen,
        ),
      ),
    );
  }

  testWidgets('shows play icon when paused and pause icon when playing', (
    tester,
  ) async {
    await tester.pumpWidget(buildBar(isPlaying: false));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.pumpWidget(buildBar(isPlaying: true));
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('tapping play/pause invokes onPlayPause', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildBar(onPlayPause: () => tapped = true));

    await tester.tap(find.byIcon(Icons.play_arrow));

    expect(tapped, isTrue);
  });

  testWidgets('shows formatted position and duration labels', (tester) async {
    await tester.pumpWidget(
      buildBar(
        position: const Duration(minutes: 1, seconds: 5),
        duration: const Duration(minutes: 10),
      ),
    );

    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('dragging the progress bar invokes onSeek', (tester) async {
    Duration? seekedTo;
    await tester.pumpWidget(
      buildBar(
        duration: const Duration(minutes: 10),
        onSeek: (value) => seekedTo = value,
      ),
    );

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(50, 0));

    expect(seekedTo, isNotNull);
  });

  testWidgets('selecting a speed from the popup invokes onSpeedSelected', (
    tester,
  ) async {
    double? selectedSpeed;
    await tester.pumpWidget(
      buildBar(currentSpeed: 1.0, onSpeedSelected: (v) => selectedSpeed = v),
    );

    expect(find.text('1.0x'), findsOneWidget);

    await tester.tap(find.text('1.0x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2.0x').last);
    await tester.pumpAndSettle();

    expect(selectedSpeed, 2.0);
  });

  testWidgets('tapping the drawer icon invokes onDrawerToggle', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(buildBar(onDrawerToggle: () => tapped = true));

    await tester.tap(find.byIcon(Icons.playlist_play));

    expect(tapped, isTrue);
  });

  testWidgets(
    'shows fullscreen icon when not fullscreen and fullscreen_exit when fullscreen',
    (tester) async {
      await tester.pumpWidget(buildBar(isFullscreen: false));
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);

      await tester.pumpWidget(buildBar(isFullscreen: true));
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    },
  );

  testWidgets('tapping the fullscreen icon invokes onFullscreenToggle', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      buildBar(onFullscreenToggle: () => tapped = true),
    );

    await tester.tap(find.byIcon(Icons.fullscreen));

    expect(tapped, isTrue);
  });
}
