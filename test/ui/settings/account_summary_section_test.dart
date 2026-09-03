import 'package:animeko_flutter/data/user/user_models.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/domain/user/self_user_controller.dart';
import 'package:animeko_flutter/ui/settings/account_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthController extends AuthController {
  bool signOutCalled = false;

  @override
  AuthState build() => const AuthAuthenticated('user-1');

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    state = const AuthUnauthenticated();
  }
}

const _user = SelfUser(
  id: 'u1',
  nickname: 'Alice',
  hasPassword: true,
  isBangumiSessionValid: true,
);

Widget _wrap(_FakeAuthController fakeAuth) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => fakeAuth),
      selfUserProvider.overrideWith((ref) async => _user),
    ],
    child: const MaterialApp(home: Scaffold(body: AccountSummarySection())),
  );
}

void main() {
  testWidgets('shows the nickname and signs out after confirming', (tester) async {
    final fakeAuth = _FakeAuthController();
    await tester.pumpWidget(_wrap(fakeAuth));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);

    await tester.tap(find.text('退出登录').first);
    await tester.pumpAndSettle();
    expect(find.text('确定要退出登录吗？'), findsOneWidget);

    await tester.tap(find.text('退出登录').last);
    await tester.pumpAndSettle();

    expect(fakeAuth.signOutCalled, isTrue);
  });

  testWidgets('cancelling the sign-out dialog does not sign out', (tester) async {
    final fakeAuth = _FakeAuthController();
    await tester.pumpWidget(_wrap(fakeAuth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('退出登录').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signOutCalled, isFalse);
  });
}
