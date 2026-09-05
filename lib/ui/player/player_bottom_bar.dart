// lib/ui/player/player_bottom_bar.dart
import 'package:flutter/material.dart';

/// Custom bottom bar for [PlayerScreen], replacing both media_kit_video's
/// default `AdaptiveVideoControls` bar and the app's old floating
/// top-right button row (`_SourceButton`/`_SpeedButton`/`_ScreenshotButton`).
///
/// Purely prop-driven so it is testable without a real [Player] or
/// Riverpod [ProviderScope]. `_PlayerScreenState` is responsible for
/// reading/writing the actual [Player] and providers and passing the
/// resulting values in as props.
class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    required this.currentSpeed,
    required this.speedOptions,
    required this.onSpeedSelected,
    required this.onDrawerToggle,
    required this.onFullscreenToggle,
    required this.isFullscreen,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final double currentSpeed;
  final List<double> speedOptions;
  final ValueChanged<double> onSpeedSelected;
  final VoidCallback onDrawerToggle;
  final VoidCallback onFullscreenToggle;
  final bool isFullscreen;

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = duration.inMilliseconds;
    final sliderMax = durationMs > 0 ? durationMs.toDouble() : 1.0;
    final sliderValue = durationMs > 0
        ? position.inMilliseconds.clamp(0, durationMs).toDouble()
        : 0.0;

    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              tooltip: isPlaying ? '暂停' : '播放',
              onPressed: onPlayPause,
            ),
            Text(
              _formatDuration(position),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: Slider(
                value: sliderValue,
                max: sliderMax,
                onChanged: durationMs > 0
                    ? (value) =>
                          onSeek(Duration(milliseconds: value.round()))
                    : null,
              ),
            ),
            Text(
              _formatDuration(duration),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            PopupMenuButton<double>(
              tooltip: '播放速度',
              onSelected: onSpeedSelected,
              itemBuilder: (context) => [
                for (final speed in speedOptions)
                  PopupMenuItem<double>(value: speed, child: Text('${speed}x')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${currentSpeed}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.playlist_play, color: Colors.white),
              tooltip: '选集',
              onPressed: onDrawerToggle,
            ),
            IconButton(
              icon: Icon(
                isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              tooltip: isFullscreen ? '退出全屏' : '全屏',
              onPressed: onFullscreenToggle,
            ),
          ],
        ),
      ),
    );
  }
}
