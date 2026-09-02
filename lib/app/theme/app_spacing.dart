import 'package:flutter/material.dart';

/// Responsive page-level horizontal/vertical padding, matching the
/// reference app's compact-vs-wide `WindowSizeClass` breakpoint (16dp
/// below 600px width, 24dp at/above it). See the design doc's "主题系统"
/// section.
double pagePadding(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width < 600 ? 16.0 : 24.0;
}
