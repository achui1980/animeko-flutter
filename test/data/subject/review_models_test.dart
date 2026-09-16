import 'dart:convert';

import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Real response from `GET /v2/subjects/302286/reviews?limit=1`.
  const realResponse = {
    'total': 2,
    'items': [
      {
        'id': 'bangumi:302286:1261526',
        'subjectId': 302286,
        'source': 'bangumi',
        'author': {
          'id': '1261526',
          'nickname': 'Guating',
          'avatarUrl':
              'https://static.myani.org/bangumi/avatars/1261526/c49f899d85642d15.jpg',
        },
        'contentBbcode': '对比老tv质的飞跃，观感不错，新加的内容是很好的补充。',
        'updatedAt': '2026-09-11T13:56:03Z',
        'rating': 8,
        'likeCount': 0,
      },
    ],
  };

  group('SubjectReview', () {
    test('parses the real wire shape', () {
      final page = PaginatedReviews.fromJson(
        Map<String, dynamic>.from(realResponse),
      );
      final review = page.items.single;

      expect(review.id, 'bangumi:302286:1261526');
      expect(review.subjectId, 302286);
      expect(review.source, 'bangumi');
      expect(review.contentBbcode, '对比老tv质的飞跃，观感不错，新加的内容是很好的补充。');
      expect(review.updatedAt, '2026-09-11T13:56:03Z');
      expect(review.rating, 8);
      expect(review.likeCount, 0);
      expect(review.author.id, '1261526');
      expect(review.author.nickname, 'Guating');
      expect(
        review.author.avatarUrl,
        'https://static.myani.org/bangumi/avatars/1261526/c49f899d85642d15.jpg',
      );
    });

    test('tolerates a missing avatar, content, rating and likeCount', () {
      final page = PaginatedReviews.fromJson({
        'total': 1,
        'items': [
          {
            'id': 'bangumi:1:2',
            'subjectId': 1,
            'source': 'bangumi',
            'author': {'id': '2', 'nickname': '匿名'},
          },
        ],
      });
      final review = page.items.single;

      expect(review.author.avatarUrl, isNull);
      expect(review.contentBbcode, isNull);
      expect(review.updatedAt, isNull);
      expect(review.rating, isNull);
      expect(review.likeCount, 0);
    });

    test('coerces an explicitly null likeCount to 0', () {
      // `@JsonKey(defaultValue: 0)` has to cover an explicit JSON `null`,
      // not just an absent key -- otherwise `likeCount` would throw a
      // cast error on a response that spells the field out as null.
      final page = PaginatedReviews.fromJson({
        'total': 1,
        'items': [
          {
            'id': 'bangumi:1:2',
            'subjectId': 1,
            'source': 'bangumi',
            'author': {'id': '2', 'nickname': '匿名'},
            'likeCount': null,
          },
        ],
      });

      expect(page.items.single.likeCount, 0);
    });

    test('items defaults to empty when absent', () {
      final page = PaginatedReviews.fromJson({'total': 0});

      expect(page.items, isEmpty);
    });

    // `explicitToJson` is off repo-wide (there is no `build.yaml`), so
    // `_$PaginatedReviewsToJson` emits `items` as raw `SubjectReview`
    // instances and leaves the nested conversion to `jsonEncode` calling
    // their `toJson` transitively -- same as the `favorite`/`infobox`/
    // `actors` round-trips in `subject_models_test.dart`. Round-trip
    // through jsonEncode so this covers what real serialization does.
    test('round-trips the nested items through toJson', () {
      final page = PaginatedReviews.fromJson(
        Map<String, dynamic>.from(realResponse),
      );

      final encoded =
          jsonDecode(jsonEncode(page.toJson())) as Map<String, dynamic>;

      expect(encoded['total'], 2);
      expect(encoded['items'], [
        {
          'id': 'bangumi:302286:1261526',
          'subjectId': 302286,
          'source': 'bangumi',
          'author': {
            'id': '1261526',
            'nickname': 'Guating',
            'avatarUrl':
                'https://static.myani.org/bangumi/avatars/1261526/c49f899d85642d15.jpg',
          },
          'contentBbcode': '对比老tv质的飞跃，观感不错，新加的内容是很好的补充。',
          'updatedAt': '2026-09-11T13:56:03Z',
          'rating': 8,
          'likeCount': 0,
        },
      ]);
      expect(
        PaginatedReviews.fromJson(encoded).items.single.author.nickname,
        'Guating',
      );
    });
  });

  group('PaginatedReviews.hasMore', () {
    test('is true when total exceeds the returned item count', () {
      // The backend returns total == limit + 1 whenever more rows exist.
      final page = PaginatedReviews.fromJson(
        Map<String, dynamic>.from(realResponse),
      );

      expect(page.items, hasLength(1));
      expect(page.total, 2);
      expect(page.hasMore, isTrue);
    });

    test('is false when total equals the returned item count', () {
      final page = PaginatedReviews.fromJson({
        'total': 1,
        'items': [
          {
            'id': 'bangumi:1:2',
            'subjectId': 1,
            'source': 'bangumi',
            'author': {'id': '2', 'nickname': '匿名'},
          },
        ],
      });

      expect(page.hasMore, isFalse);
    });

    test('is false for an empty page', () {
      final page = PaginatedReviews.fromJson({
        'total': 0,
        'items': <dynamic>[],
      });

      expect(page.hasMore, isFalse);
    });

    // Pins the comparison from the other side: a full page whose `total`
    // sentinel has NOT been bumped must not claim another page exists.
    // Without this, mutating `hasMore` to `total > items.length - 1` (or
    // to anything that ignores the off-by-one) still passes.
    test('is false when a multi-item page is exactly exhausted', () {
      SubjectReview review(String id) => SubjectReview(
        id: id,
        subjectId: 1,
        source: 'bangumi',
        author: const ReviewAuthor(id: '2', nickname: '匿名'),
      );
      final page = PaginatedReviews(
        total: 3,
        items: [review('a'), review('b'), review('c')],
      );

      expect(page.hasMore, isFalse);
    });

    // Guards the DIRECTION of the comparison, not an observed wire shape:
    // the backend should never send fewer `total` than `items`, but if it
    // does, "there is another page" is the one answer that must not come
    // out -- `loadMore` would then never terminate. Pins the operator as
    // `>` rather than `!=`.
    test('is false when total is below the returned item count', () {
      SubjectReview review(String id) => SubjectReview(
        id: id,
        subjectId: 1,
        source: 'bangumi',
        author: const ReviewAuthor(id: '2', nickname: '匿名'),
      );
      final page = PaginatedReviews(
        total: 0,
        items: [review('a'), review('b')],
      );

      expect(page.hasMore, isFalse);
    });

    // Deliberate: `total` is load-bearing for `hasMore`, and every probed
    // response carried it. A missing `total` throwing here degrades to
    // "the 热门评价 card silently hides" rather than to a wrong hasMore.
    test('throws when total is absent -- it is load-bearing for hasMore', () {
      expect(
        () => PaginatedReviews.fromJson({'items': <dynamic>[]}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
