// test/data/anime1/anime1_models_test.dart
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Anime1PlaybackSource.fromApiResponse', () {
    test('picks the src of the first source entry', () {
      final source = Anime1PlaybackSource.fromApiResponse({
        's': [
          {'src': 'https://example.com/720p.mp4', 'type': 'video/mp4'},
          {'src': 'https://example.com/1080p.mp4', 'type': 'video/mp4'},
        ],
      });

      expect(source.url, 'https://example.com/720p.mp4');
    });

    test('prepends https: to a protocol-relative src', () {
      // Verified against the live site (2026-09-01): the real API
      // returns protocol-relative URLs like "//host/path.mp4".
      final source = Anime1PlaybackSource.fromApiResponse({
        's': [
          {'src': '//chihaya.v.anime1.me/1468/8b.mp4', 'type': 'video/mp4'},
        ],
      });

      expect(source.url, 'https://chihaya.v.anime1.me/1468/8b.mp4');
    });

    test('throws FormatException when "s" is missing', () {
      expect(
        () => Anime1PlaybackSource.fromApiResponse({}),
        throwsFormatException,
      );
    });

    test('throws FormatException when "s" is an empty list', () {
      expect(
        () => Anime1PlaybackSource.fromApiResponse({'s': <dynamic>[]}),
        throwsFormatException,
      );
    });

    test('throws FormatException when the first entry has no "src"', () {
      expect(
        () => Anime1PlaybackSource.fromApiResponse({
          's': [
            {'type': 'video/mp4'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('passes the headers parameter through unchanged', () {
      final source = Anime1PlaybackSource.fromApiResponse(
        {
          's': [
            {'src': 'https://example.com/720p.mp4', 'type': 'video/mp4'},
          ],
        },
        headers: {'Referer': 'https://anime1.me', 'Cookie': 'e=1; p=2; h=3'},
      );

      expect(source.headers, {
        'Referer': 'https://anime1.me',
        'Cookie': 'e=1; p=2; h=3',
      });
    });

    test('defaults headers to an empty map when omitted', () {
      final source = Anime1PlaybackSource.fromApiResponse({
        's': [
          {'src': 'https://example.com/720p.mp4', 'type': 'video/mp4'},
        ],
      });

      expect(source.headers, isEmpty);
    });
  });

  group('MediaSource abstractions', () {
    test('Anime1Category implements MediaCandidate with sourceId "anime1"', () {
      const category = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      expect(category, isA<MediaCandidate>());
      expect(category.sourceId, 'anime1');
    });

    test('Anime1Episode implements MediaEpisode with sourceId "anime1"', () {
      const episode = Anime1Episode(title: 'ep1', pageUrl: 'https://anime1.me/1');
      expect(episode, isA<MediaEpisode>());
      expect(episode.sourceId, 'anime1');
    });

    test('Anime1PlaybackSource implements MediaPlaybackSource', () {
      const source = Anime1PlaybackSource(url: 'https://example.com/v.mp4');
      expect(source, isA<MediaPlaybackSource>());
    });
  });
}
