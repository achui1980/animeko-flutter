// lib/platform/browser_launcher.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

part 'browser_launcher.g.dart';

typedef LaunchUrlFn = Future<bool> Function(Uri uri);

/// Opens a URL in the system's default browser. The Bangumi OAuth consent
/// page is opened this way — see design doc section 6. Phase 1a targets
/// macOS only; other platforms will get their own `BrowserLauncher`
/// instance wired the same way in later phases (url_launcher itself is
/// already cross-platform).
class BrowserLauncher {
  BrowserLauncher({LaunchUrlFn? launch})
    : _launch =
          launch ??
          ((uri) => url_launcher.launchUrl(
            uri,
            mode: url_launcher.LaunchMode.externalApplication,
          ));

  final LaunchUrlFn _launch;

  Future<bool> open(String url) => _launch(Uri.parse(url));
}

@riverpod
BrowserLauncher browserLauncher(Ref ref) => BrowserLauncher();
