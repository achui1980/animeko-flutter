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

    // The server's response isn't guaranteed to be sorted or anchored
    // exactly at `today` (observed in practice: it can include trailing
    // days from before today). Sort ascending, drop anything before
    // today, then cap to a week so the UI always shows "today through
    // the next 6 days" regardless of what the server actually returns.
    final todayStr = todayDateString(now);
    final sorted = schedule.list.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final fromToday = sorted.where((day) => day.date.compareTo(todayStr) >= 0);

    return fromToday
        .take(7)
        .map(
          (day) => ScheduleDay(
            date: day.date,
            subjects: day.list
                .map(
                  (episode) => SubjectCard.fromScheduledSubject(
                    episode.subject,
                    episodeSort: episode.episode.sort,
                    airingTime: episode.airingTime,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }
}
