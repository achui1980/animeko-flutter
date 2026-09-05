// test/ui/subject/episode_source_sheet_test.dart
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/episode_source_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});

  @override
  final String sourceId;

  @override
  final String title;
}

class _FakeSource implements MediaSource {
  const _FakeSource({required this.id, required this.displayName});

  @override
  final String id;

  @override
  final String displayName;

  @override
  Future<List<MediaCandidate>> search(String title) async => const [];

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) async =>
      const [];

  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) {
    throw UnimplementedError();
  }
}

void main() {
  group('EpisodeSourceSheet', () {
    testWidgets(
      'shows a filter chip per source and all episodes by default',
      (tester) async {
        final episodes = [
          MergedEpisode(
            episode: const _FakeEpisode(sourceId: 'anime1', title: '第1集'),
            sourceId: 'anime1',
          ),
          MergedEpisode(
            episode: const _FakeEpisode(sourceId: 'xifan', title: '第1集'),
            sourceId: 'xifan',
          ),
        ];
        const sources = [
          _FakeSource(id: 'anime1', displayName: 'anime1.me'),
          _FakeSource(id: 'xifan', displayName: '稀饭动漫'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EpisodeSourceSheet(
                episodes: episodes,
                sources: sources,
                onEpisodeSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('选择集数'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'anime1.me'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, '稀饭动漫'), findsOneWidget);
        expect(find.text('第1集'), findsNWidgets(2));
      },
    );

    testWidgets('tapping an episode calls onEpisodeSelected with that episode', (
      tester,
    ) async {
      MergedEpisode? selected;
      final episode = MergedEpisode(
        episode: const _FakeEpisode(sourceId: 'anime1', title: '第1集'),
        sourceId: 'anime1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceSheet(
              episodes: [episode],
              sources: const [
                _FakeSource(id: 'anime1', displayName: 'anime1.me'),
              ],
              onEpisodeSelected: (e) => selected = e,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('第1集'));

      expect(selected, same(episode));
    });
  });
}
