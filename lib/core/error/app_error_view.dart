import 'package:flutter/material.dart';

import '../theme/crm_theme.dart';
import 'error_message.dart';

/// A friendly, reusable error state for any failed load — drop it into an
/// `AsyncValue.when(error: ...)` branch, a `FutureBuilder`, or anywhere a
/// screen can't show its data. It humanises [error] (never a raw dump), picks a
/// matching icon, and offers a "Try again" button when [onRetry] is given.
///
/// ```dart
/// async.when(
///   loading: () => const Center(child: CircularProgressIndicator()),
///   error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(myProvider)),
///   data: (d) => ...,
/// )
/// ```
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
    this.title,
    this.retryLabel = 'Try again',
  });

  final Object? error;
  final VoidCallback? onRetry;

  /// Tighter spacing/sizing for inline use (cards, list slots).
  final bool compact;

  /// Overrides the auto-chosen heading.
  final String? title;
  final String retryLabel;

  IconData get _icon {
    switch (errorKind(error)) {
      case 0:
        return Icons.wifi_off_rounded; // offline / unreachable
      case 1:
        return Icons.search_off_rounded; // not found
      case 2:
        return Icons.lock_outline_rounded; // denied
      case 3:
        return Icons.cloud_off_rounded; // server problem
      default:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final message = friendlyErrorMessage(error);
    final heading = title ?? friendlyErrorTitle(error);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal: 28, vertical: compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: compact ? 38 : 54, color: crm.textSecondary),
            SizedBox(height: compact ? 10 : 16),
            Text(
              heading,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 15 : 17,
                fontWeight: FontWeight.w800,
                color: crm.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: crm.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: compact ? 14 : 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: crm.primary,
                  side: BorderSide(color: crm.primary.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
