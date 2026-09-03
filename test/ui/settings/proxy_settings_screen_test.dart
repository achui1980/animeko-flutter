import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
import 'package:animeko_flutter/ui/settings/proxy_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProxySettingsController extends ProxySettingsController {
  _FakeProxySettingsController([this._value]);
  String? _value;

  @override
  Future<String?> build() async => _value;

  @override
  Future<void> setProxy(String url) async {
    _value = url.trim();
    state = AsyncData(_value);
  }

  @override
  Future<void> clearProxy() async {
    _value = null;
    state = const AsyncData(null);
  }
}

Widget _wrap(ProxySettingsController fake) {
  return ProviderScope(
    overrides: [proxySettingsControllerProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: ProxySettingsScreen()),
  );
}

void main() {
  testWidgets('shows the persisted proxy URL and saves a new one', (tester) async {
    final fake = _FakeProxySettingsController('http://127.0.0.1:2222');
    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    // Note: the field's hint text happens to equal this test's example
    // URL, so `find.text` would match both the EditableText and the
    // (hidden) hint Text widget. Assert on the controller's value
    // directly instead.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'http://127.0.0.1:2222');

    await tester.enterText(find.byType(TextField), 'http://10.0.0.1:8080');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('已保存'), findsOneWidget);
  });

  testWidgets('clears the proxy', (tester) async {
    final fake = _FakeProxySettingsController('http://127.0.0.1:2222');
    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('清除代理'));
    await tester.pumpAndSettle();

    expect(find.text('已清除代理'), findsOneWidget);
  });
}
