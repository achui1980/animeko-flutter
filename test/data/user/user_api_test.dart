import 'package:animeko_flutter/data/user/user_api.dart';
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
  late UserApi api;

  setUp(() {
    dio = MockDio();
    api = UserApi(dio);
  });

  group('getSelf', () {
    final selfJson = {
      'id': 'u1',
      'nickname': 'Alice',
      'hasPassword': true,
      'isBangumiSessionValid': true,
      'mediumAvatar': 'https://example.com/m.png',
    };

    test('GETs /v1/me', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse(selfJson));

      await api.getSelf();

      verify(() => dio.get<Map<String, dynamic>>('/v1/me')).called(1);
    });

    test('parses the response into a SelfUser', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse(selfJson));

      final user = await api.getSelf();

      expect(user.id, 'u1');
      expect(user.nickname, 'Alice');
      expect(user.mediumAvatar, 'https://example.com/m.png');
    });
  });
}
