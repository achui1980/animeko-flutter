// lib/ui/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/settings/dynamic_color_controller.dart';
import '../../domain/settings/proxy_settings_controller.dart';
import '../../domain/settings/seed_color_controller.dart';
import '../../domain/settings/theme_mode_controller.dart';
import 'account_summary_section.dart';

/// Grouped-list settings page. The account summary (avatar, nickname,
/// sign-out) lives at the top, followed by the 通用/网络 groups -- see
/// the Settings/bottom-nav redesign design doc for why account info
/// moved here instead of staying on a separate `/account` page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final proxy = ref.watch(proxySettingsControllerProvider);
    final useDynamicColor =
        ref.watch(dynamicColorControllerProvider).value ?? false;
    final seedColor = ref.watch(seedColorControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AccountSummarySection(),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: '通用',
            children: [
              themeMode.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) =>
                    ListTile(title: Text('加载主题设置失败：$error')),
                data: (mode) => RadioGroup<ThemeMode>(
                  groupValue: mode,
                  onChanged: (value) => _setThemeMode(ref, value),
                  child: const Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: Text('跟随系统'),
                        value: ThemeMode.system,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text('浅色'),
                        value: ThemeMode.light,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text('深色'),
                        value: ThemeMode.dark,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('跟随系统取色'),
                subtitle: const Text('Material You 动态配色（如平台支持）'),
                value: useDynamicColor,
                onChanged: (value) => ref
                    .read(dynamicColorControllerProvider.notifier)
                    .setUseDynamicColor(value),
              ),
              if (seedColor != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: IgnorePointer(
                    ignoring: useDynamicColor,
                    child: Opacity(
                      opacity: useDynamicColor ? 0.4 : 1.0,
                      child: Wrap(
                        spacing: 12,
                        children: seedColorPresets
                            .map(
                              (preset) => _SeedColorSwatch(
                                key: ValueKey(
                                  'seed_color_${preset.toARGB32()}',
                                ),
                                color: preset,
                                selected:
                                    preset.toARGB32() == seedColor.toARGB32(),
                                onTap: () => ref
                                    .read(seedColorControllerProvider.notifier)
                                    .setSeedColor(preset),
                              ),
                            )
                            .toList(),
                      ),
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

/// A single selectable circular swatch in the seed-color palette picker.
class _SeedColorSwatch extends StatelessWidget {
  const _SeedColorSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2,
                )
              : null,
        ),
        child: selected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}
