import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The 3 `IconButton`s shared by Home/Search/Schedule's `AppBar.actions`:
/// account (new in Plan 1e), collection ("我的收藏"), and settings.
/// Wiring this into those screens (replacing their inlined, duplicated
/// `IconButton`s) is Phase C's job -- this task only adds the helper.
List<Widget> buildStandardActions(BuildContext context) {
  return [
    IconButton(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: '账户',
      onPressed: () => context.push('/account'),
    ),
    IconButton(
      icon: const Icon(Icons.bookmark),
      tooltip: '我的收藏',
      onPressed: () => context.push('/collection'),
    ),
    IconButton(
      icon: const Icon(Icons.settings),
      tooltip: '设置',
      onPressed: () => context.push('/settings'),
    ),
  ];
}
