import 'package:flutter/material.dart';

/// A centered loading spinner, replacing the `Center(child:
/// CircularProgressIndicator())` boilerplate duplicated across
/// Home/Search/Schedule/Collection/Player screens.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
