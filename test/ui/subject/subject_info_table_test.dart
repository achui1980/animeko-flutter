import 'package:animeko_flutter/data/search/search_models.dart' show SubjectTag;
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_info_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectDetail detail({
  String airDate = '2026-07-12',
  List<String> aliases = const [],
  List<SubjectTag> tags = const [],
  SubjectInfobox? infobox,
  List<SubjectEpisode>? episodes,
}) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: airDate,
  tags: tags,
  aliases: aliases,
  infobox: infobox,
  episodes: episodes,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
);

SubjectEpisode mainEpisode(int id) => SubjectEpisode(
  episodeId: id,
  sort: id,
  ep: '$id',
  type: 'MAIN',
  name: 'ep$id',
  nameCn: '',
  airdate: '2026-07-12',
);

Future<void> pump(WidgetTester tester, SubjectDetail subject) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SubjectInfoTable(subject: subject)),
      ),
    );

void main() {
  group('SubjectInfoTable', () {
    testWidgets('优先用 infobox 里的中文「放送开始」原文', (tester) async {
      await pump(
        tester,
        detail(
          infobox: const SubjectInfobox(
            fields: [
              InfoboxField(
                key: '放送开始',
                values: [InfoboxValue(v: '2026年7月12日')],
              ),
            ],
          ),
        ),
      );

      expect(find.text('放送开始'), findsOneWidget);
      expect(find.text('2026年7月12日'), findsOneWidget);
    });

    testWidgets('没有 infobox 时退回 airDate 的年月格式', (tester) async {
      await pump(tester, detail(airDate: '2026-07-12'));

      expect(find.text('2026年7月'), findsOneWidget);
    });

    testWidgets('话数取 infobox，没有则用 episodeCount', (tester) async {
      await pump(tester, detail(episodes: [mainEpisode(1), mainEpisode(2)]));

      expect(find.text('话数'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('拿不到的字段整行不渲染', (tester) async {
      await pump(tester, detail(airDate: 'not-a-date'));

      expect(find.text('放送开始'), findsNothing);
      expect(find.text('话数'), findsNothing);
      expect(find.text('别名'), findsNothing);
    });

    testWidgets('别名优先用 aliases 数组并以 / 连接', (tester) async {
      await pump(
        tester,
        detail(
          aliases: const ['别名一', '别名二'],
          infobox: const SubjectInfobox(
            fields: [
              InfoboxField(
                key: '别名',
                values: [InfoboxValue(v: '只有第一个')],
              ),
            ],
          ),
        ),
      );

      expect(find.text('别名一 / 别名二'), findsOneWidget);
      expect(find.text('只有第一个'), findsNothing);
    });

    testWidgets('有标签时渲染标签行', (tester) async {
      await pump(
        tester,
        detail(tags: const [SubjectTag(name: '奇幻', count: 12)]),
      );

      expect(find.textContaining('奇幻'), findsOneWidget);
    });

    testWidgets('没有任何行也没有标签时整块隐藏', (tester) async {
      await pump(tester, detail(airDate: 'not-a-date'));

      expect(find.text('作品信息'), findsNothing);
    });

    testWidgets('一行都没有但有标签时整块仍然渲染', (tester) async {
      await pump(
        tester,
        detail(
          airDate: 'not-a-date',
          tags: const [SubjectTag(name: '奇幻', count: 12)],
        ),
      );

      expect(find.text('作品信息'), findsOneWidget);
      expect(find.textContaining('奇幻'), findsOneWidget);
      expect(find.text('放送开始'), findsNothing);
      expect(find.text('话数'), findsNothing);
      expect(find.text('别名'), findsNothing);
    });

    testWidgets('话数优先用 infobox 而不是 episodeCount', (tester) async {
      await pump(
        tester,
        detail(
          episodes: [mainEpisode(1), mainEpisode(2)],
          infobox: const SubjectInfobox(
            fields: [
              InfoboxField(
                key: '话数',
                values: [InfoboxValue(v: '11')],
              ),
            ],
          ),
        ),
      );

      expect(find.text('11'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    });
  });
}
