// test/ui/player/download_tap_message_test.dart
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/player/player_screen.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);

  @override
  final String sourceId;

  @override
  final String title;
}

void main() {
  group('downloadTapMessage', () {
    test('already downloaded shows a plain confirmation', () {
      expect(
        downloadTapMessage(
          alreadyDownloaded: true,
          preferredSource: null,
          currentSourceId: 'xifan',
        ),
        '已下载',
      );
    });

    test('no downloadable source shows the no-source message', () {
      expect(
        downloadTapMessage(
          alreadyDownloaded: false,
          preferredSource: null,
          currentSourceId: 'mikan',
        ),
        '此集暂无可下载来源',
      );
    });

    test(
      'enqueuing from the source currently playing still confirms -- this '
      'is the bug: the player previously showed nothing here',
      () {
        const source = MergedEpisode(
          episode: _FakeEpisode('xifan', '第1集'),
          sourceId: 'xifan',
        );

        expect(
          downloadTapMessage(
            alreadyDownloaded: false,
            preferredSource: source,
            currentSourceId: 'xifan',
          ),
          '已加入下载队列',
        );
      },
    );

    test(
      'enqueuing from a different source than the one currently playing '
      'names the source that will actually be used',
      () {
        const source = MergedEpisode(
          episode: _FakeEpisode('anime1', '第1集'),
          sourceId: 'anime1',
        );

        expect(
          downloadTapMessage(
            alreadyDownloaded: false,
            preferredSource: source,
            currentSourceId: 'mikan',
          ),
          '已加入下载队列（将从 anime1 下载）',
        );
      },
    );
  });

  group('shouldEnqueueOnDownloadTap', () {
    test('does not enqueue when already downloaded', () {
      expect(
        shouldEnqueueOnDownloadTap(
          alreadyDownloaded: true,
          preferredSource: null,
        ),
        isFalse,
      );
    });

    test('does not enqueue when no source is available', () {
      expect(
        shouldEnqueueOnDownloadTap(
          alreadyDownloaded: false,
          preferredSource: null,
        ),
        isFalse,
      );
    });

    test('enqueues when a source is available and not already downloaded', () {
      const source = MergedEpisode(
        episode: _FakeEpisode('xifan', '第1集'),
        sourceId: 'xifan',
      );

      expect(
        shouldEnqueueOnDownloadTap(
          alreadyDownloaded: false,
          preferredSource: source,
        ),
        isTrue,
      );
    });
  });
}
