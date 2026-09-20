// lib/ui/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/auth/auth_controller.dart';
import '../../domain/auth/auth_state.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (next is! AuthAuthenticated) return;
      // Login is triggered on-demand from whatever screen the user was on
      // (see `requireLogin()`), so return them there via `pop()` rather
      // than hard-navigating to a fixed route. Fall back to `/home` if
      // there is nothing to pop back to (e.g. a direct deep link to
      // `/login`).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      });
    });

    return Scaffold(
      body: Center(
        child: switch (state) {
          AuthUnauthenticated() => ElevatedButton(
            onPressed: () => ref
                .read(authControllerProvider.notifier)
                .login(isRegister: true),
            child: const Text('Log in with Bangumi'),
          ),
          AuthAwaitingBrowser() || AuthPolling() => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Waiting for Bangumi authorization...'),
            ],
          ),
          AuthAuthenticated(userId: final id) => Text('Logged in as $id'),
          AuthError(message: final msg) => Text('Login failed: $msg'),
        },
      ),
    );
  }
}
