import 'package:flutter/material.dart';

/// Shown in place of the local `media_kit` video while
/// `CastController`'s state has a casting status (see
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4
/// step 4). Play/pause/seek here are forwarded to the native cast
/// `AVPlayer` by `PlayerScreen`, not applied to the local player.
///
/// Purely prop-driven, mirroring the bottom bar's testable shape.
class CastPlaceholder extends StatelessWidget {
  const CastPlaceholder({
    super.key,
    required this.deviceName,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
  });

  final String deviceName;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cast_connected, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            '正在投屏到 $deviceName',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
            onPressed: onPlayPause,
          ),
          SizedBox(
            width: 320,
            child: Slider(
              value: position.inMilliseconds
                  .clamp(0, duration.inMilliseconds)
                  .toDouble(),
              max: duration.inMilliseconds > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1,
              onChanged: (value) =>
                  onSeek(Duration(milliseconds: value.round())),
            ),
          ),
        ],
      ),
    );
  }
}
