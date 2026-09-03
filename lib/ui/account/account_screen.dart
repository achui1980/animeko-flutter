// lib/ui/account/account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth/auth_controller.dart';
import '../../domain/user/self_user_controller.dart';
import '../common/error_retry_view.dart';
import '../common/loading_view.dart';

/// New page (Plan 1e phase B) showing the current user's own profile
/// with a sign-out entry. `AuthController.signOut()` already existed
/// (Plan 1a) but had no UI entry point until this page.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selfUser = ref.watch(selfUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('账户')),
      body: selfUser.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorRetryView(
          message: '加载账户信息失败：$error',
          onRetry: () => ref.invalidate(selfUserProvider),
        ),
        data: (user) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundImage: user.mediumAvatar != null
                    ? NetworkImage(user.mediumAvatar!)
                    : null,
                child: user.mediumAvatar == null
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.nickname,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text(
                '退出登录',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _confirmSignOut(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}
