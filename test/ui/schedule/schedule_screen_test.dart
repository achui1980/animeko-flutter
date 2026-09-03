import 'package:animeko_flutter/domain/schedule/schedule_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_list_item.dart';
import 'package:animeko_flutter/ui/schedule/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduleController extends ScheduleController {
  @override
  Future<List<ScheduleDay>> build() async {
    return const [
      ScheduleDay(
        date: '2024-01-01',
        subjects: [
          SubjectCard(id: 1, name: 'Foo', imageUrl: 'https://example.com/1.png'),
        ],
      ),
    ];
  }
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [scheduleControllerProvider.overrideWith(() => _FakeScheduleController())],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('expanding a day shows its subjects as AnimeListItem', (tester) async {
    await tester.pumpWidget(_wrap(const ScheduleScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2024-01-01'));
    await tester.pumpAndSettle();

    expect(find.byType(AnimeListItem), findsOneWidget);
    expect(find.text('Foo'), findsOneWidget);
  });

  testWidgets('AppBar shows the collection action', (tester) async {
    await tester.pumpWidget(_wrap(const ScheduleScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
