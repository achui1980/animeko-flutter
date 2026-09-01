// lib/ui/player/player_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../domain/play/episode_play_controller.dart';
import '../common/error_retry_view.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.episodePageUrl});

  final String episodePageUrl;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _player = Player();
  late final _controller = VideoController(_player);

  /// Set when media_kit reports a playback error *after* a source was
  /// already opened successfully (i.e. after `AsyncData` -- see the
  /// design doc's "播放页 - 播放本身失败" row). Address-resolution
  /// failures are handled by `episodePlayControllerProvider`'s own
  /// `AsyncError` instead; this field is strictly for the second kind of
  /// failure.
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    _player.stream.error.listen((message) {
      if (mounted) setState(() => _playbackError = message);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _playbackError = null);
    ref.invalidate(
      episodePlayControllerProvider(episodePageUrl: widget.episodePageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = episodePlayControllerProvider(
      episodePageUrl: widget.episodePageUrl,
    );
    // `player.open` is a command, not a declarative value -- it must run
    // as a side effect exactly once per successful resolution, not on
    // every `build()` (see design doc "数据流" step 3).
    ref.listen(provider, (previous, next) {
      next.whenData(
        (source) => _player.open(
          Media(
            source.url,
            // anime1.me's video CDN rejects direct requests without the
            // exact Referer/Cookie headers `resolvePlaybackUrl` collected
            // for this specific source -- see Anime1PlaybackSource.headers.
            httpHeaders: source.headers,
          ),
        ),
      );
    });
    final playback = ref.watch(provider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: playback.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ErrorRetryView(
            message: '播放失败：$error',
            onRetry: _retry,
          ),
          data: (_) => _playbackError != null
              ? ErrorRetryView(
                  message: '播放失败：$_playbackError',
                  onRetry: _retry,
                )
              // Uses Video's default AdaptiveVideoControls (seek-bar drag,
              // tap to show/hide controls, fullscreen button) -- see this
              // task's "Context" note above for why no custom
              // GestureDetector code is written here.
              : Video(controller: _controller),
        ),
      ),
    );
  }
}
