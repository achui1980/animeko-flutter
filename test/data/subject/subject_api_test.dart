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
      'selfRating': {'score': 0, 'tags': <String>[], 'isPrivate': false, 'comment': null},
    };

    test('GETs the exact subject-detail path', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse(detailJson));

      await api.getSubject(400602);

      verify(() => dio.get<Map<String, dynamic>>('/v2/subjects/400602')).called(1);
    });

    test('parses the response into a SubjectDetail', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse(detailJson));

      final detail = await api.getSubject(400602);

      expect(detail.id, 400602);
      expect(detail.nameCn, '葬送的芙莉莲');
      expect(detail.collectionType?.wireValue, 'DOING');
    });
  });

  group('updateCollection', () {
    test('PATCHes only collectionType when selfRating is omitted', () async {
      when(() => dio.patch<void>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 200));

      await api.updateCollection(400602, collectionType: CollectionType.doing);

      verify(() => dio.patch<void>(
            '/v2/subjects/400602',
            data: {'collectionType': 'DOING'},
          )).called(1);
    });

    test('PATCHes only selfRating when collectionType is omitted', () async {
      when(() => dio.patch<void>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 200));

      const rating = SelfRating(score: 8, tags: [], isPrivate: false, comment: '好看');

      await api.updateCollection(400602, selfRating: rating);

      verify(() => dio.patch<void>(
            '/v2/subjects/400602',
            data: {'selfRating': rating.toJson()},
          )).called(1);
    });

    test('PATCHes both fields together when both are given', () async {
      when(() => dio.patch<void>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 200));

      const rating = SelfRating(score: 9, tags: [], isPrivate: true, comment: null);

      await api.updateCollection(400602, collectionType: CollectionType.done, selfRating: rating);

      verify(() => dio.patch<void>(
            '/v2/subjects/400602',
            data: {'collectionType': 'DONE', 'selfRating': rating.toJson()},
          )).called(1);
    });
  });

  group('deleteCollection', () {
    test('DELETEs the exact subject path', () async {
      when(() => dio.delete<void>(any()))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 200));

      await api.deleteCollection(400602);

      verify(() => dio.delete<void>('/v2/subjects/400602')).called(1);
    });
  });

  group('getCharacters', () {
    test('GETs with withActors=true query param', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => jsonResponse({'items': <Map<String, dynamic>>[]}));

      await api.getCharacters(400602);

      verify(() => dio.get<Map<String, dynamic>>(
            '/v2/subjects/400602/characters',
            queryParameters: {'withActors': true},
          )).called(1);
    });

    test('parses a list of related characters', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => jsonResponse({
                'items': [
                  {'index': 0, 'character': {'name': '芙莉莲', 'imageUrl': 'https://example.com/f.jpg'}, 'role': 1},
                  {'index': 1, 'character': {'name': '费伦', 'imageUrl': null}, 'role': 2},
                ],
              }));

      final characters = await api.getCharacters(400602);

      expect(characters, hasLength(2));
      expect(characters.first.character.name, '芙莉莲');
      expect(characters.last.character.imageUrl, isNull);
    });

    test('returns an empty list when the response has no items', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => jsonResponse({'items': <Map<String, dynamic>>[]}));

      expect(await api.getCharacters(400602), isEmpty);
    });
  });

  group('getStaff', () {
    test('GETs the exact staff path', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse({'items': <Map<String, dynamic>>[]}));

      await api.getStaff(400602);

      verify(() => dio.get<Map<String, dynamic>>('/v2/subjects/400602/staff')).called(1);
    });

    test('parses a list of staff members', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse({
                'items': [
                  {'name': '渡边步', 'imageUrl': 'https://example.com/s.jpg', 'role': '导演'},
                ],
              }));

      final staff = await api.getStaff(400602);

      expect(staff, hasLength(1));
      expect(staff.single.name, '渡边步');
      expect(staff.single.role, '导演');
    });
  });
}
