// lib/ui/common/login_prompt_view.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared "log in to see this" placeholder for screens/sections that are
/// reachable as a guest but need a Bangumi session to show real content
/// (e.g. "我的收藏", the settings account header). Styled like
/// [EmptyView]/[ErrorRetryView] -- icon + message + action button.
class LoginPromptView extends StatelessWidget {
  const LoginPromptView({
    super.key,
    this.message = '登录后即可查看',
    this.icon = Icons.lock_outline,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }
}
