// test/data/auth/refresh_result_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/refresh_result.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final session = const StoredSession(
    userId: 'user-1',
    tokens: AniTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAtMillis: 1,
    ),
  );

  test('RefreshSuccess carries the new session', () {
    final result = RefreshSuccess(session);
    expect(result.session, session);
  });

  test('RefreshFailure carries the AppError', () {
    const error = NetworkError();
    final result = RefreshFailure(error);
    expect(result.error, error);
  });

  test('switch exhaustiveness compiles for both variants', () {
    String describe(RefreshResult r) => switch (r) {
      RefreshSuccess(session: final s) => 'success:${s.userId}',
      RefreshFailure(error: final e) => 'failure:${e.message}',
    };
    expect(describe(RefreshSuccess(session)), 'success:user-1');
    expect(
      describe(const RefreshFailure(NetworkError())),
      contains('failure:'),
    );
  });
}
