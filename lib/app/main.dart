// lib/app/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth/auth_controller.dart';
import 'router.dart';

Future<void> main() async {
  final container = ProviderContainer();
  await container.read(authControllerProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AnimekoFlutterApp(),
    ),
  );
}

class AnimekoFlutterApp extends StatelessWidget {
  const AnimekoFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(title: 'Animeko', routerConfig: appRouter);
  }
}
