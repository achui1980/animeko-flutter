// lib/ui/common/rating_stars.dart
import 'package:flutter/material.dart';

/// A row of 5 star icons (filled/half/empty) representing a 0-10 score,
/// plus the raw numeric score printed next to them. Read-only display,
/// no interaction.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.score});

  /// 0-10 scale (Bangumi's convention, matching [SubjectDetail.score]
  /// once parsed from its string-encoded wire format).
  final double score;

  @override
  Widget build(BuildContext context) {
    final starValue = score / 2; // 0-10 -> 0-5 stars
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) _starIcon(starValue - i),
        const SizedBox(width: 4),
        Text(score.toStringAsFixed(1)),
      ],
    );
  }

  Widget _starIcon(double diff) {
    final IconData icon;
    if (diff >= 1) {
      icon = Icons.star;
    } else if (diff >= 0.5) {
      icon = Icons.star_half;
    } else {
      icon = Icons.star_border;
    }
    return Icon(icon, size: 18, color: Colors.amber);
  }
}
