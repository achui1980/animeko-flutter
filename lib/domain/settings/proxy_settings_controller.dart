// lib/domain/settings/proxy_settings_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/settings/settings_storage.dart';

part 'proxy_settings_controller.g.dart';

/// Validates a user-entered proxy URL. Returns `null` if [input] is valid,
/// or a user-facing error message otherwise.
///
/// v1 only supports `http://` proxies -- see the design doc's "范围" section
/// for why SOCKS5 is explicitly deferred. An empty/whitespace-only [input]
/// is treated as valid (it means "clear the proxy"); callers that need to
/// distinguish "empty" from "set" must check that themselves.
String? validateProxyUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (!trimmed.startsWith('http://')) {
    return '暂不支持该协议（当前仅支持 http://）';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty || !uri.hasPort) {
    return '地址格式不正确，请输入如 http://127.0.0.1:2222';
  }

  return null;
}

@riverpod
class ProxySettingsController extends _$ProxySettingsController {
  @override
  Future<String?> build() async {
    final storage = await ref.watch(settingsStorageProvider.future);
    return storage.getProxyUrl();
  }

  /// Validates and persists [url]. Throws [FormatException] with the
  /// validation message if [url] fails [validateProxyUrl] -- the settings
  /// screen should call [validateProxyUrl] itself first to show an inline
  /// error instead of relying on this throwing.
  Future<void> setProxy(String url) async {
    final error = validateProxyUrl(url);
    if (error != null) throw FormatException(error);

    final trimmed = url.trim();
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setProxyUrl(trimmed);
    state = AsyncData(trimmed);
  }

  /// Clears the proxy (reverts to a direct connection).
  Future<void> clearProxy() async {
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setProxyUrl(null);
    state = const AsyncData(null);
  }
}
