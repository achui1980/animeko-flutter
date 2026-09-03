import 'package:animeko_flutter/data/user/user_api.dart';
import 'package:animeko_flutter/data/user/user_models.dart';
import 'package:animeko_flutter/domain/user/self_user_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockUserApi extends Mock implements UserApi {}

const _user = SelfUser(
  id: 'u1',
  nickname: 'Alice',
  hasPassword: true,
  isBangumiSessionValid: true,
);

void main() {
  late MockUserApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockUserApi();
    container = ProviderContainer(overrides: [userApiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);
  });

  test('reads the self profile from UserApi', () async {
    when(() => api.getSelf()).thenAnswer((_) async => _user);

    final result = await container.read(selfUserProvider.future);

    expect(result.id, 'u1');
    expect(result.nickname, 'Alice');
  });
}
