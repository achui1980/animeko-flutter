import 'dart:convert';

import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelfRating', () {
    test('parses a rated self-rating', () {
      final rating = SelfRating.fromJson({
        'score': 8,
        'tags': ['神作', '泪目'],
        'isPrivate': false,
        'comment': '很好看',
      });
      expect(rating.score, 8);
      expect(rating.tags, ['神作', '泪目']);
      expect(rating.isPrivate, false);
      expect(rating.comment, '很好看');
    });

    test('parses an unrated self-rating with score 0 and null comment', () {
      final rating = SelfRating.fromJson({
        'score': 0,
        'tags': <String>[],
        'isPrivate': false,
        'comment': null,
      });
      expect(rating.score, 0);
      expect(rating.comment, isNull);
    });

    test('round-trips through toJson', () {
      const rating = SelfRating(
        score: 7,
        tags: ['a'],
        isPrivate: true,
        comment: 'x',
      );
      final json = rating.toJson();
      expect(SelfRating.fromJson(json).score, 7);
      expect(json['isPrivate'], true);
    });
  });

  group('SubjectDetail', () {
    Map<String, dynamic> baseJson({String? collectionType}) => {
      'id': 400602,
      'name': 'Sousou no Frieren',
      'nameCn': '葬送的芙莉莲',
      'summary': '勇者一行人击败魔王后……',
      'airDate': '2023-09-29',
      'tags': [
        {'name': '奇幻', 'count': 120},
        {'name': '冒险', 'count': 80},
      ],
      'score': '8.4',
      'rank': 12,
      'collectionType': collectionType,
      'selfRating': {
        'score': 0,
        'tags': <String>[],
        'isPrivate': false,
        'comment': null,
      },
    };

    test('parses a subject with no collection (null collectionType)', () {
      final detail = SubjectDetail.fromJson(baseJson());
      expect(detail.id, 400602);
      expect(detail.nameCn, '葬送的芙莉莲');
      expect(detail.tags, hasLength(2));
      expect(detail.tags.first.name, '奇幻');
      expect(detail.score, '8.4');
      expect(detail.rank, 12);
      expect(detail.collectionType, isNull);
      expect(detail.selfRating.score, 0);
    });

    test('parses a subject with a non-null collectionType', () {
      final detail = SubjectDetail.fromJson(baseJson(collectionType: 'DOING'));
      expect(detail.collectionType, CollectionType.doing);
    });

    test('parses a subject with null score and rank', () {
      final json = baseJson()
        ..['score'] = null
        ..['rank'] = null;
      final detail = SubjectDetail.fromJson(json);
      expect(detail.score, isNull);
      expect(detail.rank, isNull);
    });

    test('round-trips collectionType through toJson', () {
      final detail = SubjectDetail.fromJson(
        baseJson(collectionType: 'ON_HOLD'),
      );
      expect(detail.toJson()['collectionType'], 'ON_HOLD');
    });

    test('parses aliases when present', () {
      final json = baseJson()..['aliases'] = ['Sousou no Frieren', '葬送のフリーレン'];
      final detail = SubjectDetail.fromJson(json);
      expect(detail.aliases, ['Sousou no Frieren', '葬送のフリーレン']);
    });

    test('defaults aliases to an empty list when absent from JSON', () {
      final detail = SubjectDetail.fromJson(baseJson());
      expect(detail.aliases, isEmpty);
    });

    test('parses scoreDetails when present', () {
      final json = baseJson()
        ..['scoreDetails'] = {
          '1': 130,
          '2': 37,
          '3': 51,
          '4': 111,
          '5': 352,
          '6': 1081,
          '7': 3659,
          '8': 10440,
          '9': 12845,
          '10': 7445,
        };
      final detail = SubjectDetail.fromJson(json);
      expect(detail.scoreDetails, {
        '1': 130,
        '2': 37,
        '3': 51,
        '4': 111,
        '5': 352,
        '6': 1081,
        '7': 3659,
        '8': 10440,
        '9': 12845,
        '10': 7445,
      });
    });

    test('scoreDetails is null when absent from JSON', () {
      final detail = SubjectDetail.fromJson(baseJson());
      expect(detail.scoreDetails, isNull);
    });

    test('parses the embedded episodes array into SubjectEpisode models', () {
      final json = baseJson()
        ..['episodes'] = [
          {'episodeId': 1, 'type': 'MAIN', 'sort': '1', 'nameCn': '第一话'},
          {'episodeId': 3, 'type': 'OP', 'sort': '1'},
        ];

      final detail = SubjectDetail.fromJson(json);

      expect(detail.episodes, hasLength(2));
      expect(detail.episodes![0].episodeId, 1);
      expect(detail.episodes![0].sort, 1);
      expect(detail.episodes![0].displayName, '第一话');
      expect(detail.episodes![0].isMain, isTrue);
      expect(detail.episodes![1].isMain, isFalse);
    });

    test('episodes is null when absent from JSON', () {
      final detail = SubjectDetail.fromJson(baseJson());
      expect(detail.episodes, isNull);
    });

    test('counts only MAIN-type entries in the embedded episodes array', () {
      final json = baseJson()
        ..['episodes'] = [
          {'episodeId': 1, 'type': 'MAIN', 'sort': '1'},
          {'episodeId': 2, 'type': 'MAIN', 'sort': '2'},
          {'episodeId': 3, 'type': 'OP', 'sort': '1'},
          {'episodeId': 4, 'type': 'ED', 'sort': '1'},
          {'episodeId': 5, 'type': 'SPECIAL', 'sort': '1'},
        ];
      final detail = SubjectDetail.fromJson(json);
      expect(detail.episodeCount, 2);
    });

    test('episodeCount is null when episodes is absent from JSON', () {
      final detail = SubjectDetail.fromJson(baseJson());
      expect(detail.episodeCount, isNull);
    });

    // Distinct from the null case above: an *empty* array means "we know
    // there are no episodes", which must render as 话数：0 rather than
    // silently omitting the line the way a null does.
    test('episodeCount is 0 when the episodes array is present but empty', () {
      final detail = SubjectDetail.fromJson(baseJson()..['episodes'] = []);
      expect(detail.episodeCount, 0);
    });
  });

  group('CharacterInfo / RelatedCharacter', () {
    test('parses a related character with a voice actor image', () {
      final related = RelatedCharacter.fromJson({
        'index': 0,
        'character': {'name': '芙莉莲', 'imageUrl': 'https://example.com/f.jpg'},
        'role': 1,
      });
      expect(related.index, 0);
      expect(related.character.name, '芙莉莲');
      expect(related.character.imageUrl, 'https://example.com/f.jpg');
      expect(related.role, 1);
    });

    test('parses a character with a null image', () {
      final related = RelatedCharacter.fromJson({
        'index': 1,
        'character': {'name': '费伦', 'imageUrl': null},
        'role': 2,
      });
      expect(related.character.imageUrl, isNull);
    });
  });

  group('StaffMember', () {
    test('parses a staff member with a role and image', () {
      final staff = StaffMember.fromJson({
        'name': '渡边步',
        'imageUrl': 'https://example.com/s.jpg',
        'role': '导演',
      });
      expect(staff.name, '渡边步');
      expect(staff.imageUrl, 'https://example.com/s.jpg');
      expect(staff.role, '导演');
    });

    test('parses a staff member with null role and image', () {
      final staff = StaffMember.fromJson({
        'name': '某人',
        'imageUrl': null,
        'role': null,
      });
      expect(staff.imageUrl, isNull);
      expect(staff.role, isNull);
    });
  });

  group('MyCollectionSubject / PaginatedCollections', () {
    test('parses a collection-list item with a collectionType', () {
      final item = MyCollectionSubject.fromJson({
        'subjectId': 400602,
        'name': 'Sousou no Frieren',
        'nameCn': '葬送的芙莉莲',
        'collectionType': 'WISH',
      });
      expect(item.subjectId, 400602);
      expect(item.collectionType, CollectionType.wish);
    });

    test('parses a collection-list item that uses "id" instead of "subjectId" '
        '(real server observed to omit "subjectId" entirely)', () {
      final item = MyCollectionSubject.fromJson({
        'id': 900,
        'name': 'Nikogyanya',
        'nameCn': '尼古喵喵',
      });
      expect(item.subjectId, 900);
    });

    test(
      'parses a response with no total field (real server observed to omit it)',
      () {
        final page = PaginatedCollections.fromJson({
          'items': [
            {'subjectId': 1, 'name': 'A', 'nameCn': 'A-cn'},
          ],
        });

        expect(page.items, hasLength(1));
        expect(page.total, isNull);
      },
    );

    test('parses a paginated response with items and total', () {
      final page = PaginatedCollections.fromJson({
        'items': [
          {
            'subjectId': 1,
            'name': 'A',
            'nameCn': 'A-cn',
            'collectionType': 'DOING',
          },
          {
            'subjectId': 2,
            'name': 'B',
            'nameCn': 'B-cn',
            'collectionType': null,
          },
        ],
        'total': 2,
      });
      expect(page.items, hasLength(2));
      expect(page.total, 2);
      expect(page.items.last.collectionType, isNull);
    });
  });

  group('SubjectFavorite', () {
    test('parses the favorite object from the wire', () {
      final subject = SubjectDetail.fromJson({
        'id': 302286,
        'name': 'BLEACH 千年血戦篇',
        'nameCn': '境·界 千年血战篇',
        'summary': '',
        'airDate': '2022-10-10',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
        'favorite': {
          'wish': 2138,
          'done': 7420,
          'doing': 1102,
          'onHold': 360,
          'dropped': 177,
        },
      });

      expect(subject.favorite, isNotNull);
      expect(subject.favorite!.wish, 2138);
      expect(subject.favorite!.done, 7420);
      expect(subject.favorite!.doing, 1102);
      expect(subject.favorite!.onHold, 360);
      expect(subject.favorite!.dropped, 177);
    });

    test('favorite is null when the key is absent', () {
      final subject = SubjectDetail.fromJson({
        'id': 1,
        'name': 'x',
        'nameCn': 'x',
        'summary': '',
        'airDate': '2020-01-01',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
      });

      expect(subject.favorite, isNull);
    });

    test('missing counters default to zero', () {
      final subject = SubjectDetail.fromJson({
        'id': 1,
        'name': 'x',
        'nameCn': 'x',
        'summary': '',
        'airDate': '2020-01-01',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
        'favorite': {'done': 5},
      });

      expect(subject.favorite!.done, 5);
      expect(subject.favorite!.wish, 0);
      expect(subject.favorite!.doing, 0);
      expect(subject.favorite!.onHold, 0);
      expect(subject.favorite!.dropped, 0);
    });

    // Distinct from the absent case above: an *empty* object means "we
    // have the counters and they are all zero", so the 收藏统计 block
    // renders 0/0/0 rather than hiding itself the way a null does.
    test('favorite is non-null with all-zero counters when the object is '
        'present but empty', () {
      final subject = SubjectDetail.fromJson({
        'id': 1,
        'name': 'x',
        'nameCn': 'x',
        'summary': '',
        'airDate': '2020-01-01',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
        'favorite': <String, dynamic>{},
      });

      expect(subject.favorite, isNotNull);
      expect(subject.favorite!.wish, 0);
      expect(subject.favorite!.done, 0);
      expect(subject.favorite!.doing, 0);
      expect(subject.favorite!.onHold, 0);
      expect(subject.favorite!.dropped, 0);
    });

    // `explicitToJson` is off, so `_$SubjectDetailToJson` emits the
    // `SubjectFavorite` instance as-is and leaves the nested conversion to
    // `jsonEncode` calling its `toJson` transitively -- exactly like the
    // pre-existing `selfRating` field. Round-trip through jsonEncode rather
    // than asserting on the raw map, so this covers what real serialization
    // actually does.
    test('round-trips the nested favorite object through toJson', () {
      final subject = SubjectDetail.fromJson({
        'id': 302286,
        'name': 'BLEACH 千年血戦篇',
        'nameCn': '境·界 千年血战篇',
        'summary': '',
        'airDate': '2022-10-10',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
        'favorite': {
          'wish': 2138,
          'done': 7420,
          'doing': 1102,
          'onHold': 360,
          'dropped': 177,
        },
      });

      final encoded =
          jsonDecode(jsonEncode(subject.toJson())) as Map<String, dynamic>;

      expect(encoded['favorite'], {
        'wish': 2138,
        'done': 7420,
        'doing': 1102,
        'onHold': 360,
        'dropped': 177,
      });
      expect(SubjectDetail.fromJson(encoded).favorite!.done, 7420);
    });
  });

  group('SubjectInfobox', () {
    /// Real subset of subject 302286's infobox.
    SubjectDetail buildWithInfobox(Map<String, dynamic> infobox) {
      return SubjectDetail.fromJson({
        'id': 302286,
        'name': 'BLEACH 千年血戦篇',
        'nameCn': '境·界 千年血战篇',
        'summary': '',
        'airDate': '2022-10-10',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
        'infobox': infobox,
      });
    }

    const realInfobox = {
      'template': 'Infobox animanga/TVAnime',
      'fields': [
        {
          'key': '中文名',
          'values': [
            {'v': '境·界 千年血战篇'},
          ],
        },
        {
          'key': '放送开始',
          'values': [
            {'v': '2022年10月10日'},
          ],
        },
        {
          'key': '话数',
          'values': [
            {'v': '13'},
          ],
        },
        {
          'key': '原作',
          'values': [
            {'v': '「BLEACH」久保帯人（集英社「週刊少年ジャンプ」連載）'},
          ],
        },
        {
          'key': '音乐',
          'values': [
            {'v': '鷺巣詩郎'},
          ],
        },
        {
          'key': '系列构成',
          'values': [
            {'v': '田口智久'},
            {'v': '平松正樹'},
          ],
        },
        {
          'key': '官方网站',
          'values': [
            {'v': 'https://example.com'},
          ],
        },
      ],
    };

    test('parses template and fields', () {
      final subject = buildWithInfobox(realInfobox);

      expect(subject.infobox, isNotNull);
      expect(subject.infobox!.template, 'Infobox animanga/TVAnime');
      expect(subject.infobox!.fields.length, 7);
      expect(subject.infobox!.fields.first.key, '中文名');
      expect(subject.infobox!.fields.first.values.first.v, '境·界 千年血战篇');
    });

    test('parses a field with multiple values', () {
      final subject = buildWithInfobox(realInfobox);
      final field = subject.infobox!.fields.firstWhere((f) => f.key == '系列构成');

      expect(field.values.map((value) => value.v).toList(), ['田口智久', '平松正樹']);
    });

    test('value k is null when absent', () {
      final subject = buildWithInfobox(realInfobox);

      expect(subject.infobox!.fields.first.values.first.k, isNull);
    });

    test('value k is parsed when present', () {
      final subject = buildWithInfobox({
        'fields': [
          {
            'key': '主题歌',
            'values': [
              {'k': 'OP', 'v': 'Scar'},
            ],
          },
        ],
      });

      expect(subject.infobox!.fields.first.values.first.k, 'OP');
      expect(subject.infobox!.fields.first.values.first.v, 'Scar');
    });

    test('infobox is null when the key is absent', () {
      final subject = SubjectDetail.fromJson({
        'id': 1,
        'name': 'x',
        'nameCn': 'x',
        'summary': '',
        'airDate': '2020-01-01',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
      });

      expect(subject.infobox, isNull);
      expect(subject.infoboxValue('原作'), isNull);
      expect(subject.staffFields, isEmpty);
    });

    test('fields defaults to empty when absent', () {
      final subject = buildWithInfobox({'template': 'x'});

      expect(subject.infobox!.fields, isEmpty);
    });

    group('infoboxValue', () {
      test('returns the first value of a matching field', () {
        final subject = buildWithInfobox(realInfobox);

        expect(subject.infoboxValue('放送开始'), '2022年10月10日');
        expect(subject.infoboxValue('话数'), '13');
        expect(subject.infoboxValue('系列构成'), '田口智久');
      });

      test('returns null for a key that is not present', () {
        final subject = buildWithInfobox(realInfobox);

        expect(subject.infoboxValue('不存在的键'), isNull);
      });
    });

    group('staffFields', () {
      test('keeps staff roles and drops blocklisted metadata keys', () {
        final subject = buildWithInfobox(realInfobox);
        final keys = subject.staffFields.map((field) => field.key).toList();

        expect(keys, ['原作', '音乐', '系列构成']);
        expect(keys, isNot(contains('中文名')));
        expect(keys, isNot(contains('放送开始')));
        expect(keys, isNot(contains('话数')));
        expect(keys, isNot(contains('官方网站')));
      });

      test('keeps a role key that was never observed before', () {
        final subject = buildWithInfobox({
          'fields': [
            {
              'key': '某种全新的没见过的职位',
              'values': [
                {'v': '某人'},
              ],
            },
          ],
        });

        expect(subject.staffFields.map((field) => field.key).toList(), [
          '某种全新的没见过的职位',
        ]);
      });
    });
  });
}
