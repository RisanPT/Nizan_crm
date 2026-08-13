import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';

/// Default page size for client-side pagination across finance lists.
const int kFinancePageSize = 50;

/// A "Show more" footer for a client-side paginated list. Renders nothing when
/// [remaining] <= 0.
class ShowMoreButton extends StatelessWidget {
  const ShowMoreButton({
    super.key,
    required this.remaining,
    required this.onPressed,
    this.pageSize = kFinancePageSize,
  });

  final int remaining;
  final int pageSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (remaining <= 0) return const SizedBox.shrink();
    final crm = context.crmColors;
    final next = remaining < pageSize ? remaining : pageSize;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.expand_more, size: 18),
          label: Text('Show $next more · $remaining left',
              style: TextStyle(color: crm.textPrimary)),
        ),
      ),
    );
  }
}
