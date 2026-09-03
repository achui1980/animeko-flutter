import 'package:animeko_flutter/domain/schedule/schedule_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_list_item.dart';
import 'package:animeko_flutter/ui/common/tag_chip.dart';
import 'package:animeko_flutter/ui/schedule/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduleController extends ScheduleController {
  _FakeScheduleController(this._days);

  final List<ScheduleDay> _days;

  @override
  Future<List<ScheduleDay>> build() async => _days;
}

Widget _wrap(List<ScheduleDay> days) {
  return ProviderScope(
    overrides: [scheduleControllerProvider.overrideWith(() => _FakeScheduleController(days))],
    child: const MaterialApp(home: ScheduleScreen()),
  );
}

void main() {
  testWidgets('shows each day\'s subjects directly, with no expand/collapse interaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const [
        ScheduleDay(
          date: '2024-01-01',
          subjects: [SubjectCard(id: 1, name: 'Foo', imageUrl: 'https://example.com/1.png')],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // The item is already visible -- no tap/expand needed, and there must
    // be no ExpansionTile left in the tree at all.
    expect(find.byType(AnimeListItem), findsOneWidget);
    expect(find.text('Foo'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
  });

  testWidgets('formats the date header in a readable Chinese format', (tester) async {
    await tester.pumpWidget(
      _wrap(const [
        // 2024-01-01 was a Monday.
        ScheduleDay(date: '2024-01-01', subjects: [SubjectCard(id: 1, name: 'Foo')]),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('1月1日 星期一'), findsOneWidget);
  });

  testWidgets('marks today\'s date with a 今天 tag', (tester) async {
    final today = todayDateString(DateTime.now());
    await tester.pumpWidget(
      _wrap([ScheduleDay(date: today, subjects: const [SubjectCard(id: 1, name: 'Foo')])]),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.byType(TagChip), findsOneWidget);
  });

  testWidgets('does not mark a non-today date with a 今天 tag', (tester) async {
    await tester.pumpWidget(
      _wrap(const [
        ScheduleDay(date: '2000-01-01', subjects: [SubjectCard(id: 1, name: 'Foo')]),
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
}
