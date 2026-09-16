// lib/ui/subject/subject_rating_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subject/subject_collection_controller.dart';

/// Opens the 打分 dialog for [subjectId].
///
/// The caller (`SubjectRatingCard`) already watches
/// `subjectCollectionControllerProvider`, so it passes the current
/// self-rating in as the initial form values -- the dialog itself does
/// not read any provider during `initState`.
Future<void> showSubjectRatingDialog(
  BuildContext context, {
  required int subjectId,
  required int initialScore,
  String? initialComment,
  bool initialIsPrivate = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => SubjectRatingDialog(
      subjectId: subjectId,
      initialScore: initialScore,
      initialComment: initialComment,
      initialIsPrivate: initialIsPrivate,
    ),
  );
}

/// The 打分 form: score slider (1-10), optional comment, "private"
/// toggle, submit.
///
/// Ported from the old `_RatingSection` inside `subject_detail_screen.dart`,
/// which rendered the same form inline in the left column. Submission is
/// deliberately NOT optimistic (see `SubjectCollectionController.submitRating`):
/// on failure the dialog stays open with the user's input intact.
class SubjectRatingDialog extends ConsumerStatefulWidget {
  const SubjectRatingDialog({
    super.key,
    required this.subjectId,
    required this.initialScore,
    this.initialComment,
    this.initialIsPrivate = false,
  });

  final int subjectId;
  final int initialScore;
  final String? initialComment;
  final bool initialIsPrivate;

  @override
  ConsumerState<SubjectRatingDialog> createState() =>
      _SubjectRatingDialogState();
}

class _SubjectRatingDialogState extends ConsumerState<SubjectRatingDialog> {
  late int _score = widget.initialScore;
  late bool _isPrivate = widget.initialIsPrivate;
  late final TextEditingController _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );
  bool _busy = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(
            subjectCollectionControllerProvider(
              subjectId: widget.subjectId,
            ).notifier,
          )
          .submitRating(
            _score,
            comment: _commentController.text.isEmpty
                ? null
                : _commentController.text,
            isPrivate: _isPrivate,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评分已提交')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提交评分失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('我的评分'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_score 分', style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: _score.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_score',
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _score = value.round()),
            ),
            TextField(
              controller: _commentController,
              enabled: !_busy,
              decoration: const InputDecoration(hintText: '评论（可选）'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('仅自己可见'),
              value: _isPrivate,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _isPrivate = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('提交'),
        ),
      ],
    );
  }
}
