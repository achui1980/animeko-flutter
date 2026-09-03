// lib/ui/subject/subject_tags_row.dart
import 'package:flutter/material.dart';

import '../../data/search/search_models.dart' show SubjectTag;
import '../common/tag_chip.dart';

/// A wrapped row of [TagChip]s for a subject's tags, each showing
/// "name count" (e.g. "战斗 120"). Renders nothing when [tags] is empty.
class SubjectTagsRow extends StatelessWidget {
  const SubjectTagsRow({super.key, required this.tags});

  final List<SubjectTag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) => TagChip(label: '${tag.name} ${tag.count}')).toList(),
    );
  }
}
