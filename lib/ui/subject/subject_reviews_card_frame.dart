// lib/ui/subject/subject_reviews_card_frame.dart
import 'package:flutter/material.dart';

import 'subject_side_card.dart';

/// The 热门评价 card shell, shared by [SubjectReviewsCard]'s loading and
/// data branches so the frame is identical in both (no layout jump).
class SubjectReviewsCardFrame extends StatelessWidget {
  const SubjectReviewsCardFrame({
    super.key,
    required this.child,
    this.onSeeAll,
  });

  final Widget child;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SubjectSideCard(
      title: '热门评价',
      trailing: onSeeAll == null
          ? null
          : TextButton(onPressed: onSeeAll, child: const Text('查看全部 ›')),
      child: child,
    );
  }
}
