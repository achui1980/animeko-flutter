// test/ui/auth/login_screen_test.dart
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/ui/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pumpWidget(wrap(const AuthError(UnknownAppError('network down'))));

    expect(find.textContaining('network down'), findsOneWidget);
  });
}
