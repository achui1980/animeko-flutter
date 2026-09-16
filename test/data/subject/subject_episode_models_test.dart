import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The wire shape here mirrors what `GET /v2/subjects/{id}` on the Animeko
/// backend actually embeds under its `episodes` key (verified against live
/// responses). Notably `sort` and `ep` arrive as *strings*, and `type` is a
/// string enum (`MAIN`/`SPECIAL`/`OP`/`ED`) rather than Bangumi's numeric code.
Map<String, dynamic> baseJson() => <String, dynamic>{
  'episodeId': 1127992,
  'subjectId': 302286,
  'sort': '1',
  'ep': '1',
  'type': 'MAIN',
  'name': 'THE BLOOD WARFARE',
  'nameCn': '血战',
  'description': '',
  'airdate': '2022-10-10',
  'disc': 0,
  'duration': '00:24:07',
};

void main() {
  group('SubjectEpisode.fromJson', () {
    test('parses the live wire shape', () {
      final episode = SubjectEpisode.fromJson(baseJson());

      expect(episode.episodeId, 1127992);
      expect(episode.sort, 1);
      expect(episode.ep, '1');
      expect(episode.type, 'MAIN');
      expect(episode.name, 'THE BLOOD WARFARE');
      expect(episode.nameCn, '血战');
      expect(episode.airdate, '2022-10-10');
    });

    test('parses a decimal string sort without losing precision', () {
      final episode = SubjectEpisode.fromJson(baseJson()..['sort'] = '7.5');

      expect(episode.sort, 7.5);
    });

    test(
      'accepts a numeric sort in case the backend stops stringifying it',
      () {
        final episode = SubjectEpisode.fromJson(baseJson()..['sort'] = 12);

        expect(episode.sort, 12);
      },
    );

    test('falls back to sort 0 when sort is missing or unparseable', () {
      expect(SubjectEpisode.fromJson(baseJson()..remove('sort')).sort, 0);
      expect(SubjectEpisode.fromJson(baseJson()..['sort'] = '').sort, 0);
      expect(SubjectEpisode.fromJson(baseJson()..['sort'] = 'abc').sort, 0);
    });

    test('tolerates a null ep, which SPECIAL entries can have', () {
      final episode = SubjectEpisode.fromJson(baseJson()..['ep'] = null);

      expect(episode.ep, isNull);
    });

    test('defaults the text fields to empty strings when absent', () {
      final json = baseJson()
        ..remove('name')
        ..remove('nameCn')
        ..remove('airdate');

      final episode = SubjectEpisode.fromJson(json);

      expect(episode.name, '');
      expect(episode.nameCn, '');
      expect(episode.airdate, '');
    });

    test('defaults type to an empty string when absent so isMain is false', () {
      final episode = SubjectEpisode.fromJson(baseJson()..remove('type'));

      expect(episode.type, '');
      expect(episode.isMain, isFalse);
    });
  });

  group('SubjectEpisode.isMain', () {
    test('is true only for MAIN entries', () {
      expect(
        SubjectEpisode.fromJson(baseJson()..['type'] = 'MAIN').isMain,
        isTrue,
      );
      expect(
        SubjectEpisode.fromJson(baseJson()..['type'] = 'SPECIAL').isMain,
        isFalse,
      );
      expect(
        SubjectEpisode.fromJson(baseJson()..['type'] = 'OP').isMain,
        isFalse,
      );
      expect(
        SubjectEpisode.fromJson(baseJson()..['type'] = 'ED').isMain,
        isFalse,
      );
    });
  });

  group('SubjectEpisode.displayName', () {
    test('prefers the Chinese name', () {
      final episode = SubjectEpisode.fromJson(baseJson());

      expect(episode.displayName, '血战');
    });

    test('falls back to the original name when nameCn is empty', () {
      final episode = SubjectEpisode.fromJson(baseJson()..['nameCn'] = '');

      expect(episode.displayName, 'THE BLOOD WARFARE');
    });
  });
}
