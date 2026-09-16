// test/ui/subject/subject_staff_card_test.dart
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_staff_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectDetail detailWith(SubjectInfobox? infobox) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 's',
  airDate: '2026-07-12',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  infobox: infobox,
);

InfoboxField field(String key, List<String> values) => InfoboxField(
  key: key,
  values: [for (final value in values) InfoboxValue(v: value)],
);

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders one row per staff infobox field', (tester) async {
    final subject = detailWith(
      SubjectInfobox(
        fields: [
          field('原作', ['中村颯希（作家）']),
          field('音乐', ['橋本由香利']),
        ],
      ),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('制作人员'), findsOneWidget);
    expect(find.text('原作'), findsOneWidget);
    expect(find.text('中村颯希（作家）'), findsOneWidget);
    expect(find.text('音乐'), findsOneWidget);
    expect(find.text('橋本由香利'), findsOneWidget);
  });

  testWidgets('joins multiple values of one role', (tester) async {
    final subject = detailWith(
      SubjectInfobox(
        fields: [
          field('系列构成', ['田口智久', '平松正樹']),
        ],
      ),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('田口智久、平松正樹'), findsOneWidget);
  });

  testWidgets('excludes non-staff infobox keys', (tester) async {
    final subject = detailWith(
      SubjectInfobox(
        fields: [
          field('放送开始', ['2026年7月12日']),
          field('话数', ['11']),
          field('官方网站', ['https://example.com']),
          field('导演', ['佐藤']),
        ],
      ),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('导演'), findsOneWidget);
    expect(find.text('放送开始'), findsNothing);
    expect(find.text('话数'), findsNothing);
    expect(find.text('官方网站'), findsNothing);
  });

  testWidgets('keeps unknown roles that are not on the blocklist', (
    tester,
  ) async {
    final subject = detailWith(
      SubjectInfobox(
        fields: [
          field('某个没见过的职位', ['某人']),
        ],
      ),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('某个没见过的职位'), findsOneWidget);
    expect(find.text('某人'), findsOneWidget);
  });

  testWidgets('hides the whole card when infobox is null', (tester) async {
    await tester.pumpWidget(wrap(SubjectStaffCard(subject: detailWith(null))));

    expect(find.text('制作人员'), findsNothing);
  });

  testWidgets('hides the whole card when every field is filtered out', (
    tester,
  ) async {
    final subject = detailWith(
      SubjectInfobox(
        fields: [
          field('话数', ['11']),
        ],
      ),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('制作人员'), findsNothing);
  });

  testWidgets('shows at most maxVisible rows and opens the sheet', (
    tester,
  ) async {
    final subject = detailWith(
      SubjectInfobox(
        fields: [
          for (var i = 0; i < 12; i++) field('职位$i', ['人$i']),
        ],
      ),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('职位0'), findsOneWidget);
    expect(find.text('职位${SubjectStaffCard.maxVisible - 1}'), findsOneWidget);
    expect(find.text('职位${SubjectStaffCard.maxVisible}'), findsNothing);

    await tester.tap(find.text('查看全部 ›'));
    await tester.pumpAndSettle();

    expect(find.text('全部制作人员'), findsOneWidget);
    expect(find.text('职位11'), findsOneWidget);
  });
}
