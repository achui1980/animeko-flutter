// lib/ui/subject/subject_tags_row.dart
import 'package:flutter/material.dart';

import '../../data/search/search_models.dart' show SubjectTag;
import '../common/tag_chip.dart';

/// A wrapped row of [TagChip]s for a subject's tags, each showing
/// "name count" (e.g. "战斗 120"). Renders nothing when [tags] is empty.
///
/// Caps the number of visible tags at [maxVisible] (Kazumi's
/// `infoBody` pattern: cap at 13, swap the last slot for a "更多 +N"
/// chip) so a subject with dozens of tags doesn't push the rest of the
/// page down several extra rows. Tapping the "更多" chip reveals the
/// rest.
class SubjectTagsRow extends StatefulWidget {
  const SubjectTagsRow({super.key, required this.tags, this.maxVisible = 12});

  final List<SubjectTag> tags;
  final int maxVisible;

  @override
  State<SubjectTagsRow> createState() => _SubjectTagsRowState();
}

class _SubjectTagsRowState extends State<SubjectTagsRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.tags.isEmpty) return const SizedBox.shrink();
    final overflowing = !_expanded && widget.tags.length > widget.maxVisible;
    final visible = overflowing ? widget.tags.take(widget.maxVisible) : widget.tags;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in visible) TagChip(label: '${tag.name} ${tag.count}'),
        if (overflowing)
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: TagChip(label: '更多 +${widget.tags.length - widget.maxVisible}'),
          ),
      ],
    );
  }
}
