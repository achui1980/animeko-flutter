// lib/ui/download/download_badge_button.dart
import 'package:flutter/material.dart';

/// The visual state of a single episode's download button. Moved here
/// from `player_top_bar.dart` -- this widget is now shared by the home
/// screen, the subject detail "选集" header, and the player bottom bar,
/// not just the player.
enum DownloadButtonState { idle, queued, downloading, completed }

/// A download icon button with an optional numeric badge showing how
/// many episodes are currently downloading (queued or in progress).
///
/// Purely prop-driven so it is testable without a real
/// [DownloadQueueController] or Riverpod [ProviderScope]. Callers own
/// computing [downloadState] and [activeCount] from their own context
/// (e.g. a single episode's state for the player, or a whole subject's
/// active-download count for the subject detail header).
class DownloadBadgeButton extends StatelessWidget {
  const DownloadBadgeButton({
    super.key,
    required this.downloadState,
    required this.activeCount,
    required this.onTap,
    this.iconColor,
    this.tooltip = '下载',
  });

  final DownloadButtonState downloadState;

  /// Number of episodes currently queued or downloading that this button
  /// represents. `0` hides the badge entirely.
  final int activeCount;
  final VoidCallback onTap;

  /// Overrides the icon's color. `null` uses the ambient icon theme --
  /// appropriate for a normal Material [AppBar]. The player bottom bar
  /// passes `Colors.white` explicitly to match its other icons, which
  /// are rendered over a dark video background rather than a themed
  /// surface.
  final Color? iconColor;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(_icon, color: iconColor),
          tooltip: tooltip,
          onPressed: onTap,
        ),
        if (activeCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Text(
                  '$activeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData get _icon => switch (downloadState) {
    DownloadButtonState.idle => Icons.download_outlined,
    DownloadButtonState.queued => Icons.schedule,
    DownloadButtonState.downloading => Icons.downloading,
    DownloadButtonState.completed => Icons.download_done,
  };
}
