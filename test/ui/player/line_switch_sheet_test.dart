// test/ui/player/line_switch_sheet_test.dart
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/rss/rss_parser.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';
import 'package:animeko_flutter/data/torrent/torrent_playback_source.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/media/title_parser.dart';
import 'package:animeko_flutter/ui/player/line_switch_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRqbitEngine extends Mock implements RqbitEngine {}

class _LabeledSource extends MediaPlaybackSource {
  const _LabeledSource(this._label);
  final String? _label;
  @override
  String get url => 'https://example.com/video.mp4';
  @override
  Map<String, String> get headers => const {};
  @override
  String? get label => _label;
}

void main() {
  Widget buildSheet({
    required List<MediaPlaybackSource> candidates,
    int currentIndex = 0,
    ValueChanged<int>? onSelect,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LineSwitchSheet(
          candidates: candidates,
          currentIndex: currentIndex,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );
  }

  testWidgets(
    'falls back to 1-indexed 线路 N label when candidate label is null',
    (tester) async {
      await tester.pumpWidget(
        buildSheet(
          candidates: const [_LabeledSource(null), _LabeledSource(null)],
        ),
      );

      expect(find.text('线路 1'), findsOneWidget);
      expect(find.text('线路 2'), findsOneWidget);
    },
  );

  testWidgets('shows the candidate label directly when it is non-null', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSheet(candidates: const [_LabeledSource('自定义线路')]),
    );

    expect(find.text('自定义线路'), findsOneWidget);
    expect(find.text('线路 1'), findsNothing);
  });

  testWidgets(
    'shows a checkmark on the currently-selected item and not on others',
    (tester) async {
      await tester.pumpWidget(
        buildSheet(
          candidates: const [
            _LabeledSource('A'),
            _LabeledSource('B'),
            _LabeledSource('C'),
          ],
          currentIndex: 1,
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);

      final tileB = tester.widget<ListTile>(
        find.ancestor(of: find.text('B'), matching: find.byType(ListTile)),
      );
      expect(tileB.selected, isTrue);

      final tileA = tester.widget<ListTile>(
        find.ancestor(of: find.text('A'), matching: find.byType(ListTile)),
      );
      expect(tileA.selected, isFalse);
    },
  );

  testWidgets('tapping a tile invokes onSelect with the correct index', (
    tester,
  ) async {
    int? selectedIndex;
    await tester.pumpWidget(
      buildSheet(
        candidates: const [
          _LabeledSource('A'),
          _LabeledSource('B'),
          _LabeledSource('C'),
        ],
        onSelect: (index) => selectedIndex = index,
      ),
    );

    await tester.tap(find.text('C'));

    expect(selectedIndex, 2);
  });

  testWidgets(
    'shows release title as subtitle for a TorrentPlaybackSource candidate '
    'and no subtitle for a non-BT candidate',
    (tester) async {
      const rawTitle = '[绿茶字幕组][Show][10][1080P][简体]';
      final torrentSource = TorrentPlaybackSource(
        release: RssRelease(
          item: const RssItem(
            title: rawTitle,
            torrentUrl: 'https://mikan.tangbai.cc/Download/x/x.torrent',
            contentLength: 1000,
          ),
          parsed: parseTitle(rawTitle),
        ),
        engine: MockRqbitEngine(),
      );

      await tester.pumpWidget(
        buildSheet(candidates: [torrentSource, const _LabeledSource('HTTP线路')]),
      );

      expect(find.text(rawTitle), findsOneWidget);

      final httpTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('HTTP线路'), matching: find.byType(ListTile)),
      );
      expect(httpTile.subtitle, isNull);
    },
  );
}
