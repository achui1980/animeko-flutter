// lib/ui/home/trending_carousel.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/subject_card.dart';

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

  @override
  void dispose() {
    _timer?.cancel();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return NotificationListener<ScrollNotification>(
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
