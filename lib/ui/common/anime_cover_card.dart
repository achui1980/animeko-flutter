import 'package:flutter/material.dart';

/// A vertical anime cover card: a `849:1200`-ratio cover image (matching
/// the reference app's `COVER_WIDTH_TO_HEIGHT_RATIO`) with a title below,
/// on a `surfaceContainerHigh` background and 16dp corner radius.
class AnimeCoverCard extends StatelessWidget {
  const AnimeCoverCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.scoreBadge,
    this.onTap,
  });

  static const coverAspectRatio = 849 / 1200;

  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? scoreBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: coverAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                  if (scoreBadge case final score? when score.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Semantics(
                        label: '评分 $score',
                        container: true,
                        excludeSemantics: true,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Text(
                              score,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // Shrunk to 90% of the default titleMedium size per user
                    // feedback -- the default felt too large for a 2-line title.
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize:
                          (Theme.of(context).textTheme.titleMedium?.fontSize ??
                              16) *
                          0.9,
                    ),
                  ),
                  if (subtitle case final subtitle? when subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
