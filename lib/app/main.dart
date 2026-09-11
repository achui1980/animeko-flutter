// lib/app/main.dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../data/settings/proxy_dio_config.dart';
import '../domain/auth/auth_controller.dart';
import '../domain/settings/dynamic_color_controller.dart';
import '../domain/settings/proxy_settings_controller.dart';
import '../domain/settings/seed_color_controller.dart';
import '../domain/settings/theme_mode_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Must run before any platform-channel plugin use (e.g. the
  // flutter_secure_storage read inside restoreSession() below), since
  // that call happens before runApp(), which is what normally performs
  // this initialization implicitly.
  WidgetsFlutterBinding.ensureInitialized();

  // Must run before any Player() is constructed (see
  // lib/ui/player/player_screen.dart) -- initializes media_kit's native
  // libmpv bindings for this platform.
  MediaKit.ensureInitialized();

  final container = ProviderContainer();

  // Must resolve before anything makes an HTTP request so that the very
  // first connection sees the persisted proxy setting instead of
  // AsyncLoading's null. Without this, that first connection gets decided as
  // DIRECT while the setting is still loading from disk, and dart:io's
  // HttpClient keeps that decision for the lifetime of the (possibly
  // reused/keep-alive) connection -- surfacing as "the proxy I configured
  // doesn't seem to take effect until I clear and re-save it".
  await container.read(proxySettingsControllerProvider.future);

  // Routes *all* of this process's HTTP through the configured proxy, since
  // dart:io's `HttpClient()` constructor delegates to HttpOverrides.current:
  // every Dio, the un-intercepted rawAniDio() used for token refreshes, and
  // Flutter's shared image client behind Image.network/NetworkImage. Requests
  // to loopback (the rqbit sidecar and the local stream URLs it serves) stay
  // direct -- see decideProxy(). Installed before restoreSession() below
  // because that can hit the network to refresh the session.
  installProxyHttpOverrides(container);

  await container.read(authControllerProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AnimekoFlutterApp(),
    ),
  );
}

class AnimekoFlutterApp extends ConsumerWidget {
  const AnimekoFlutterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
    final useDynamicColor =
        ref.watch(dynamicColorControllerProvider).value ?? false;
    final seedColor =
        ref.watch(seedColorControllerProvider).value ?? kSeedColor;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Only actually switch to the platform's dynamic scheme when the
        // user has opted in AND the platform actually provided one (it's
        // null on unsupported platforms, or briefly while still loading --
        // see DynamicColorBuilder's own doc comment). Otherwise fall back
        // to the seed-color-derived theme, same as before this setting
        // existed.
        final light = useDynamicColor && lightDynamic != null
            ? AppTheme.fromDynamicColorScheme(lightDynamic)
            : AppTheme.light(seedColor: seedColor);
        final dark = useDynamicColor && darkDynamic != null
            ? AppTheme.fromDynamicColorScheme(darkDynamic)
            : AppTheme.dark(seedColor: seedColor);
        return MaterialApp.router(
          title: 'AniMeow',
          theme: light,
          darkTheme: dark,
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    );
  }
}
