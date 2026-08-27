// lib/app/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

void main() {
  runApp(const ProviderScope(child: AnimekoFlutterApp()));
}

class AnimekoFlutterApp extends StatelessWidget {
  const AnimekoFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(title: 'Animeko', routerConfig: appRouter);
  }
}
