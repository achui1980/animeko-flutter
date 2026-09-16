// lib/ui/subject/subject_side_card.dart
import 'package:flutter/material.dart';

/// The shared visual frame for the three right-column cards (评分 /
/// 热门评价 / 制作人员) on the subject detail page.
///
/// Reference-app style: a filled rounded surface with a small title on
/// the left of the header row and an optional action (`查看全部 ›` /
/// `☆ 打分`) on the right. Defined once here so the three cards cannot
/// drift apart visually.
///
/// In the narrow (< [subjectDetailThreeColumnBreakpoint]) single-column
/// layout the same cards are reused unchanged -- they just stack full
/// width below the rest of the content.
class SubjectSideCard extends StatelessWidget {
  const SubjectSideCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// Optional header-row action, e.g. a `查看全部 ›` [TextButton].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
