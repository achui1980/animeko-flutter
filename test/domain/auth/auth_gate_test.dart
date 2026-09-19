// test/domain/auth/auth_gate_test.dart
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_gate.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

/// Builds a two-route app (`/` with a button that calls [requireLogin],
/// `/login` as the guarded destination) so tests can assert both the
/// return value and whether navigation happened.
Widget _wrap(AuthState initialState, {required ValueSetter<bool> onResult}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => _FakeAuthController(initialState),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => onResult(requireLogin(context, ref)),
                    child: const Text('Guarded action'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                const Scaffold(body: Text('Login screen')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'when unauthenticated, pushes /login and returns false',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(const AuthUnauthenticated(), onResult: (v) => result = v),
      );

      await tester.tap(find.text('Guarded action'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Login screen'), findsOneWidget);
    },
  );

  testWidgets(
    'when authenticated, does not navigate and returns true',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          const AuthAuthenticated('user-1'),
          onResult: (v) => result = v,
        ),
      );

      await tester.tap(find.text('Guarded action'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Login screen'), findsNothing);
      expect(find.text('Guarded action'), findsOneWidget);
    },
  );
}
