import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_title_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectEpisode ep(int n, String airdate) => SubjectEpisode(
  episodeId: n,
  sort: n,
  ep: '$n',
  type: 'MAIN',
  name: 'E$n',
  nameCn: '第$n集',
  airdate: airdate,
);

SubjectDetail detail({
  String name = 'Futsutsuka na Akujo',
  String nameCn = '恶女不才',
  String airDate = '2026-07-12',
  List<SubjectEpisode>? episodes,
}) => SubjectDetail(
  id: 1,
  name: name,
  nameCn: nameCn,
  summary: 'summary',
  airDate: airDate,
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: episodes,
);

Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('renders the Chinese title and the original name', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(),
          episodes: const [],
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    expect(find.text('恶女不才'), findsOneWidget);
    expect(find.text('Futsutsuka na Akujo'), findsOneWidget);
  });

  testWidgets('falls back to the original name when nameCn is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(nameCn: ''),
          episodes: const [],
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    // Shown exactly once -- as the title, not also as the subtitle.
    expect(find.text('Futsutsuka na Akujo'), findsOneWidget);
  });

  testWidgets('does not repeat the original name when it equals the title', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(name: '恶女不才', nameCn: '恶女不才'),
          episodes: const [],
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    expect(find.text('恶女不才'), findsOneWidget);
  });

  testWidgets('renders the meta line', (tester) async {
    final episodes = [
      for (var i = 1; i <= 9; i++) ep(i, '2026-09-01'),
      ep(10, '2026-09-19'),
      ep(11, '2026-09-26'),
    ];
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(episodes: episodes),
          episodes: episodes,
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    expect(find.text('2026年7月 · 连载至 09 · 预定全 11 话'), findsOneWidget);
  });

  // Guards the `now` plumbing specifically: these airdates are far enough in
  // the future that the real current time would report nothing aired yet and
  // drop the 连载至 segment. Without this the widget could ignore `now`
  // entirely and the other meta-line test would still pass, since its pinned
  // date sits in the same airing window as the real today.
  testWidgets('pins today through the now parameter', (tester) async {
    final episodes = [
      for (var i = 1; i <= 3; i++) ep(i, '2099-01-01'),
      for (var i = 4; i <= 5; i++) ep(i, '2099-12-01'),
    ];
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(airDate: '2099-01-01', episodes: episodes),
          episodes: episodes,
          now: DateTime(2099, 6, 1),
        ),
      ),
    );

    expect(find.text('2099年1月 · 连载至 03 · 预定全 5 话'), findsOneWidget);
  });

  testWidgets('omits the meta line when nothing is known', (tester) async {
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(airDate: ''),
          episodes: const [],
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    expect(find.text(''), findsNothing);
    expect(find.byType(Text), findsNWidgets(0));
    expect(find.byType(SelectableText), findsNWidgets(2));
  });
}
