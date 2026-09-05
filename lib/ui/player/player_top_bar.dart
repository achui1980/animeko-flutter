// lib/ui/player/player_top_bar.dart
import 'package:flutter/material.dart';

/// Custom top bar for [PlayerScreen], replacing the floating back button
/// that used to sit alone in the top-left corner.
///
/// Purely prop-driven so it is testable without a real [Player] or
/// Riverpod [ProviderScope].
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onScreenshot,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onScreenshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: '返回',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              tooltip: '截图',
              onPressed: onScreenshot,
            ),
          ],
        ),
      ),
    );
  }
}
