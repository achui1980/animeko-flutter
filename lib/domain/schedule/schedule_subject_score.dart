import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/subject_api.dart';

part 'schedule_subject_score.g.dart';

String? formatScheduleSubjectScore(String? score) {
  final trimmed = score?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final value = double.tryParse(trimmed);
  if (value == null || !value.isFinite || value <= 0) return null;

  return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
}

@Riverpod(keepAlive: true)
Future<String?> scheduleSubjectScore(Ref ref, int subjectId) async {
  try {
    final detail = await ref.watch(subjectApiProvider).getSubject(subjectId);
    return formatScheduleSubjectScore(detail.score);
  } catch (_) {
    return null;
  }
}
