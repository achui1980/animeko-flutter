// lib/ui/subject/subject_blurred_header.dart
import 'dart:ui';

import 'package:flutter/material.dart';

/// The subject detail page's immersive header: the cover image blurred
/// and stretched to fill the header's full width/height, with a
/// top-to-bottom gradient fading into the page background, and the
/// actual (unblurred) cover thumbnail overlaid at the bottom-left in
/// its native 849:1200 aspect ratio with 16dp rounded corners.
///
/// A simplified version of the reference app's `SubjectBlurredBackground`
/// (blur radius 16dp on compact widths, 32dp on wide widths) --
/// deliberately does NOT extract a dynamic color theme from the cover
/// image (excluded scope, see the design doc's "明确排除范围").
class SubjectBlurredHeader extends StatelessWidget {
  const SubjectBlurredHeader({super.key, required this.imageUrl});

  static const height = 240.0;
  static const coverAspectRatio = 849 / 1200;

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final blurSigma = MediaQuery.of(context).size.width < 600 ? 16.0 : 32.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: colorScheme.surfaceContainerHighest),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, colorScheme.surface],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: coverAspectRatio,
                  child: SizedBox(
                    width: 120,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
