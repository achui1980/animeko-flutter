import 'package:flutter_test/flutter_test.dart';
import 'package:animeko_flutter/domain/media/title_parser.dart';

void main() {
  group('parseTitle', () {
    test('parses dash-separated single episode with bracket group', () {
      const title =
          '[黒ネズミたち] 魔法少女奈叶 EXCEEDS Gun Blaze Vengeance / '
          'Mahou Shoujo Lyrical Nanoha EXCEEDS - 10 '
          '(ABEMA 1920x1080 AVC AAC MKV)';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(10), isTrue);
      expect(parsed.episodeRange!.contains(11), isFalse);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, '黒ネズミたち');
    });

    test('parses fullwidth-bracket range episode with season marker', () {
      const title =
          '【澄空学园&动漫国字幕组】★07月新番[魔法少女奈叶 EXCEEDS 复仇枪焰]'
          '[07-10][1080P][简体][MP4]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(7), isTrue);
      expect(parsed.episodeRange!.contains(10), isTrue);
      expect(parsed.episodeRange!.contains(11), isFalse);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, '澄空学园&动漫国字幕组');
      expect(parsed.subtitleLanguages, contains('简体'));
    });

    test('parses double-space group name with CHT language tag', () {
      const title =
          '[ANi]  魔法少女奈叶 EXCEEDS Gun Blaze Vengeance - 09 '
          '[1080P][Baha][WEB-DL][AAC AVC][CHT][MP4]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(9), isTrue);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, 'ANi');
      expect(parsed.subtitleLanguages, contains('繁体'));
    });

    test('parses bracketed single episode with traditional chinese tag', () {
      const title =
          '[ExileSub][魔法少女奈叶EXCEEDS Gun Blaze Vengeance][10][繁体][1080P]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(10), isTrue);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, 'ExileSub');
      expect(parsed.subtitleLanguages, contains('繁体'));
    });

    test('returns null episodeRange when no episode number is found', () {
      const title = '[SomeGroup][Some Show][1080P][MP4]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNull);
    });

    test('does not mistake a resolution number for an episode number', () {
      const title = '[Group][Show][1080P]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNull);
      expect(parsed.resolution, '1080P');
    });

    test(
      'does not mistake a file-size tag ending in GB for Simplified Chinese',
      () {
        const title = '[Group][Show][10][1080P][1.52GB]';
        final parsed = parseTitle(title);

        expect(parsed.subtitleLanguages, isNot(contains('简体')));
      },
    );

    test(
      'does not mistake an unrelated word containing TC for Traditional Chinese',
      () {
        const title = '[Group][Show][10][1080P][MATCH]';
        final parsed = parseTitle(title);

        expect(parsed.subtitleLanguages, isNot(contains('繁体')));
      },
    );

    test('recognizes 720p as a resolution', () {
      const title = '[Group][Show][10][720P]';
      final parsed = parseTitle(title);

      expect(parsed.resolution, '720P');
    });

    test('parses a SxxExx title (Nix-Raws style)', () {
      const title =
          '[Nix-Raws] ふつつかな悪女ではございますが S01E09 '
          '(Baha 1920x1080 AVC AAC MP4)';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(9), isTrue);
      expect(parsed.episodeRange!.expand(), [9]);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, 'Nix-Raws');
    });

    test('parses a bare Exx title', () {
      const title = '[SomeRaws] 恶女不才，请多关照 E09 [1080P]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.expand(), [9]);
    });

    test('parses a lowercase sxxexx title', () {
      const title = '[SomeRaws] 恶女不才，请多关照 s01e09 [1080P]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.expand(), [9]);
    });

    test('parses 第09话 / 第9集 / 第09話', () {
      for (final word in ['第09话', '第9集', '第09話']) {
        final parsed = parseTitle('[桜都字幕组] 恶女不才，请多关照 [$word][1080P][简体]');

        expect(parsed.episodeRange, isNotNull, reason: word);
        expect(parsed.episodeRange!.expand(), [9], reason: word);
      }
    });

    test('parses a v2 re-release episode number (TSDM style)', () {
      const title = '[TSDM字幕组][恶女不才，请多关照][09v2][1080p][简中]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.expand(), [9]);
      expect(parsed.alliance, 'TSDM字幕组');
      expect(parsed.resolution, '1080P');
    });

    test('regression: the pre-existing bare-number formats still parse', () {
      expect(
        parseTitle(
          '[ANi] 恶女不才，请多关照 - 09 [1080P][Baha][CHT][MP4]',
        ).episodeRange!.expand(),
        [9],
      );
      expect(
        parseTitle(
          '[ExileSub][恶女不才，请多关照][10][繁体][1080P]',
        ).episodeRange!.expand(),
        [10],
      );
      expect(
        parseTitle(
          '【澄空学园】★07月新番[恶女不才，请多关照][07-10][1080P][简体][MP4]',
        ).episodeRange!.expand(),
        [7, 8, 9, 10],
      );
    });

    test('regression: a bare resolution number is never an episode', () {
      // Exercises the _resolutionNumbers guard itself: a bare `1080` token
      // and a `1080v2` token must both be rejected, so that loosening any
      // episode pattern cannot smuggle a resolution into the episode slot.
      expect(
        parseTitle('[Group][Show][1080][1080P][MP4]').episodeRange,
        isNull,
      );
      expect(
        parseTitle('[Group][Show][1080v2][1080P][MP4]').episodeRange,
        isNull,
      );
    });
  });

  group('EpisodeRange', () {
    test('single contains only its own value', () {
      const range = EpisodeRange.single(5);
      expect(range.contains(5), isTrue);
      expect(range.contains(4), isFalse);
      expect(range.expand(), [5]);
    });

    test('range expands to all values inclusive', () {
      const range = EpisodeRange.range(7, 10);
      expect(range.expand(), [7, 8, 9, 10]);
      expect(range.contains(7), isTrue);
      expect(range.contains(10), isTrue);
      expect(range.contains(11), isFalse);
    });
  });
}
