// test/app/router_test.dart
import 'package:animeko_flutter/app/router.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets(
    'play route without `extra` set renders a fallback instead of crashing',
    (tester) async {
      final fake = _FakeAuthController();
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      GoRouter? router;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(appRouterProvider);
              return MaterialApp.router(routerConfig: router!);
            },
          ),
        ),
      );
      await tester.pump();

      fake.state = const AuthAuthenticated('user-1');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Navigate straight to the play route by URL, without ever pushing
      // through `SubjectDetailScreen` -- so `state.extra` is null, as it
      // would be after e.g. app restoration or a future deep link.
      router!.go('/subject/1/play');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Invalid navigation'), findsOneWidget);
      // No exception should have been thrown by the unguarded cast.
      expect(tester.takeException(), isNull);
    },
  );
}
