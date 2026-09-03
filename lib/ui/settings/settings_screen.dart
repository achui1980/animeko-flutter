// lib/ui/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/auth/auth_controller.dart';
import '../../domain/auth/auth_state.dart';
import '../../domain/settings/proxy_settings_controller.dart';
import '../../domain/settings/theme_mode_controller.dart';

/// Grouped-list settings page (Plan 1e phase B), aligned with the
/// reference Animeko app's grouped-settings layout. Unlike the
/// reference app's fully transparent `SettingsScope` container, this
/// keeps Flutter's default M3 `Card` per group -- it already gives the
/// same grouping affordance without a custom container widget.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final proxy = ref.watch(proxySettingsControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final isAuthenticated = authState is AuthAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsGroup(
            title: '通用',
            children: [
              themeMode.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => ListTile(title: Text('加载主题设置失败：$error')),
                data: (mode) => RadioGroup<ThemeMode>(
                  groupValue: mode,
                  onChanged: (value) => _setThemeMode(ref, value),
                  child: const Column(
                    children: [
                      RadioListTile<ThemeMode>(title: Text('跟随系统'), value: ThemeMode.system),
                      RadioListTile<ThemeMode>(title: Text('浅色'), value: ThemeMode.light),
                      RadioListTile<ThemeMode>(title: Text('深色'), value: ThemeMode.dark),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: '网络',
            children: [
              ListTile(
                title: const Text('代理设置'),
                subtitle: Text(proxy.value ?? '未设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/proxy'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: '账户',
            children: [
              ListTile(
                title: const Text('账户设置'),
                subtitle: Text(isAuthenticated ? '已登录' : '未登录'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/account'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setThemeMode(WidgetRef ref, ThemeMode? mode) {
    if (mode == null) return;
    ref.read(themeModeControllerProvider.notifier).setThemeMode(mode);
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
