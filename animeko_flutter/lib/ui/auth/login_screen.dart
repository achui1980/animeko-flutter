// lib/ui/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth/auth_controller.dart';
import '../../domain/auth/auth_state.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);

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
