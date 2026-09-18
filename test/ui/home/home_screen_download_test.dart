import 'package:animeko_flutter/data/download/downloaded_episodes_provider.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/home/home_recommendations_controller.dart';
import 'package:animeko_flutter/domain/home/trending_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQueueController extends DownloadQueueController {
  _FakeQueueController(this.items);

  final Map<String, DownloadQueueItem> items;

  @override
  Future<Map<String, DownloadQueueItem>> build() async => items;
}

const _emptyPage = HomeRecommendationsPage(items: [], hasMore: false);

Future<void> _pump(
  WidgetTester tester,
  Map<String, DownloadQueueItem> queueItems,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trendingProvider.overrideWith((ref) async => const <SubjectCard>[]),
        homeRecommendationsControllerProvider.overrideWith(
          () => _StubRecommendationsController(),
        ),
        downloadQueueControllerProvider.overrideWith(
          () => _FakeQueueController(queueItems),
        ),
        // downloadedEpisodesProvider is a real drift watchAll() stream; its
        // debounce Timer never fires under flutter_test's FakeAsync clock
        // before the tree is disposed, tripping the "Timer is still
        // pending" invariant when the DownloadPanel bottom sheet is opened.
        // Override with a fixed empty stream, matching the workaround
        // already used in download_panel_test.dart.
        downloadedEpisodesProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _StubRecommendationsController extends HomeRecommendationsController {
  @override
  Future<HomeRecommendationsPage> build() async => _emptyPage;
}

void main() {
  testWidgets('shows a download icon with no badge when nothing is active', (
    tester,
  ) async {
    await _pump(tester, const {});

    expect(find.byTooltip('下载'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('shows the total active-download count across all subjects', (
    tester,
  ) async {
    await _pump(tester, const {
      '1::anime1::1': DownloadQueueItem(status: DownloadQueueStatus.downloading),
      '1::anime1::2': DownloadQueueItem(status: DownloadQueueStatus.queued),
      '2::xifan::1': DownloadQueueItem(status: DownloadQueueStatus.downloading),
    });

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping the download icon opens the download panel', (
    tester,
  ) async {
    await _pump(tester, const {});

    await tester.tap(find.byTooltip('下载'));
    await tester.pumpAndSettle();

    expect(find.text('下载中 · 已下载(0)'), findsOneWidget);
  });
}
