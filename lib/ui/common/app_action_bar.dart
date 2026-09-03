import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The shared "我的收藏" (collection) icon button used by Home/Search/
/// Schedule's `AppBar.actions`. Account and Settings previously also
/// lived here, but account info is now embedded inline at the top of
/// the Settings page (see `AccountSummarySection`), and Settings itself
/// is a bottom-nav tab rather than something reached from an AppBar
/// icon (see the Settings/bottom-nav redesign design doc).
List<Widget> buildStandardActions(BuildContext context) {
  return [
    IconButton(
      icon: const Icon(Icons.bookmark),
      tooltip: '我的收藏',
      onPressed: () => context.push('/collection'),
    ),
  ];
}
