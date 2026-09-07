import 'dart:async';

import 'package:animeko_flutter/data/subject/bangumi_episode_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/ui/subject/episode_playback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeCandidate implements MediaCandidate {
  const _FakeCandidate(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});
  @override
  final String sourceId;
  @override
  final String title;
}

class MockMediaSource extends Mock implements MediaSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(const _FakeCandidate('fallback', 'fallback'));
  });

  const bangumiEpisode = BangumiEpisode(
    id: 1,
    sort: 1,
    name: 'EN',
    nameCn: '第1集',
    airdate: '2023-09-29',
    type: 0,
  );

  Widget wrap(Widget child, {required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets(
    'shows a loading indicator while the merged list is still loading',
    (tester) async {
      final source = MockMediaSource();
      when(() => source.id).thenReturn('anime1');
      when(() => source.displayName).thenReturn('anime1.me');
      // A never-completing Future, not `Future.delayed`: `flutter_test`
      // asserts no `Timer` is left pending when a test ends, and this
      // test intentionally never lets the search settle within it.
      when(
        () => source.search(any()),
      ).thenAnswer((_) => Completer<List<MediaCandidate>>().future);

      await tester.pumpWidget(
        wrap(
          const EpisodePlaybackSheet(
            subjectId: 1,
            subjectName: '目标番剧',
            ordinalIndex: 0,
            bangumiEpisode: bangumiEpisode,
          ),
          overrides: [
            mediaSourcesProvider.overrideWithValue([source]),
          ],
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('shows "暂无播放源" when no source has an episode at this position', (
    tester,
  ) async {
    final source = MockMediaSource();
    when(() => source.id).thenReturn('anime1');
    when(() => source.displayName).thenReturn('anime1.me');
    when(() => source.search(any())).thenAnswer((_) async => const []);

    await tester.pumpWidget(
      wrap(
        const EpisodePlaybackSheet(
          subjectId: 1,
          subjectName: '目标番剧',
          ordinalIndex: 0,
          bangumiEpisode: bangumiEpisode,
        ),
        overrides: [
          mediaSourcesProvider.overrideWithValue([source]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无播放源'), findsOneWidget);
  });

  testWidgets('shows one row with a 播放 button for a matched source', (
    tester,
  ) async {
    final source = MockMediaSource();
    when(() => source.id).thenReturn('anime1');
    when(() => source.displayName).thenReturn('anime1.me');
    when(
      () => source.search('目标番剧'),
    ).thenAnswer((_) async => [const _FakeCandidate('anime1', '目标番剧')]);
    when(() => source.listEpisodes(any())).thenAnswer(
      (_) async => [const _FakeEpisode(sourceId: 'anime1', title: '第1集')],
    );

    await tester.pumpWidget(
      wrap(
        const EpisodePlaybackSheet(
          subjectId: 1,
          subjectName: '目标番剧',
          ordinalIndex: 0,
          bangumiEpisode: bangumiEpisode,
        ),
        overrides: [
          mediaSourcesProvider.overrideWithValue([source]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('anime1.me'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '播放'), findsOneWidget);
  });
}
