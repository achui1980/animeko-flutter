import 'package:animeko_flutter/data/subject/subject_api.dart';
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
}
