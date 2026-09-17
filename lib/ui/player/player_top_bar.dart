// lib/ui/player/player_top_bar.dart
import 'package:flutter/material.dart';

enum DownloadButtonState { idle, queued, downloading, completed }

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
    required this.onDownload,
    required this.downloadState,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onScreenshot;
  final VoidCallback? onDownload;
  final DownloadButtonState downloadState;

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
            if (onDownload != null)
              IconButton(
                icon: Icon(_downloadIcon, color: Colors.white),
                tooltip: '下载',
                onPressed: onDownload,
              ),
          ],
        ),
      ),
    );
  }

  IconData get _downloadIcon => switch (downloadState) {
    DownloadButtonState.idle => Icons.download_outlined,
    DownloadButtonState.queued => Icons.schedule,
    DownloadButtonState.downloading => Icons.downloading,
    DownloadButtonState.completed => Icons.download_done,
  };
}
