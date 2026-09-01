// lib/ui/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/settings/proxy_settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _initialized = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final input = _controller.text;
    final error = validateProxyUrl(input);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      await ref.read(proxySettingsControllerProvider.notifier).clearProxy();
    } else {
      await ref.read(proxySettingsControllerProvider.notifier).setProxy(trimmed);
    }
    setState(() => _errorText = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  Future<void> _clear() async {
    _controller.clear();
    await ref.read(proxySettingsControllerProvider.notifier).clearProxy();
    setState(() => _errorText = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除代理')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final proxy = ref.watch(proxySettingsControllerProvider);

    proxy.whenData((value) {
      if (!_initialized) {
        _initialized = true;
        _controller.text = value ?? '';
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: proxy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载设置失败：$error')),
        data: (value) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('代理地址（例如 http://127.0.0.1:2222，留空表示直连）'),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'http://127.0.0.1:2222',
                  errorText: _errorText,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(onPressed: _save, child: const Text('保存')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _clear, child: const Text('清除代理')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
