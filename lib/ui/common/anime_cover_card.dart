import 'package:flutter/material.dart';

/// A vertical anime cover card: a `849:1200`-ratio cover image (matching
/// the reference app's `COVER_WIDTH_TO_HEIGHT_RATIO`) with a title below,
/// on a `surfaceContainerHigh` background and 16dp corner radius.
class AnimeCoverCard extends StatelessWidget {
  const AnimeCoverCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.onTap,
  });

  static const coverAspectRatio = 849 / 1200;

  final String imageUrl;
  final String title;
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
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: coverAspectRatio,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // Shrunk to 70% of the default titleMedium size per user
                // feedback -- the default felt too large for a 2-line title.
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize:
                      (Theme.of(context).textTheme.titleMedium?.fontSize ??
                          16) *
                      0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
