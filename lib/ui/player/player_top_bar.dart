// lib/ui/player/player_top_bar.dart
import 'package:flutter/material.dart';

import 'airplay_button.dart';

/// Custom top bar for [PlayerScreen], replacing the floating back button
/// that used to sit alone in the top-left corner.
///
/// The download button that used to live here has moved to
/// [PlayerBottomBar] (see the download UX overhaul design doc's decision
/// that neither the player's nor the subject page's download entry point
/// belongs in a top-right corner) -- [DownloadButtonState] now lives in
/// `download_badge_button.dart`, shared by the bottom bar, the subject
/// detail page, and the home screen.
///
/// Purely prop-driven so it is testable without a real [Player] --
/// except for [AirPlayButton], which is a `ConsumerStatefulWidget` (see
/// `airplay_button.dart`), so callers must still wrap this widget in a
/// Riverpod `ProviderScope` in tests.
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onScreenshot,
    required this.castButtonVisible,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onScreenshot;

  /// Whether the current playback candidate is cast-eligible (see
  /// `isCastable` in `lib/domain/play/cast_eligibility.dart`). The
  /// AirPlay button is fully hidden, not grayed out, when false.
  final bool castButtonVisible;

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
            AirPlayButton(visible: castButtonVisible),
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
