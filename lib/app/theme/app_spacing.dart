import 'package:flutter/material.dart';

/// Responsive page-level horizontal/vertical padding, matching the
/// reference app's compact-vs-wide `WindowSizeClass` breakpoint (16dp
/// below 600px width, 24dp at/above it). See the design doc's "主题系统"
/// section.
double pagePadding(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width < 600 ? 16.0 : 24.0;
}

/// Width at/above which the subject detail page uses its three-column
/// desktop layout; below it the same sections stack into one column.
///
/// At the breakpoint itself the middle column is `1000 - 2*24 (page
/// padding) - 200 (left) - 300 (right) - 2*24 (gaps) = 404dp`, which fits
/// three 96dp episode buttons (`3*96 + 2*8 = 304`). A fourth needs
/// `4*96 + 3*8 = 408dp`, i.e. a window of 1004dp or wider -- so the
/// bottom 4dp of the wide layout renders a three-wide episode grid.
/// Accepted rather than moving the breakpoint to 1004: the design doc
/// lists these widths under 「已知的估算项」, and a round 1000 is easier to
/// reason about than a number derived from one grid's button size.
///
/// Deliberately unrelated to [pagePadding]'s 600dp compact/wide
/// breakpoint -- that one mirrors the reference app's `WindowSizeClass`,
/// this one is driven by the detail page's own content widths.
const double subjectDetailThreeColumnBreakpoint = 1000;
