import 'package:flutter/material.dart';

import '../theme/crm_theme.dart';
import 'error_message.dart';

/// Show a humanised error to the user as a snackbar. Pass the raw error object
/// (a `DioException`, a caught `Exception`, anything) — it is turned into a
/// short, readable line; a raw dump can never reach the user.
///
/// ```dart
/// try { ... } catch (e) { if (context.mounted) showErrorSnackBar(context, e); }
/// ```
void showErrorSnackBar(BuildContext context, Object? error, {String? fallback}) {
  _show(
    context,
    message: friendlyErrorMessage(error, fallback: fallback),
    color: context.crmColors.destructive,
    icon: Icons.error_outline_rounded,
  );
}

/// A confirmation snackbar (green) for a successful action.
void showSuccessSnackBar(BuildContext context, String message) {
  _show(
    context,
    message: message,
    color: context.crmColors.success,
    icon: Icons.check_circle_outline_rounded,
  );
}

/// A caution snackbar (amber) — partial success or a soft warning.
void showWarningSnackBar(BuildContext context, String message) {
  _show(
    context,
    message: message,
    color: context.crmColors.warning,
    icon: Icons.warning_amber_rounded,
  );
}

void _show(
  BuildContext context, {
  required String message,
  required Color color,
  required IconData icon,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
}
