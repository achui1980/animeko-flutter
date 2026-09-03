import 'package:animeko_flutter/data/user/user_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelfUser', () {
    test('fromJson parses all required and optional fields', () {
      final json = {
        'id': 'u1',
        'nickname': 'Alice',
        'hasPassword': true,
        'isBangumiSessionValid': true,
        'email': 'a@example.com',
        'smallAvatar': 'https://example.com/s.png',
        'mediumAvatar': 'https://example.com/m.png',
        'largeAvatar': 'https://example.com/l.png',
        'registerTime': 1700000000000,
        'lastLoginTime': 1700000001000,
        'clientVersion': '1.0.0',
        'bangumiUsername': 'alice_bgm',
      };

      final user = SelfUser.fromJson(json);

      expect(user.id, 'u1');
      expect(user.nickname, 'Alice');
      expect(user.hasPassword, true);
      expect(user.isBangumiSessionValid, true);
      expect(user.mediumAvatar, 'https://example.com/m.png');
      expect(user.bangumiUsername, 'alice_bgm');
    });

    test('fromJson tolerates missing optional fields', () {
      final json = {
        'id': 'u2',
        'nickname': 'Bob',
        'hasPassword': false,
        'isBangumiSessionValid': false,
      };

      final user = SelfUser.fromJson(json);

      expect(user.id, 'u2');
      expect(user.email, isNull);
      expect(user.mediumAvatar, isNull);
    });
  });
}
