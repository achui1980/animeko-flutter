import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/download/downloaded_episodes_provider.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/ui/download/download_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadedEpisodeSummary _row({
  required String status,
  String? errorMessage,
}) => DownloadedEpisodeSummary(
  sourceId: 'anime1',
  subjectId: 1,
  episodeKey: '1::anime1::第1集',
  subjectName: '测试番剧',
  episodeLabel: '第1集',
  localPath: '/tmp/video.mp4',
  status: status,
  errorMessage: errorMessage,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the source label alongside the episode label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(status: DownloadStatus.completed.name),
          queueItem: null,
          onCancel: () {},
          onRetry: () {},
          onDelete: () async {},
        ),
      ),
    );

    expect(find.textContaining('anime1'), findsWidgets);
  });

  testWidgets('shows 已中断 with retry/delete for an interrupted row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(status: DownloadStatus.interrupted.name),
          queueItem: null,
          onCancel: () {},
          onRetry: () {},
          onDelete: () async {},
        ),
      ),
    );

    expect(find.text('已中断'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('shows 已停滞，正在重试 for a stalled in-progress item', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(status: DownloadStatus.downloading.name),
          queueItem: const DownloadQueueItem(
            status: DownloadQueueStatus.downloading,
            received: 10,
            total: 100,
            isStalled: true,
          ),
          onCancel: () {},
          onRetry: () {},
          onDelete: () async {},
        ),
      ),
    );

    expect(find.text('已停滞，正在重试'), findsOneWidget);
  });

  testWidgets('shows the error message verbatim for a failed row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(
            status: DownloadStatus.failed.name,
            errorMessage: '源返回了网页而非视频（可能是防盗链或登录失效）',
          ),
          queueItem: null,
          onCancel: () {},
          onRetry: () {},
          onDelete: () async {},
        ),
      ),
    );

    expect(find.text('源返回了网页而非视频（可能是防盗链或登录失效）'), findsOneWidget);
  });

  testWidgets('tapping 重试 on a failed row invokes onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(status: DownloadStatus.failed.name, errorMessage: 'x'),
          queueItem: null,
          onCancel: () {},
          onRetry: () => retried = true,
          onDelete: () async {},
        ),
      ),
    );

    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });
}
