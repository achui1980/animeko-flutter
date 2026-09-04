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
  const SubjectBlurredHeader({super.key, required this.imageUrl, this.info});

  static const height = 240.0;
  static const coverAspectRatio = 849 / 1200;

  final String imageUrl;

  /// Optional content (title/rating/collection buttons) rendered next
  /// to the sharp foreground thumbnail, so the header itself carries
  /// the subject's identity instead of leaving that entirely to a
  /// separate section below (Kazumi's `bangumi_info_card.dart` overlays
  /// this same information inside its header area).
  final Widget? info;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final blurSigma = mediaQuery.size.width < 600 ? 16.0 : 32.0;

    // Decode the blurred background at half resolution (Kazumi's
    // `_InfoHeaderBackground` pattern: `downsample=0.5`) -- a Gaussian
    // blur's cost scales with pixel count, and blurring away detail at
    // sigma 16-32 makes decoding at full resolution first pure waste.
    // `cacheWidth`/`cacheHeight` tell Flutter's image codec to decode at
    // this smaller size directly, rather than decode-full-then-downscale.
    final cacheWidth = (mediaQuery.size.width * mediaQuery.devicePixelRatio * 0.5).round();
    final cacheHeight = (height * mediaQuery.devicePixelRatio * 0.5).round();

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
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
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
                  if (info != null)
                    Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: info!)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
