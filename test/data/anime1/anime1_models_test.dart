// test/data/anime1/anime1_models_test.dart
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
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
  });
}
