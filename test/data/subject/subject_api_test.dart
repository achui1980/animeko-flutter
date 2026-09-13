import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> jsonResponse(
  Map<String, dynamic> body, {
  String path = '/',
}) {
  return Response(
    data: body,
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
  );
}

void main() {
  late MockDio dio;
  late SubjectApi api;

  setUp(() {
    dio = MockDio();
    api = SubjectApi(dio);
  });

  group('getSubject', () {
    final detailJson = {
      'id': 400602,
      'name': 'Sousou no Frieren',
      'nameCn': '葬送的芙莉莲',
      'summary': '勇者一行人击败魔王后……',
      'airDate': '2023-09-29',
      'tags': [
        {'name': '奇幻', 'count': 120},
      ],
      'score': '8.4',
      'rank': 12,
      'collectionType': 'DOING',
      'selfRating': {
        'score': 0,
        'tags': <String>[],
        'isPrivate': false,
        'comment': null,
      },
    };

    test('GETs the exact subject-detail path', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => jsonResponse(detailJson));

      await api.getSubject(400602);

      verify(
        () => dio.get<Map<String, dynamic>>('/v2/subjects/400602'),
      ).called(1);
    });

    test('parses the response into a SubjectDetail', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => jsonResponse(detailJson));

      final detail = await api.getSubject(400602);

      expect(detail.id, 400602);
      expect(detail.nameCn, '葬送的芙莉莲');
      expect(detail.collectionType?.wireValue, 'DOING');
    });
  });

  group('updateCollection', () {
    test('PATCHes only collectionType when selfRating is omitted', () async {
      when(() => dio.patch<void>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 200,
        ),
      );

      await api.updateCollection(400602, collectionType: CollectionType.doing);

      verify(
        () => dio.patch<void>(
          '/v2/subjects/400602',
          data: {'collectionType': 'DOING'},
        ),
      ).called(1);
    });

    test('PATCHes only selfRating when collectionType is omitted', () async {
      when(() => dio.patch<void>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 200,
        ),
      );

      const rating = SelfRating(
        score: 8,
        tags: [],
        isPrivate: false,
        comment: '好看',
      );

      await api.updateCollection(400602, selfRating: rating);

      verify(
        () => dio.patch<void>(
          '/v2/subjects/400602',
          data: {'selfRating': rating.toJson()},
        ),
      ).called(1);
    });

    test('PATCHes both fields together when both are given', () async {
      when(() => dio.patch<void>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 200,
        ),
      );

      const rating = SelfRating(
        score: 9,
        tags: [],
        isPrivate: true,
        comment: null,
      );

      await api.updateCollection(
        400602,
        collectionType: CollectionType.done,
        selfRating: rating,
      );

      verify(
        () => dio.patch<void>(
          '/v2/subjects/400602',
          data: {'collectionType': 'DONE', 'selfRating': rating.toJson()},
        ),
      ).called(1);
    });
  });

  group('deleteCollection', () {
    test('DELETEs the exact subject path', () async {
      when(() => dio.delete<void>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 200,
        ),
      );

      await api.deleteCollection(400602);

      verify(() => dio.delete<void>('/v2/subjects/400602')).called(1);
    });
  });

  group('getCharacters', () {
    /// `/characters` is declared as `get<dynamic>` because the endpoint
    /// answers with a bare JSON array, so its stubs cannot reuse the
    /// `Response<Map<String, dynamic>>`-typed [jsonResponse] helper.
    Response<dynamic> characterResponse(dynamic body) => Response<dynamic>(
      data: body,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );

    /// A trimmed element of the real `GET /v2/subjects/302286/characters?
    /// withActors=true` payload -- the actor's `imageLarge`/`imageMedium`/
    /// `summary` are dropped because nothing here asserts on them. The
    /// untrimmed element lives in `subject_models_test.dart`.
    Map<String, dynamic> realItem() => {
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
          {'id': 4716, 'name': '森田成一', 'nameCn': '森田成一', 'type': 1},
        ],
      },
      'role': 1,
    };

    test('GETs with withActors=true query param', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => characterResponse(<dynamic>[]));

      await api.getCharacters(400602);

      verify(
        () => dio.get<dynamic>(
          '/v2/subjects/400602/characters',
          queryParameters: {'withActors': true},
        ),
      ).called(1);
    });

    // The real endpoint returns a BARE ARRAY -- no `items` envelope.
    // Parsing it as one used to throw on every single call.
    test('parses a bare JSON array of related characters', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => characterResponse(<dynamic>[
          realItem(),
          {
            'index': 1,
            'character': {'id': 3321, 'name': '朽木ルキア'},
            'role': 2,
          },
        ]),
      );

      final characters = await api.getCharacters(400602);

      expect(characters, hasLength(2));
      expect(characters.first.character.name, '黒崎一護');
      expect(characters.first.character.primaryActor?.name, '森田成一');
      expect(characters.last.character.imageMedium, isNull);
      expect(characters.last.character.actors, isEmpty);
      expect(characters.last.character.primaryActor, isNull);
    });

    // Defensive branch: keeps working if the backend ever wraps the
    // array in the `{items: [...]}` envelope every other list endpoint
    // in this codebase uses.
    test('still parses an items envelope if the backend adds one', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => characterResponse(<String, dynamic>{
          'items': <dynamic>[realItem()],
        }),
      );

      final characters = await api.getCharacters(400602);

      expect(characters, hasLength(1));
      expect(characters.single.character.nameCn, '黑崎一护');
    });

    test('returns an empty list when the array is empty', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => characterResponse(<dynamic>[]));

      expect(await api.getCharacters(400602), isEmpty);
    });
  });

  group('getMyCollections', () {
    test(
      'GETs with type/offset/limit query params when type is given',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async =>
              jsonResponse({'items': <Map<String, dynamic>>[], 'total': 0}),
        );

        await api.getMyCollections(
          type: CollectionType.doing,
          offset: 20,
          limit: 20,
        );

        verify(
          () => dio.get<Map<String, dynamic>>(
            '/v2/subjects/list',
            queryParameters: {'type': 'DOING', 'offset': 20, 'limit': 20},
          ),
        ).called(1);
      },
    );

    test('omits the type query param when type is null', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async =>
            jsonResponse({'items': <Map<String, dynamic>>[], 'total': 0}),
      );

      await api.getMyCollections(offset: 0, limit: 20);

      verify(
        () => dio.get<Map<String, dynamic>>(
          '/v2/subjects/list',
          queryParameters: {'offset': 0, 'limit': 20},
        ),
      ).called(1);
    });

    test('parses a paginated response', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'items': [
            {
              'subjectId': 1,
              'name': 'A',
              'nameCn': 'A-cn',
              'collectionType': 'DOING',
            },
          ],
          'total': 1,
        }),
      );

      final page = await api.getMyCollections(offset: 0, limit: 20);

      expect(page.items, hasLength(1));
      expect(page.total, 1);
      expect(page.items.single.nameCn, 'A-cn');
    });
  });

  group('getReviews', () {
    final reviewsJson = {
      'total': 2,
      'items': [
        {
          'id': 'bangumi:302286:1261526',
          'subjectId': 302286,
          'source': 'bangumi',
          'author': {'id': '1261526', 'nickname': 'Guating'},
          'contentBbcode': '对比老tv质的飞跃。',
          'updatedAt': '2026-09-11T13:56:03Z',
          'rating': 8,
          'likeCount': 0,
        },
      ],
    };

    test('GETs the reviews path with offset/limit query params', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => jsonResponse(reviewsJson));

      await api.getReviews(subjectId: 302286, offset: 40, limit: 5);

      verify(
        () => dio.get<Map<String, dynamic>>(
          '/v2/subjects/302286/reviews',
          // Deliberately distinct values: with offset == limit a
          // transposed `{'offset': limit, 'limit': offset}` implementation
          // would still satisfy this expectation.
          queryParameters: {'offset': 40, 'limit': 5},
        ),
      ).called(1);
    });

    test('parses the response into a PaginatedReviews', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => jsonResponse(reviewsJson));

      final page = await api.getReviews(
        subjectId: 302286,
        offset: 0,
        limit: 20,
      );

      expect(page.items, hasLength(1));
      expect(page.items.single.author.nickname, 'Guating');
      expect(page.items.single.rating, 8);
      // total=2 with 1 item is the backend's limit+1 has-more sentinel.
      expect(page.hasMore, isTrue);
    });
  });
}
