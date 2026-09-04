// lib/ui/player/player_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../app/theme/app_theme.dart';
import '../../data/play/playback_position_storage.dart';
import '../../domain/media/media_registry.dart';
import '../../domain/play/episode_play_controller.dart';
import '../../domain/play/subject_episodes_controller.dart';
import '../../domain/settings/playback_speed_controller.dart';
import '../../domain/settings/proxy_settings_controller.dart';
import '../common/error_retry_view.dart';
import '../home/trending_carousel.dart' show isDesktopPlatform;

/// Playback speed presets offered in the speed-selection menu.
const _playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Below this, resuming would be indistinguishable from starting over, so
/// don't bother seeking (and don't bother persisting positions this
/// small either -- see `_savePosition`).
const _minResumePosition = Duration(seconds: 5);

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.episode,
    required this.subjectId,
    required this.subjectName,
  });

  final MergedEpisode episode;

  /// Together with [subjectName], used to look up the full episode list
  /// (via [subjectEpisodesControllerProvider]) so playback can
  /// auto-advance to the next episode from the same source when the
  /// current one finishes -- see `_maybePlayNextEpisode`.
  final int subjectId;
  final String subjectName;

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

  StreamSubscription<bool>? _completedSubscription;
  bool _hasAdvancedToNextEpisode = false;

  Timer? _savePositionTimer;

  // --- Volume/brightness swipe gesture state ---
  // (see `_handleVerticalDragUpdate`/`_adjustVolume`/`_adjustBrightness`).
  // Values are 0.0-1.0 fractions, matching both plugins' own scale.
  double _volume = 1;
  double _brightness = 1;
  bool _showVolumeHud = false;
  bool _showBrightnessHud = false;
  double? _dragStartX;
  Timer? _hudHideTimer;

  // --- Screenshot feedback ---
  bool _screenshotFlash = false;
  Timer? _screenshotFlashTimer;

  /// Captured once, synchronously, while the widget is still safely
  /// mounted. `_savePosition`/`_clearSavedPosition` need this from
  /// `dispose()` (to do a final save/clear on the way out), and `ref` is
  /// unsafe to touch by the time `dispose()` runs -- Riverpod asserts on
  /// any `ref.read`/`ref.watch` call there ("Using ref when a widget is
  /// about to or has been unmounted is unsafe"). Reading the future here
  /// in `initState` instead avoids ever needing `ref` again for this.
  late final Future<PlaybackPositionStorage> _storageFuture;

  /// Identifies [PlayerScreen.episode] for [PlaybackPositionStorage].
  /// Episodes have no other stable identity than `sourceId` + `title`
  /// (see `MediaEpisode`'s doc comment); combined with `subjectId`, this
  /// is unique enough in practice.
  String get _positionKey =>
      '${widget.subjectId}::${widget.episode.sourceId}::${widget.episode.title}';

  @override
  void initState() {
    super.initState();
    _storageFuture = ref.read(playbackPositionStorageProvider.future);
    _player.stream.error.listen((message) {
      if (mounted) setState(() => _playbackError = message);
    });
    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed) {
        unawaited(_clearSavedPosition());
        _maybePlayNextEpisode();
      }
    });
    // Periodically persist the current position so playback can resume
    // from roughly the same spot after leaving and reopening this
    // episode. A period, rather than saving on every position update, is
    // enough resolution for "resume where I left off" and avoids writing
    // to SharedPreferences several times a second.
    _savePositionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_savePosition()),
    );
    // media_kit's native backend (libmpv/ffmpeg) makes its own network
    // connections and does NOT pick up the app's Dio-configured proxy
    // (see `dioProvider`/`proxy_dio_config.dart`) -- that proxy is wired
    // only into the Dio HTTP client used for metadata API calls, never
    // into the video player. On networks where a playback source's CDN
    // (e.g. 稀饭动漫's `moedot.net`) is only reachable through the
    // configured proxy, this caused every playback attempt to fail with
    // "Failed to open ..." or "tcp: ffurl_read returned ..." even though
    // the app-level proxy setting was already correctly configured and
    // working for all other network calls. Fix: forward the same proxy
    // URL to libmpv via its `http-proxy` property, which ffmpeg's HTTP
    // protocol layer honors for all subsequent network I/O.
    unawaited(_configureProxy());
    // We show our own HUD for volume/brightness swipes (see
    // `_AdjustmentHud`), so suppress each platform's native
    // volume-changed overlay to avoid a duplicate indicator.
    unawaited(FlutterVolumeController.updateShowSystemUI(false));
    unawaited(_initVolumeAndBrightness());
  }

  Future<void> _initVolumeAndBrightness() async {
    try {
      final volume = await FlutterVolumeController.getVolume();
      if (volume != null && mounted) setState(() => _volume = volume);
    } on Object {
      // Best-effort only -- if the platform can't report the current
      // volume, the gesture still works from whatever `_volume` already
      // is, just possibly out of sync with the system value initially.
    }
    if (isDesktopPlatform()) return;
    try {
      final brightness = await ScreenBrightness().application;
      if (mounted) setState(() => _brightness = brightness);
    } on Object {
      // Same rationale as above.
    }
  }

  Future<void> _configureProxy() async {
    final proxyUrl = await ref.read(proxySettingsControllerProvider.future);
    if (proxyUrl == null || proxyUrl.isEmpty) return;
    final platform = _player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('http-proxy', proxyUrl);
    }
  }

  Future<void> _savePosition() async {
    final position = _player.state.position;
    if (position < _minResumePosition) return;
    final storage = await _storageFuture;
    await storage.setPosition(_positionKey, position.inMilliseconds);
  }

  Future<void> _clearSavedPosition() async {
    final storage = await _storageFuture;
    await storage.clearPosition(_positionKey);
  }

  Future<void> _maybeResumePosition() async {
    final storage = await _storageFuture;
    final savedMs = storage.getPosition(_positionKey);
    if (savedMs == null) return;
    await _player.seek(Duration(milliseconds: savedMs));
  }

  /// Records which half of the screen a vertical drag started in --
  /// [_handleVerticalDragUpdate] uses this to decide whether the drag
  /// adjusts brightness (left half) or volume (right half), matching the
  /// convention used by most video apps.
  void _handleVerticalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
  }

  /// Left half of the screen adjusts brightness, right half adjusts
  /// volume -- both by the same fraction of screen height the finger has
  /// moved, so a full-height drag goes from 0% to 100%. Brightness is
  /// skipped entirely on desktop (no touch screen to swipe on, and
  /// mouse-drag-to-dim would be surprising); volume works everywhere.
  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final startX = _dragStartX;
    if (startX == null) return;
    final size = MediaQuery.sizeOf(context);
    final delta = -details.delta.dy / size.height;
    if (startX < size.width / 2) {
      if (isDesktopPlatform()) return;
      unawaited(_adjustBrightness(delta));
    } else {
      unawaited(_adjustVolume(delta));
    }
  }

  Future<void> _adjustVolume(double delta) async {
    final volume = (_volume + delta).clamp(0.0, 1.0);
    setState(() {
      _volume = volume;
      _showVolumeHud = true;
      _showBrightnessHud = false;
    });
    _scheduleHideHud();
    await FlutterVolumeController.setVolume(volume);
  }

  Future<void> _adjustBrightness(double delta) async {
    final brightness = (_brightness + delta).clamp(0.0, 1.0);
    setState(() {
      _brightness = brightness;
      _showBrightnessHud = true;
      _showVolumeHud = false;
    });
    _scheduleHideHud();
    await ScreenBrightness().setApplicationScreenBrightness(brightness);
  }

  void _scheduleHideHud() {
    _hudHideTimer?.cancel();
    _hudHideTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showVolumeHud = false;
          _showBrightnessHud = false;
        });
      }
    });
  }

  /// Saves a screenshot of the current video frame to the device gallery.
  /// `saver_gallery` (unlike media_kit's own `Player.screenshot()`, which
  /// is cross-platform) only ships native implementations for
  /// Android/iOS/OHOS, so desktop gets a plain "not supported" message
  /// instead of a broken attempt.
  Future<void> _takeScreenshot() async {
    if (isDesktopPlatform()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂未支持保存截图')),
        );
      }
      return;
    }
    final bytes = await _player.screenshot();
    if (bytes == null || !mounted) return;
    final result = await SaverGallery.saveImage(
      bytes,
      fileName: 'animeko_${DateTime.now().millisecondsSinceEpoch}.jpg',
      skipIfExists: false,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      _triggerScreenshotFlash();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('截图保存失败：${result.errorMessage}')),
      );
    }
  }

  void _triggerScreenshotFlash() {
    _screenshotFlashTimer?.cancel();
    setState(() => _screenshotFlash = true);
    _screenshotFlashTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _screenshotFlash = false);
    });
  }

  /// Called when media_kit reports playback has run to completion. Looks
  /// up the same-source episode list (via
  /// [subjectEpisodesControllerProvider]) to find the episode right after
  /// [PlayerScreen.episode]; if one exists, replaces this screen with a
  /// fresh [PlayerScreen] for it. Matches episodes by `title` within the
  /// same [MergedEpisode.sourceId] (episodes have no other stable
  /// identity -- see `MediaEpisode`'s doc comment). Guarded by
  /// [_hasAdvancedToNextEpisode] so this only ever fires once per screen
  /// instance, even if media_kit emits `completed: true` more than once.
  void _maybePlayNextEpisode() {
    if (_hasAdvancedToNextEpisode || !mounted) return;
    final episodes = ref
        .read(
          subjectEpisodesControllerProvider(
            subjectId: widget.subjectId,
            subjectName: widget.subjectName,
          ),
        )
        .value;
    if (episodes == null) return;
    final sameSource = episodes
        .where((e) => e.sourceId == widget.episode.sourceId)
        .toList();
    final currentIndex = sameSource.indexWhere(
      (e) => e.title == widget.episode.title,
    );
    if (currentIndex == -1 || currentIndex + 1 >= sameSource.length) return;
    _hasAdvancedToNextEpisode = true;
    final next = sameSource[currentIndex + 1];
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          episode: next,
          subjectId: widget.subjectId,
          subjectName: widget.subjectName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_completedSubscription?.cancel());
    _savePositionTimer?.cancel();
    unawaited(_savePosition());
    _hudHideTimer?.cancel();
    _screenshotFlashTimer?.cancel();
    // Restore each platform's own volume-changed overlay and, on mobile,
    // hand screen brightness back to whatever the system had it at
    // before this screen changed it (neither of these `ref`/context, so
    // -- unlike `_savePosition` -- they're safe to fire from `dispose()`
    // directly, no `_storageFuture`-style caching needed).
    unawaited(FlutterVolumeController.updateShowSystemUI(true));
    if (!isDesktopPlatform()) {
      unawaited(ScreenBrightness().resetApplicationScreenBrightness());
    }
    // media_kit has a known crash where disposing a Player while it is
    // still playing (i.e. without calling `stop()` first) can invoke a
    // native FFI callback after it has already been freed, causing a
    // hard native crash ("Callback invoked after it has been deleted").
    // Calling `stop()` before `dispose()` is the mitigation recommended
    // by media_kit maintainers. See media-kit/media-kit#1324, #1340,
    // #1348 (upstream bug, not fixed in the version pinned in
    // pubspec.lock as of this fix).
    //
    // `State.dispose()` cannot be `async`, so this is fire-and-forget.
    unawaited(_disposePlayer());
    super.dispose();
  }

  Future<void> _disposePlayer() async {
    await _player.stop();
    await _player.dispose();
  }

  void _retry() {
    setState(() => _playbackError = null);
    ref.invalidate(episodePlayControllerProvider(episode: widget.episode));
  }

  @override
  Widget build(BuildContext context) {
    final provider = episodePlayControllerProvider(episode: widget.episode);
    // `player.open` is a command, not a declarative value -- it must run
    // as a side effect exactly once per successful resolution, not on
    // every `build()` (see design doc "数据流" step 3).
    ref.listen(provider, (previous, next) {
      next.whenData(
        (source) async {
          await _player.open(
            Media(
              source.url,
              // Some sources' video CDNs (e.g. anime1.me) reject direct
              // requests without specific headers -- see each concrete
              // MediaPlaybackSource's own `headers` doc comment. Others
              // (e.g. 稀饭动漫) need none, in which case this is empty.
              httpHeaders: source.headers,
            ),
          );
          final speed = await ref.read(playbackSpeedControllerProvider.future);
          await _player.setRate(speed);
          await _maybeResumePosition();
        },
      );
    });
    final playback = ref.watch(provider);

    return Theme(
      data: AppTheme.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: _handleVerticalDragStart,
            onVerticalDragUpdate: _handleVerticalDragUpdate,
            child: Stack(
              children: [
                playback.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
                if (_showVolumeHud)
                  Center(
                    child: _AdjustmentHud(
                      icon: _volumeIcon(_volume),
                      value: _volume,
                    ),
                  ),
                if (_showBrightnessHud)
                  Center(
                    child: _AdjustmentHud(
                      icon: _brightnessIcon(_brightness),
                      value: _brightness,
                    ),
                  ),
                // Screenshot flash feedback -- plain white flash, not a
                // BackdropFilter/blur (see `_AdjustmentHud`'s doc comment
                // for why), ignoring pointer events so it never blocks
                // taps while fading.
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _screenshotFlash ? 0.6 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(color: Colors.white),
                  ),
                ),
                // Floating back button -- the player has no AppBar (to stay
                // immersive/full-bleed), so without this there was no way to
                // leave the screen except system back gestures/shortcuts.
                Positioned(
                  top: 8,
                  left: 8,
                  child: _BackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SourceButton(
                        subjectId: widget.subjectId,
                        subjectName: widget.subjectName,
                        currentEpisode: widget.episode,
                        onSelected: (target) {
                          if (target.sourceId == widget.episode.sourceId) {
                            return;
                          }
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => PlayerScreen(
                                episode: target,
                                subjectId: widget.subjectId,
                                subjectName: widget.subjectName,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _SpeedButton(
                        onSelected: (speed) async {
                          await _player.setRate(speed);
                          await ref
                              .read(playbackSpeedControllerProvider.notifier)
                              .setPlaybackSpeed(speed);
                        },
                      ),
                      const SizedBox(width: 8),
                      _ScreenshotButton(onPressed: _takeScreenshot),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small floating circular back button, styled to sit on top of video
/// content without a full AppBar (which would break the immersive look).
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        tooltip: '返回',
        onPressed: onPressed,
      ),
    );
  }
}

/// A small floating circular button that saves a screenshot of the
/// current video frame to the device gallery (see
/// `_PlayerScreenState._takeScreenshot`).
class _ScreenshotButton extends StatelessWidget {
  const _ScreenshotButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        tooltip: '截图',
        onPressed: onPressed,
      ),
    );
  }
}

/// A small floating pill button showing the current playback speed. Tapping
/// it opens a menu of common speed presets; selecting one applies it to the
/// player and persists it via [PlaybackSpeedController].
class _SpeedButton extends ConsumerWidget {
  const _SpeedButton({required this.onSelected});

  final void Function(double speed) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playbackSpeedControllerProvider).value ?? 1.0;
    return Material(
      color: Colors.black45,
      shape: const StadiumBorder(),
      child: PopupMenuButton<double>(
        tooltip: '播放速度',
        onSelected: onSelected,
        itemBuilder: (context) => _playbackSpeeds
            .map(
              (value) => PopupMenuItem<double>(
                value: value,
                child: Text('${value}x'),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '${speed}x',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

/// A small floating pill button for switching the currently-playing
/// episode to the same episode (matched by [MergedEpisode.title]) from a
/// different [MediaSource]. Renders nothing when fewer than two sources
/// have this episode -- there is nothing to switch to. New sources need
/// no changes here: this only ever lists whatever [mediaSourcesProvider]
/// and [subjectEpisodesControllerProvider] already produce, keyed by
/// [MediaSource.displayName].
class _SourceButton extends ConsumerWidget {
  const _SourceButton({
    required this.subjectId,
    required this.subjectName,
    required this.currentEpisode,
    required this.onSelected,
  });

  final int subjectId;
  final String subjectName;
  final MergedEpisode currentEpisode;
  final void Function(MergedEpisode target) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref
            .watch(
              subjectEpisodesControllerProvider(
                subjectId: subjectId,
                subjectName: subjectName,
              ),
            )
            .value ??
        const <MergedEpisode>[];
    final sameEpisode = episodes
        .where((e) => e.title == currentEpisode.title)
        .toList();
    if (sameEpisode.length <= 1) return const SizedBox.shrink();

    final displayNames = {
      for (final source in ref.watch(mediaSourcesProvider))
        source.id: source.displayName,
    };

    return Material(
      color: Colors.black45,
      shape: const StadiumBorder(),
      child: PopupMenuButton<MergedEpisode>(
        tooltip: '切换播放源',
        onSelected: onSelected,
        itemBuilder: (context) => sameEpisode
            .map(
              (e) => PopupMenuItem<MergedEpisode>(
                value: e,
                child: Row(
                  children: [
                    if (e.sourceId == currentEpisode.sourceId)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.check, size: 16),
                      ),
                    Text(displayNames[e.sourceId] ?? e.sourceId),
                  ],
                ),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayNames[currentEpisode.sourceId] ?? currentEpisode.sourceId,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.expand_more, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon for the volume HUD, chosen from [volume] (0.0-1.0).
IconData _volumeIcon(double volume) {
  if (volume <= 0) return Icons.volume_off;
  if (volume < 0.5) return Icons.volume_down;
  return Icons.volume_up;
}

/// Icon for the brightness HUD, chosen from [brightness] (0.0-1.0).
IconData _brightnessIcon(double brightness) {
  if (brightness < 0.34) return Icons.brightness_low;
  if (brightness < 0.67) return Icons.brightness_medium;
  return Icons.brightness_high;
}

/// Floating feedback shown while a vertical swipe is adjusting volume or
/// brightness (see `_handleVerticalDragUpdate`). Deliberately does not use
/// `BackdropFilter`/`ImageFilter.blur` -- layering either over the video
/// surface is a known source of a native Impeller crash (see
/// flutter/flutter#185506); a plain semi-transparent `Material` avoids it
/// entirely while still reading clearly over video content.
class _AdjustmentHud extends StatelessWidget {
  const _AdjustmentHud({required this.icon, required this.value});

  final IconData icon;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

