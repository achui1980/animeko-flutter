import 'dart:async';

import 'package:animeko_flutter/domain/schedule/schedule_controller.dart';
import 'package:animeko_flutter/domain/schedule/schedule_subject_score.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_cover_card.dart';
import 'package:animeko_flutter/ui/common/tag_chip.dart';
import 'package:animeko_flutter/ui/schedule/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduleController extends ScheduleController {
  _FakeScheduleController(this._days);

  final List<ScheduleDay> _days;

  @override
  Future<List<ScheduleDay>> build() async => _days;
}

Widget _wrap(
  List<ScheduleDay> days, {
  List<Override> overrides = const [],
  Override? scoreProviderOverride,
}) {
  return ProviderScope(
    overrides: [
      scheduleControllerProvider.overrideWith(
        () => _FakeScheduleController(days),
      ),
      scoreProviderOverride ??
          scheduleSubjectScoreProvider.overrideWith(
            (ref, subjectId) => Future.value(null),
          ),
      ...overrides,
    ],
    child: const MaterialApp(home: ScheduleScreen()),
  );
}

void main() {
  test('formats an episode number and local airing time', () {
    final airingTime = DateTime(2026, 8, 28, 22, 5).toUtc().toIso8601String();

    expect(
      formatScheduleEpisodeMetadata(episodeSort: '1', airingTime: airingTime),
      '第1话 · 22:05',
    );
  });

  test('keeps a fractional episode number in airing metadata', () {
    final airingTime = DateTime(2026, 8, 28, 22).toUtc().toIso8601String();

    expect(
      formatScheduleEpisodeMetadata(episodeSort: '3.5', airingTime: airingTime),
      '第3.5话 · 22:00',
    );
  });

  test('omits malformed or incomplete airing metadata', () {
    expect(
      formatScheduleEpisodeMetadata(
        episodeSort: null,
        airingTime: '2026-08-28T22:00:00Z',
      ),
      isNull,
    );
    expect(
      formatScheduleEpisodeMetadata(episodeSort: '1', airingTime: 'not-a-time'),
      isNull,
    );
    expect(
      formatScheduleEpisodeMetadata(episodeSort: '1', airingTime: '2026-08-28'),
      isNull,
    );
    expect(
      formatScheduleEpisodeMetadata(
        episodeSort: '1',
        airingTime: '2026-08-28T22:00:00',
      ),
      isNull,
    );
    expect(
      formatScheduleEpisodeMetadata(
        episodeSort: 'NaN',
        airingTime: '2026-08-28T22:00:00Z',
      ),
      isNull,
    );
  });

  testWidgets(
    'shows each day\'s subjects directly in a horizontal row, with no expand/collapse interaction',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          [
            ScheduleDay(
              date: '2024-01-01',
              subjects: [
                SubjectCard(
                  id: 1,
                  name: 'Foo',
                  imageUrl: 'https://example.com/1.png',
                  episodeSort: '1',
                  airingTime: DateTime(
                    2024,
                    1,
                    1,
                    22,
                  ).toUtc().toIso8601String(),
                ),
              ],
            ),
          ],
          scoreProviderOverride: scheduleSubjectScoreProvider(1).overrideWith(
            (ref) async => '7.8',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The item is already visible -- no tap/expand needed, and there must
      // be no ExpansionTile left in the tree at all.
      expect(find.byType(AnimeCoverCard), findsOneWidget);
      expect(find.text('Foo'), findsOneWidget);
      expect(find.text('第1话 · 22:00'), findsOneWidget);
      expect(find.bySemanticsLabel('评分 7.8'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(
        tester.widget<ListView>(find.byType(ListView).last).scrollDirection,
        Axis.horizontal,
      );
    },
  );

  testWidgets('does not show a score badge for a subject without an id', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const [
          ScheduleDay(
            date: '2024-01-01',
            subjects: [SubjectCard(id: null, name: 'Unidentified')],
          ),
        ],
        scoreProviderOverride: scheduleSubjectScoreProvider.overrideWith((
          ref,
          subjectId,
        ) {
            throw StateError('A null-ID subject must not read its score');
          }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r'^评分 ')), findsNothing);
  });

  testWidgets('omits a previous score badge while its refreshed score loads', (
    tester,
  ) async {
    final refreshedScore = Completer<String?>();
    var requestCount = 0;
    await tester.pumpWidget(
      _wrap(
        const [
          ScheduleDay(
            date: '2024-01-01',
            subjects: [SubjectCard(id: 1, name: 'Foo')],
          ),
        ],
        scoreProviderOverride: scheduleSubjectScoreProvider(1).overrideWith((
          ref,
        ) {
            requestCount++;
            return requestCount == 1
                ? Future.value('7.8')
                : refreshedScore.future;
          }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('评分 7.8'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScheduleScreen)),
    );
    container.invalidate(scheduleSubjectScoreProvider(1));
    container.read(scheduleSubjectScoreProvider(1));
    await tester.pump();

    expect(find.text('Foo'), findsOneWidget);
    expect(find.bySemanticsLabel('评分 7.8'), findsNothing);
  });

  testWidgets('omits a previous score badge when its refreshed score errors', (
    tester,
  ) async {
    var requestCount = 0;
    await tester.pumpWidget(
      _wrap(
        const [
          ScheduleDay(
            date: '2024-01-01',
            subjects: [SubjectCard(id: 1, name: 'Foo')],
          ),
        ],
        scoreProviderOverride: scheduleSubjectScoreProvider(1).overrideWith((
          ref,
        ) {
            requestCount++;
            return requestCount == 1
                ? Future.value('7.8')
                : Future<String?>.error(StateError('score unavailable'));
          }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('评分 7.8'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScheduleScreen)),
    );
    container.invalidate(scheduleSubjectScoreProvider(1));
    container.read(scheduleSubjectScoreProvider(1));
    await tester.pump();
    await tester.pump();

    expect(find.text('Foo'), findsOneWidget);
    expect(find.bySemanticsLabel('评分 7.8'), findsNothing);
  });

  testWidgets('formats the date header in a readable Chinese format', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const [
        // 2024-01-01 was a Monday.
        ScheduleDay(
          date: '2024-01-01',
          subjects: [SubjectCard(id: 1, name: 'Foo')],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('1月1日 星期一'), findsOneWidget);
  });

  testWidgets('marks today\'s date with a 今天 tag', (tester) async {
    final today = todayDateString(DateTime.now());
    await tester.pumpWidget(
      _wrap([
        ScheduleDay(
          date: today,
          subjects: const [SubjectCard(id: 1, name: 'Foo')],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.byType(TagChip), findsOneWidget);
  });

  testWidgets('does not mark a non-today date with a 今天 tag', (tester) async {
    await tester.pumpWidget(
      _wrap(const [
        ScheduleDay(
          date: '2000-01-01',
          subjects: [SubjectCard(id: 1, name: 'Foo')],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsNothing);
    expect(find.byType(TagChip), findsNothing);
  });

  testWidgets('AppBar shows the collection action', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('AppBar title is 追番日历', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('追番日历'), findsOneWidget);
  });
}
