// test/ui/auth/login_screen_test.dart
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/ui/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);
  final AuthState _initial;
  bool loginCalled = false;

  @override
  AuthState build() => _initial;

  @override
  Future<void> login({required bool isRegister}) async {
    loginCalled = true;
  }
}

Widget wrap(
  AuthState initialState, {
  void Function(_FakeAuthController)? capture,
}) {
  final fake = _FakeAuthController(initialState);
  capture?.call(fake);
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('shows a login button when unauthenticated', (tester) async {
    await tester.pumpWidget(wrap(const AuthUnauthenticated()));

    expect(find.text('Log in with Bangumi'), findsOneWidget);
  });

  testWidgets('tapping the login button calls controller.login', (
    tester,
  ) async {
    _FakeAuthController? controller;
    await tester.pumpWidget(
      wrap(const AuthUnauthenticated(), capture: (c) => controller = c),
    );

    await tester.tap(find.text('Log in with Bangumi'));
    await tester.pump();

    expect(controller!.loginCalled, isTrue);
  });

  testWidgets('shows a progress indicator while awaiting browser', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AuthAwaitingBrowser('req-1')));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a progress indicator while polling', (tester) async {
    await tester.pumpWidget(wrap(const AuthPolling('req-1')));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the user id when authenticated', (tester) async {
    await tester.pumpWidget(wrap(const AuthAuthenticated('user-42')));

    expect(find.textContaining('user-42'), findsOneWidget);
  });

  testWidgets('shows the error message on error', (tester) async {
    await tester.pumpWidget(
      wrap(const AuthError(UnknownAppError('network down'))),
    );

    expect(find.textContaining('network down'), findsOneWidget);
  });

  testWidgets('pops back to the screen that pushed /login on success', (
    tester,
  ) async {
    final fake = _FakeAuthController(const AuthUnauthenticated());
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Open login'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => fake)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Open login'));
    await tester.pumpAndSettle();
    expect(find.text('Log in with Bangumi'), findsOneWidget);

    fake.state = const AuthAuthenticated('user-1');
    await tester.pumpAndSettle();

    // Back on the screen that pushed /login, not hard-navigated to a
    // fixed route -- per design, a completed login does not retry
    // whatever action the user originally tapped.
    expect(find.text('Open login'), findsOneWidget);
    expect(find.text('Log in with Bangumi'), findsNothing);
  });

  testWidgets(
    'falls back to /home when there is nothing to pop back to (e.g. a '
    'direct deep link to /login)',
    (tester) async {
      final fake = _FakeAuthController(const AuthUnauthenticated());
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => fake)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      fake.state = const AuthAuthenticated('user-1');
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    },
  );
}
