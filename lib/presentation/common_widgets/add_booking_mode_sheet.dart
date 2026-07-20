import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';

/// Shows the "Single vs Multiple booking" chooser, then opens the add-booking
/// screen with the chosen mode.
///
/// * **Single booking** — one package (may still span multiple days). One
///   invoice.
/// * **Multiple booking** — several packages and/or days saved as ONE invoice;
///   each package/day appears as its own calendar entry.
///
/// The chosen mode is passed to the add screen via the `?mode=` query param.
Future<void> showAddBookingModeChooser(BuildContext context) async {
  final mode = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final crm = ctx.crmColors;

      Widget option({
        required String value,
        required IconData icon,
        required String title,
        required String subtitle,
      }) {
        return InkWell(
          onTap: () => Navigator.of(ctx).pop(value),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: crm.border),
              borderRadius: BorderRadius.circular(14),
              color: crm.surface,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: crm.primary.withValues(alpha: 0.12),
                  child: Icon(icon, color: crm.primary),
                ),
                14.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15.5)),
                      3.h,
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: crm.textSecondary)),
                    ],
                  ),
                ),
                8.w,
                Icon(Icons.chevron_right, color: crm.textSecondary),
              ],
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New booking',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: crm.textPrimary)),
              4.h,
              Text('How is this client booking?',
                  style: TextStyle(fontSize: 13, color: crm.textSecondary)),
              18.h,
              option(
                value: 'single',
                icon: Icons.event_available_outlined,
                title: 'Single booking',
                subtitle:
                    'One package for this client. Can still span multiple '
                    'days — always one invoice.',
              ),
              12.h,
              option(
                value: 'multiple',
                icon: Icons.dashboard_customize_outlined,
                title: 'Multiple booking',
                subtitle:
                    'Several packages and/or days as ONE invoice. Each '
                    'package/day appears as its own calendar entry.',
              ),
            ],
          ),
        ),
      );
    },
  );

  if (mode == null || !context.mounted) return;
  context.push('/booking/add?mode=$mode');
}
