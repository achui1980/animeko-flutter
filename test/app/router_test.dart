// test/app/router_test.dart
import 'package:animeko_flutter/app/router.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal fake that lets the test drive [AuthController]'s state
/// directly, mirroring the `_FakeAuthController` pattern already used in
/// Plan 1a's `login_screen_test.dart`.
class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

void main() {
  testWidgets('unauthenticated user sees the login screen, authenticated user sees Home', (
    tester,
  ) async {
    final fake = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(appRouterProvider)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in with Bangumi'), findsOneWidget);

    fake.state = const AuthAuthenticated('user-1');
    // Not pumpAndSettle(): HomeScreen's homeControllerProvider makes a real
    // (un-mocked) network call and stays in AsyncLoading, whose
    // CircularProgressIndicator animates indefinitely -- pumpAndSettle()
    // never sees "no more frames scheduled" and times out. A couple of
    // bounded pumps is enough for the refreshListenable-triggered redirect
    // and the route transition to complete.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Animeko'), findsOneWidget);
    expect(find.text('Log in with Bangumi'), findsNothing);
  });
}
