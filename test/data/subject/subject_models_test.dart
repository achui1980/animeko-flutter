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
      const rating = SelfRating(score: 7, tags: ['a'], isPrivate: true, comment: 'x');
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
      final json = baseJson()..['score'] = null..['rank'] = null;
      final detail = SubjectDetail.fromJson(json);
      expect(detail.score, isNull);
      expect(detail.rank, isNull);
    });

    test('round-trips collectionType through toJson', () {
      final detail = SubjectDetail.fromJson(baseJson(collectionType: 'ON_HOLD'));
      expect(detail.toJson()['collectionType'], 'ON_HOLD');
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
      final staff = StaffMember.fromJson({'name': '某人', 'imageUrl': null, 'role': null});
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
          {'subjectId': 1, 'name': 'A', 'nameCn': 'A-cn', 'collectionType': 'DOING'},
          {'subjectId': 2, 'name': 'B', 'nameCn': 'B-cn', 'collectionType': null},
        ],
        'total': 2,
      });
      expect(page.items, hasLength(2));
      expect(page.total, 2);
      expect(page.items.last.collectionType, isNull);
    });
  });
}
