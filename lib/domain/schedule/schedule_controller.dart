// lib/domain/schedule/schedule_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/schedule/schedule_api.dart';
import '../subject_card.dart';

part 'schedule_controller.g.dart';

class ScheduleDay {
  const ScheduleDay({required this.date, required this.subjects});

  final String date;
  final List<SubjectCard> subjects;
}

/// Formats a [DateTime] as `YYYY-MM-DD`. Pure function, directly testable
/// with no mocking. See this file's Task 8 note in the plan doc regarding
/// the unverified server-expected format for this string.
String todayDateString(DateTime now) {
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Formats a UTC offset [Duration] as `+HH:MM` / `-HH:MM`. Pure function,
/// directly testable with no mocking.
String timeZoneOffsetString(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hours = abs.inHours.toString().padLeft(2, '0');
  final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return '$sign$hours:$minutes';
}

@riverpod
class ScheduleController extends _$ScheduleController {
  @override
  Future<List<ScheduleDay>> build() async {
    final api = ref.watch(scheduleApiProvider);
    final now = DateTime.now();
    final schedule = await api.getLatestAiringSchedule(
      today: todayDateString(now),
      timeZone: timeZoneOffsetString(now.timeZoneOffset),
    );

    return schedule.list
        .map(
          (day) => ScheduleDay(
            date: day.date,
            subjects: day.list
                .map((e) => SubjectCard.fromScheduledSubject(e.subject))
                .toList(),
          ),
        )
        .toList();
  }
}
