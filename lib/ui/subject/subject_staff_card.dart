// lib/ui/subject/subject_staff_card.dart
import 'package:flutter/material.dart';

import '../../data/subject/subject_models.dart';
import 'subject_side_card.dart';
import 'subject_staff_sheet.dart';

/// 制作人员 card for the right column.
///
/// Driven entirely by `SubjectDetail.staffFields` (the subject response's
/// `infobox`), NOT by a `/staff` request. The `/staff` endpoint returns int
/// `position` codes (52 distinct values on one subject) that would need a
/// hand-maintained code -> Chinese label table; `infobox` already carries
/// Chinese role names, so the whole staff API chain was deleted in Task 4.
///
/// Takes the subject as a parameter instead of watching the provider so the
/// widget stays a plain `StatelessWidget` -- the parent pane already has the
/// loaded `SubjectDetail`.
class SubjectStaffCard extends StatelessWidget {
  const SubjectStaffCard({super.key, required this.subject});

  final SubjectDetail subject;

  /// How many roles the card shows before 「查看全部」. Estimate; the
  /// reference screenshot shows ~8 rows in the sidebar.
  static const int maxVisible = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = subject.staffFields;
    if (fields.isEmpty) return const SizedBox.shrink();

    final visible = fields.take(maxVisible).toList();

    return SubjectSideCard(
      title: '制作人员',
      trailing: fields.length <= maxVisible
          ? null
          : TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SubjectStaffSheet(fields: fields),
              ),
              child: const Text('查看全部 ›'),
            ),
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        children: [
          for (final field in visible)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 6),
                  child: Text(
                    field.key,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    field.values.map((value) => value.v).join('、'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
