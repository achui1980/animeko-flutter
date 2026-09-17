import 'package:animeko_flutter/domain/download/download_source_resolver.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Episode implements MediaEpisode {
  const _Episode(this.sourceId, this.title);

  @override
  final String sourceId;
  @override
  final String title;
}

MergedEpisode _e(String sourceId, String title) =>
    MergedEpisode(episode: _Episode(sourceId, title), sourceId: sourceId);

void main() {
  group('resolveDownloadOptions', () {
    test('groups by title and keeps only downloadable sources', () {
      final merged = [
        _e('anime1', '第1集'),
        _e('mikan', '第1集'),
        _e('mikan', '第2集'),
      ];

      final options = resolveDownloadOptions(merged);

      expect(options, hasLength(2));
      final first = options.firstWhere((o) => o.title == '第1集');
      expect(first.isDownloadable, isTrue);
      expect(first.candidates.map((c) => c.sourceId), ['anime1']);
      final second = options.firstWhere((o) => o.title == '第2集');
      expect(second.isDownloadable, isFalse);
      expect(second.candidates, isEmpty);
    });

    test('prefers anime1 over xifan when both are available', () {
      final merged = [_e('xifan', '第1集'), _e('anime1', '第1集')];

      final options = resolveDownloadOptions(merged);

      expect(options.single.preferred!.sourceId, 'anime1');
      expect(
        options.single.candidates.map((c) => c.sourceId),
        ['anime1', 'xifan'],
      );
    });

    test('an episode with only xifan is still downloadable', () {
      final options = resolveDownloadOptions([_e('xifan', '第1集')]);

      expect(options.single.isDownloadable, isTrue);
      expect(options.single.preferred!.sourceId, 'xifan');
    });

    test('an episode available on no HTTP source is not downloadable', () {
      final options = resolveDownloadOptions([_e('mikan', '第1集')]);

      expect(options.single.isDownloadable, isFalse);
      expect(options.single.preferred, isNull);
    });

    test('preserves the merged list\'s title order', () {
      final merged = [_e('anime1', '第2集'), _e('anime1', '第1集')];

      final options = resolveDownloadOptions(merged);

      expect(options.map((o) => o.title), ['第2集', '第1集']);
    });
  });

  group('resolvePreferredDownloadSource', () {
    test('finds the preferred candidate for a single episode by title', () {
      final merged = [_e('xifan', '第1集'), _e('anime1', '第1集')];

      final match = resolvePreferredDownloadSource(merged, '第1集');

      expect(match!.sourceId, 'anime1');
    });

    test('returns null when no HTTP source has this episode', () {
      final merged = [_e('mikan', '第1集')];

      expect(resolvePreferredDownloadSource(merged, '第1集'), isNull);
    });

    test('returns null when the title does not exist at all', () {
      final merged = [_e('anime1', '第1集')];

      expect(resolvePreferredDownloadSource(merged, '第99集'), isNull);
    });
  });
}
