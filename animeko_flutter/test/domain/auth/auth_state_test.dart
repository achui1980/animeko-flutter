import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthState', () {
    test('AuthUnauthenticated is a const singleton-like value', () {
      expect(const AuthUnauthenticated(), isA<AuthState>());
    });

    test('AuthAwaitingBrowser carries the requestId', () {
      const state = AuthAwaitingBrowser('req-123');
      expect(state.requestId, 'req-123');
    });

    test('AuthPolling carries the requestId', () {
      const state = AuthPolling('req-123');
      expect(state.requestId, 'req-123');
    });

    test('AuthAuthenticated carries the userId', () {
      const state = AuthAuthenticated('user-42');
      expect(state.userId, 'user-42');
    });

    test('AuthError carries a message', () {
      const state = AuthError('network down');
      expect(state.message, 'network down');
    });

    test('switch exhaustiveness compiles for all variants', () {
      String describe(AuthState s) => switch (s) {
            AuthUnauthenticated() => 'unauthenticated',
            AuthAwaitingBrowser(requestId: final id) => 'awaiting:$id',
            AuthPolling(requestId: final id) => 'polling:$id',
            AuthAuthenticated(userId: final id) => 'authenticated:$id',
            AuthError(message: final m) => 'error:$m',
          };
      expect(describe(const AuthUnauthenticated()), 'unauthenticated');
    });
  });
}
