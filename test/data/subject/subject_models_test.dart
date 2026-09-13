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

  group('CharacterInfo', () {
    /// Real item shape from `GET /v2/subjects/302286/characters?withActors=true`
    /// (a bare JSON array, one element shown).
    const realItem = {
      'index': 0,
      'character': {
        'id': 3320,
        'name': '黒崎一護',
        'nameCn': '黑崎一护',
        'imageLarge':
            'https://api.animeko.org/v2/characters/3320/image?size=large',
        'imageMedium':
            'https://api.animeko.org/v2/characters/3320/image?size=medium',
        'actors': [
          {
            'id': 4716,
            'name': '森田成一',
            'nameCn': '森田成一',
            'type': 1,
            'imageLarge': 'https://example.com/large',
            'imageMedium': 'https://example.com/medium',
            'summary': '',
          },
        ],
      },
      'role': 1,
    };

    test('parses the real wire shape', () {
      final related = RelatedCharacter.fromJson(
        Map<String, dynamic>.from(realItem),
      );

      expect(related.index, 0);
      expect(related.role, 1);
      expect(related.character.name, '黒崎一護');
      expect(related.character.nameCn, '黑崎一护');
      expect(
        related.character.imageMedium,
        'https://api.animeko.org/v2/characters/3320/image?size=medium',
      );
      expect(
        related.character.imageLarge,
        'https://api.animeko.org/v2/characters/3320/image?size=large',
      );
    });

    test('parses the voice actors', () {
      final related = RelatedCharacter.fromJson(
        Map<String, dynamic>.from(realItem),
      );

      expect(related.character.actors, hasLength(1));
      expect(related.character.actors.first.id, 4716);
      expect(related.character.actors.first.name, '森田成一');
      expect(related.character.actors.first.nameCn, '森田成一');
      expect(
        related.character.actors.first.imageMedium,
        'https://example.com/medium',
      );
    });

    test('actors defaults to empty when the key is absent', () {
      final related = RelatedCharacter.fromJson({
        'index': 3,
        'character': {'id': 9, 'name': 'ナメック星人'},
        'role': 2,
      });

      expect(related.character.actors, isEmpty);
      expect(related.character.nameCn, isNull);
      expect(related.character.imageMedium, isNull);
      expect(related.character.imageLarge, isNull);
    });

    // Two actors, because a character can have several CVs (different
    // eras/dubs) and the design pins the displayed one to `actors.first`
    // -- with a single-actor fixture `actors.last` would pass too.
    test('primaryActor is the first actor', () {
      final related = RelatedCharacter.fromJson({
        'index': 0,
        'character': {
          'id': 3320,
          'name': '黒崎一護',
          'actors': [
            {'id': 4716, 'name': '森田成一'},
            {'id': 9999, 'name': '別の声優'},
          ],
        },
        'role': 1,
      });

      expect(related.character.actors, hasLength(2));
      expect(related.character.primaryActor, isNotNull);
      expect(related.character.primaryActor!.id, 4716);
    });

    // `actors.first` would throw `Bad state: No element` here. The UI
    // hides the CV line on null, so this must stay null-not-throw.
    test('primaryActor is null when there are no actors', () {
      const character = CharacterInfo(id: 9, name: 'ナメック星人');

      expect(character.primaryActor, isNull);
    });

    group('displayName', () {
      test('prefers a non-empty nameCn', () {
        const character = CharacterInfo(id: 3320, name: '黒崎一護', nameCn: '黑崎一护');

        expect(character.displayName, '黑崎一护');
      });

      test('falls back to name when nameCn is absent', () {
        const character = CharacterInfo(id: 3320, name: '黒崎一護');

        expect(character.displayName, '黒崎一護');
      });

      // `''` has not been observed on this payload -- the guard is
      // `isNotEmpty` rather than a plain null check because it follows
      // the repo-wide display convention, whose precedent
      // (`subject_detail_screen.dart:283`) guards a non-nullable
      // `nameCn` on emptiness. Defensive, and pinned so it stays that way.
      test('falls back to name when nameCn is an empty string', () {
        const character = CharacterInfo(id: 3320, name: '黒崎一護', nameCn: '');

        expect(character.displayName, '黒崎一護');
      });
    });

    // Same reasoning as the `favorite`/`infobox` round-trips above:
    // `explicitToJson` is off, so `_$CharacterInfoToJson` emits the
    // `actors` list as raw `PersonInfo` instances and leaves the nested
    // conversion to `jsonEncode` calling their `toJson` transitively.
    test('round-trips the nested actors through toJson', () {
      final related = RelatedCharacter.fromJson(
        Map<String, dynamic>.from(realItem),
      );

      final encoded =
          jsonDecode(jsonEncode(related.character.toJson()))
              as Map<String, dynamic>;

      expect(encoded['actors'], [
        {
          'id': 4716,
          'name': '森田成一',
          'nameCn': '森田成一',
          'type': 1,
          'imageMedium': 'https://example.com/medium',
          'imageLarge': 'https://example.com/large',
          'summary': '',
        },
      ]);
      expect(CharacterInfo.fromJson(encoded).primaryActor!.name, '森田成一');
    });
  });

  group('PersonInfo', () {
    test('parses the actor shape seen inside a character', () {
      final person = PersonInfo.fromJson({
        'id': 4716,
        'name': '森田成一',
        'nameCn': '森田成一',
        'type': 1,
        'imageLarge': 'https://example.com/large',
        'imageMedium': 'https://example.com/medium',
        'summary': '',
      });

      expect(person.id, 4716);
      expect(person.type, 1);
      expect(person.imageLarge, 'https://example.com/large');
      expect(person.summary, '');
    });

    test('leaves every optional field null when absent', () {
      final person = PersonInfo.fromJson({'id': 1, 'name': '某人'});

      expect(person.nameCn, isNull);
      expect(person.type, isNull);
      expect(person.imageMedium, isNull);
      expect(person.imageLarge, isNull);
      expect(person.summary, isNull);
    });

    group('displayName', () {
      test('prefers a non-empty nameCn', () {
        const person = PersonInfo(id: 1, name: 'かかし', nameCn: '卡卡西');

        expect(person.displayName, '卡卡西');
      });

      test('falls back to name when nameCn is absent', () {
        const person = PersonInfo(id: 4716, name: '森田成一');

        expect(person.displayName, '森田成一');
      });

      // See the sibling CharacterInfo case: `''` is not an observed wire
      // value, the guard just follows the repo-wide display convention.
      test('falls back to name when nameCn is an empty string', () {
        const person = PersonInfo(id: 4716, name: '森田成一', nameCn: '');

        expect(person.displayName, '森田成一');
      });
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

    /// Subject 302286's infobox. The `原作` / `音乐` / `系列构成` /
    /// `放送开始` entries are verbatim from the live capture recorded in
    /// the design doc (`原作` including that doc's own `…` elision).
    ///
    /// Note `系列构成` arrives as ONE `、`-joined string, not one value
    /// per person -- the backend pre-joins multi-person credits, so a
    /// consumer rendering this shape does not have to join anything.
    ///
    /// `中文名` / `话数` / `官方网站` are keys the capture confirms exist
    /// on this subject, but it records only their names, so the values
    /// here are illustrative placeholders. Tests do assert on those
    /// values, but only to prove parsing/serialization round-trip --
    /// never as a claim about what the backend actually sends.
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
            {'v': '「BLEACH」久保帯人（集英社…）'},
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
            {'v': '田口智久、平松正樹'},
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

    /// SYNTHETIC, not observed: no field with more than one value has
    /// turned up on this backend yet (see [realInfobox] -- multi-person
    /// credits arrive pre-joined). Bangumi's infobox format permits a
    /// value list, so the parser has to cope with one; this fixture pins
    /// that and nothing more. Do not read it as evidence that the
    /// backend ever sends this shape.
    const multiValueInfobox = {
      'fields': [
        {
          'key': '系列构成',
          'values': [
            {'v': '田口智久'},
            {'v': '平松正樹'},
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
      final subject = buildWithInfobox(multiValueInfobox);
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

    // A value object with no `v` at all would otherwise fail the whole
    // `SubjectDetail.fromJson`, blanking the entire subject page over one
    // malformed infobox row. Degrading to '' keeps the page alive; see the
    // hand-written `MyCollectionSubject.fromJson` for the precedent.
    test('value v defaults to empty string when the wire omits it', () {
      final subject = buildWithInfobox({
        'fields': [
          {
            'key': '主题歌',
            'values': [
              {'k': 'OP'},
            ],
          },
        ],
      });

      expect(subject.infobox!.fields.first.values.first.k, 'OP');
      expect(subject.infobox!.fields.first.values.first.v, '');
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

    // Same reasoning as the sibling `favorite` round-trip: `explicitToJson`
    // is off, so `_$SubjectDetailToJson` emits the `SubjectInfobox` instance
    // as-is and leaves nested conversion to `jsonEncode` calling `toJson`
    // transitively. Go through jsonEncode so this covers real serialization.
    test('round-trips the nested infobox through toJson', () {
      final subject = buildWithInfobox(realInfobox);

      final encoded =
          jsonDecode(jsonEncode(subject.toJson())) as Map<String, dynamic>;

      expect(encoded['infobox'], {
        'template': 'Infobox animanga/TVAnime',
        'fields': [
          {
            'key': '中文名',
            'values': [
              {'k': null, 'v': '境·界 千年血战篇'},
            ],
          },
          {
            'key': '放送开始',
            'values': [
              {'k': null, 'v': '2022年10月10日'},
            ],
          },
          {
            'key': '话数',
            'values': [
              {'k': null, 'v': '13'},
            ],
          },
          {
            'key': '原作',
            'values': [
              {'k': null, 'v': '「BLEACH」久保帯人（集英社…）'},
            ],
          },
          {
            'key': '音乐',
            'values': [
              {'k': null, 'v': '鷺巣詩郎'},
            ],
          },
          {
            'key': '系列构成',
            'values': [
              {'k': null, 'v': '田口智久、平松正樹'},
            ],
          },
          {
            'key': '官方网站',
            'values': [
              {'k': null, 'v': 'https://example.com'},
            ],
          },
        ],
      });
      final reparsed = SubjectDetail.fromJson(encoded);
      expect(reparsed.infoboxValue('放送开始'), '2022年10月10日');
      expect(reparsed.staffFields.map((field) => field.key).toList(), [
        '原作',
        '音乐',
        '系列构成',
      ]);
    });

    group('infoboxValue', () {
      test('returns the first value of a matching field', () {
        final subject = buildWithInfobox(realInfobox);

        expect(subject.infoboxValue('放送开始'), '2022年10月10日');
        expect(subject.infoboxValue('话数'), '13');
        // Pre-joined by the backend -- this is the whole credit, not a
        // truncation. A consumer needs no `join` for this shape.
        expect(subject.infoboxValue('系列构成'), '田口智久、平松正樹');
      });

      test('returns only the first value when a field has several', () {
        final subject = buildWithInfobox(multiValueInfobox);

        expect(subject.infoboxValue('系列构成'), '田口智久');
      });

      test('returns null for a key that is not present', () {
        final subject = buildWithInfobox(realInfobox);

        expect(subject.infoboxValue('不存在的键'), isNull);
      });

      test('returns null when the only matching field has no values', () {
        final subject = buildWithInfobox({
          'fields': [
            {'key': '别名', 'values': <dynamic>[]},
          ],
        });

        expect(subject.infoboxValue('别名'), isNull);
      });

      // Duplicate keys are realistic on a wiki-sourced infobox, so which
      // one wins is pinned rather than left to chance: an empty field is
      // skipped and the scan continues.
      test('skips a matching field with no values and returns a later '
          'duplicate', () {
        final subject = buildWithInfobox({
          'fields': [
            {'key': '别名', 'values': <dynamic>[]},
            {
              'key': '别名',
              'values': [
                {'v': 'Thousand-Year Blood War'},
              ],
            },
          ],
        });

        expect(subject.infoboxValue('别名'), 'Thousand-Year Blood War');
      });

      test('returns the first of two non-empty duplicate keys', () {
        final subject = buildWithInfobox({
          'fields': [
            {
              'key': '别名',
              'values': [
                {'v': '第一个'},
              ],
            },
            {
              'key': '别名',
              'values': [
                {'v': '第二个'},
              ],
            },
          ],
        });

        expect(subject.infoboxValue('别名'), '第一个');
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

      // Matches `infoboxValue`'s treatment of an empty `values`, and
      // spares the 制作人员 renderer from emitting a role label with a
      // blank value next to it.
      test('drops a staff role whose values list is empty', () {
        final subject = buildWithInfobox({
          'fields': [
            {'key': '原作', 'values': <dynamic>[]},
            {
              'key': '音乐',
              'values': [
                {'v': '鷺巣詩郎'},
              ],
            },
          ],
        });

        expect(subject.staffFields.map((field) => field.key).toList(), ['音乐']);
      });
    });
  });
}
