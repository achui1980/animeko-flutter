// lib/ui/settings/settings_split_group.dart
import 'package:flutter/material.dart';

/// A Material 3 "split list" style settings group: a title above a set
/// of rows where the group's outer corners use a larger radius and the
/// inner row boundaries use a small radius, instead of a plain `Card`
/// with `Divider`s between rows.
///
/// Borrowed from Kazumi's `SettingsSplitGroup` (see the Kazumi
/// player/UI/settings/收藏页 comparison research) -- this is a drop-in
/// replacement for the plain-`Card` `_SettingsGroup` previously used on
/// [SettingsScreen].
class SettingsSplitGroup extends StatelessWidget {
  const SettingsSplitGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  static const double outerRadius = 24;
  static const double innerRadius = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        for (var i = 0; i < children.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: theme.colorScheme.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(i == 0 ? outerRadius : innerRadius),
                topRight: Radius.circular(i == 0 ? outerRadius : innerRadius),
                bottomLeft: Radius.circular(
                  i == children.length - 1 ? outerRadius : innerRadius,
                ),
                bottomRight: Radius.circular(
                  i == children.length - 1 ? outerRadius : innerRadius,
                ),
              ),
              child: children[i],
            ),
          ),
      ],
    );
  }
}
