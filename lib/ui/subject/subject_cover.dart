// lib/ui/subject/subject_cover.dart
import 'package:flutter/material.dart';

/// The subject cover image, rounded and clipped to the reference app's
/// 849:1200 poster aspect ratio.
///
/// Lives in its own file because two different layouts need it at two
/// different widths: the wide-screen left column (200dp) and the narrow
/// -screen horizontal top header (120dp).
///
/// [imageUrl] is nullable because no subject endpoint returns a cover --
/// it arrives as a route query parameter (see `SubjectDetailScreen`), so
/// deep links without it must still render.
class SubjectCover extends StatelessWidget {
  const SubjectCover({super.key, required this.imageUrl, required this.width});

  /// The reference app's poster ratio (`849:1200`), same value the old
  /// `SubjectBlurredHeader` used for its sharp thumbnail.
  static const double aspectRatio = 849 / 1200;

  final String? imageUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: url == null
              ? _placeholder(context)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholder(context),
                ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}
