import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';

/// A tappable, Zoho-style column header with a sort indicator (↕ idle, ↑/↓ when
/// this column is the active sort). Tapping cycles the sort via [onTap].
class SortHeader extends StatelessWidget {
  const SortHeader({
    super.key,
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: active ? crm.primary : crm.textSecondary,
    );
    final icon = Icon(
      active ? (ascending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
      size: 11,
      color: active ? crm.primary : crm.textSecondary.withValues(alpha: 0.55),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: alignEnd
            ? [icon, const SizedBox(width: 2), Flexible(child: Text(label, style: style, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis))]
            : [Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis)), const SizedBox(width: 2), icon],
      ),
    );
  }
}
