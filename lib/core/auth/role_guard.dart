import 'package:flutter/material.dart';

/// Conditionally renders [child] only when [allowed] is true.
/// Renders [fallback] (or nothing) otherwise.
class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowed,
    required this.child,
    this.fallback,
  });

  final bool allowed;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
