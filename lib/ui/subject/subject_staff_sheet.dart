// lib/ui/subject/subject_staff_sheet.dart
import 'package:flutter/material.dart';

import '../../data/subject/subject_models.dart';

/// 「查看全部」 target for the 制作人员 card. Takes the already-fetched
/// [InfoboxField] list instead of watching a provider, because the card's
/// data is a plain getter off the subject detail the caller already has.
class SubjectStaffSheet extends StatelessWidget {
  const SubjectStaffSheet({super.key, required this.fields});

  final List<InfoboxField> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('全部制作人员', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '${fields.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    for (final field in fields)
                      ListTile(
                        title: Text(field.key),
                        subtitle: Text(
                          field.values.map((value) => value.v).join('、'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
