// lib/ui/home/trending_carousel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/subject_card.dart';

/// Whether the current platform should show desktop-style left/right
/// arrow buttons on the carousel, matching the reference Animeko app's
/// convention (desktop gets arrows; mobile/web stays pure gesture-swipe).
bool isDesktopPlatform() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// An auto-advancing hero carousel for the home page's "trending"
/// section, built on Flutter's Material 3 `CarouselView.weighted`
/// (matching the reference Animeko app's `HorizontalCenteredHeroCarousel`).
/// Owns its own [CarouselController] and auto-advance [Timer] -- no
/// Riverpod dependency, so it's independently testable (same pattern as
/// Phase D's `SubjectBlurredHeader`/`SubjectTagsRow`).
class TrendingCarousel extends StatefulWidget {
  const TrendingCarousel({super.key, required this.cards, required this.onTap, this.controller});

  final List<SubjectCard> cards;
  final void Function(SubjectCard card) onTap;

  /// Exposed so tests can inspect [CarouselController.offset] after the
  /// auto-advance timer fires. When omitted, the widget creates and owns
  /// its own controller.
  final CarouselController? controller;

  @override
  State<TrendingCarousel> createState() => _TrendingCarouselState();
}

class _TrendingCarouselState extends State<TrendingCarousel> {
  late final CarouselController _controller;
  late final bool _ownsController;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? CarouselController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.cards.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _currentIndex = (_currentIndex + 1) % widget.cards.length;
      _controller.animateToItem(_currentIndex);
    });
  }

  void _pauseTimer() => _timer?.cancel();

  void _goToRelativeIndex(int delta) {
    final count = widget.cards.length;
    _currentIndex = (_currentIndex + delta) % count;
    if (_currentIndex < 0) _currentIndex += count;
    _controller.animateToItem(_currentIndex);
    // Treat an arrow tap like a manual scroll: reset the auto-advance
    // countdown instead of letting it fire again immediately after.
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    final carousel = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _pauseTimer();
        } else if (notification is ScrollEndNotification) {
          _startTimer();
        }
        return false;
      },
      child: CarouselView.weighted(
        controller: _controller,
        flexWeights: const [1, 7, 1],
        itemSnapping: true,
        onTap: (index) => widget.onTap(widget.cards[index]),
        children: widget.cards.map(_buildItem).toList(),
      ),
    );

    if (!isDesktopPlatform() || widget.cards.length <= 1) return carousel;

    return Stack(
      alignment: Alignment.center,
      children: [
        carousel,
        Positioned(
          left: 4,
          child: _ArrowButton(
            icon: Icons.chevron_left,
            tooltip: '上一个',
            onPressed: () => _goToRelativeIndex(-1),
          ),
        ),
        Positioned(
          right: 4,
          child: _ArrowButton(
            icon: Icons.chevron_right,
            tooltip: '下一个',
            onPressed: () => _goToRelativeIndex(1),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(SubjectCard card) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            card.imageUrl ?? '',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: Text(
                card.nameCn ?? card.name,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A semi-transparent circular arrow button overlaid on the carousel,
/// shown only on desktop platforms (see [isDesktopPlatform]) since
/// desktop users have no touch-drag affordance hint the way mobile users
/// do -- matching the reference Animeko app's own desktop-only arrows on
/// its horizontal lists.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
