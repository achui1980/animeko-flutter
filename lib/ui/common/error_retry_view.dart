// lib/ui/common/error_retry_view.dart
import 'package:flutter/material.dart';

/// Shared "failed to load, tap to retry" placeholder. Used by
/// `SubjectDetailScreen` and `PlayerScreen` for any error that is *not*
/// `Anime1NotFoundException` -- see the design doc's "错误处理" table.
/// `Anime1NotFoundException` gets its own non-retryable empty state
/// instead, rendered inline by the screen that catches it.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
