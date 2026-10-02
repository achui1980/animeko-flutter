import 'package:animeko_flutter/data/agedm/agedm_models.dart';
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/data/dilidili/dilidili_models.dart';
import 'package:animeko_flutter/data/omofun/omofun_models.dart';
import 'package:animeko_flutter/data/xifan/xifan_models.dart';
import 'package:animeko_flutter/data/yinghua/yinghua_models.dart';
import 'package:animeko_flutter/domain/download/local_file_playback_source.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/cast_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUnknownSource extends MediaPlaybackSource {
  const _FakeUnknownSource();
  @override
  String get url => 'https://example.com/unknown.m3u8';
  @override
  Map<String, String> get headers => const {};
}

void main() {
  group('isCastable', () {
    test('returns true for xifan', () {
      expect(
        isCastable(const XifanPlaybackSource(url: 'https://example.com/a.m3u8')),
        isTrue,
      );
    });

    test('returns true for agedm', () {
      expect(
        isCastable(
          const AgedmPlaybackSource(url: 'https://example.com/a.m3u8', label: null),
        ),
        isTrue,
      );
    });

    test('returns true for omofun', () {
      expect(
        isCastable(
          const OmofunPlaybackSource(url: 'https://example.com/a.m3u8', label: null),
        ),
        isTrue,
      );
    });

    test('returns true for yinghua', () {
      expect(
        isCastable(const YinghuaPlaybackSource(url: 'https://example.com/a.m3u8')),
        isTrue,
      );
    });

    test('returns true for dilidili', () {
      expect(
        isCastable(const DilidiliPlaybackSource(url: 'https://example.com/a.m3u8')),
        isTrue,
      );
    });

    test('returns false for anime1 (confirmed cookie-blocked)', () {
      expect(
        isCastable(const Anime1PlaybackSource(url: 'https://example.com/a.mp4')),
        isFalse,
      );
    });

    test('returns false for a downloaded local file', () {
      expect(isCastable(const LocalFilePlaybackSource('/tmp/a.mp4')), isFalse);
    });

    test('returns false for any other/unknown source type', () {
      expect(isCastable(const _FakeUnknownSource()), isFalse);
    });
  });
}
