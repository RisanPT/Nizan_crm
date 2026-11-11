import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/fleet/data/driver_login.dart';
import 'package:nizan_crm/services/user_service.dart';

final _long = DateFormat('d MMM yyyy');

/// Colour of a driver's login on the card: green while it works, amber when it ends within
/// two days, red once it has ended or been switched off.
Color loginColor(CrmTheme crm, DriverLogin l) => switch (l.kind) {
      DriverLoginKind.none => crm.textSecondary,
      DriverLoginKind.permanent => crm.success,
      DriverLoginKind.temporary => l.endsSoon ? crm.warning : crm.success,
      DriverLoginKind.ended || DriverLoginKind.off => crm.destructive,
    };

/// Choose the last day of a temporary login: quick choices counted from today, or any date
/// up to 180 days ahead.
class LoginEndPicker extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const LoginEndPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    bool isPreset(int days) => loginEndAfter(days, from: today) == DateTime(value.year, value.month, value.day);
    final custom = !loginDurationPresets.any((p) => isPreset(p.days));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Valid until the end of', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (final p in loginDurationPresets)
          ChoiceChip(
            label: Text(p.label),
            selected: isPreset(p.days),
            onSelected: (_) => onChanged(loginEndAfter(p.days, from: today)),
          ),
        ChoiceChip(
          avatar: const Icon(Icons.event_rounded, size: 16),
          label: Text(custom ? _long.format(value) : 'Pick a date'),
          selected: custom,
          onSelected: (_) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value.isBefore(day) ? day : value,
              firstDate: day,
              lastDate: day.add(const Duration(days: 180)),
              helpText: 'Last day the login works',
            );
            if (picked != null) onChanged(DateTime(picked.year, picked.month, picked.day));
          },
        ),
      ]),
    ]);
  }
}

/// Change when a driver's login ends (or make it permanent) — also brings an ended or switched-off
/// login back to life. The password is not touched.
Future<void> showRenewLoginDialog(
  BuildContext context,
  WidgetRef ref,
  Employee employee,
  DriverLogin login,
) async {
  final messenger = ScaffoldMessenger.of(context);
  var permanent = false;
  var until = login.kind == DriverLoginKind.temporary && login.until != null ? login.until! : loginEndAfter(7);
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Login for ${employee.name}'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(login.label, style: TextStyle(fontSize: 13, color: context.crmColors.textSecondary)),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: permanent,
              onChanged: saving ? null : (v) => setState(() => permanent = v),
              title: const Text('No end date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Works until you switch it off', style: TextStyle(fontSize: 11.5)),
            ),
            if (!permanent) LoginEndPicker(value: until, onChanged: (d) => setState(() => until = d)),
          ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      await ref.read(userServiceProvider).setDriverLoginAccess(
                            employeeId: employee.id,
                            permanent: permanent,
                            expiresOn: permanent ? null : loginDayParam(until),
                            active: true,
                          );
                      ref.refreshData.crmUsers();
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      messenger.showSnackBar(SnackBar(
                        content: Text(permanent
                            ? '${employee.name}\'s login has no end date now.'
                            : '${employee.name}\'s login works until ${_long.format(until)}.'),
                      ));
                    } catch (e) {
                      setState(() => saving = false);
                      if (dialogContext.mounted) showErrorSnackBar(dialogContext, e);
                    }
                  },
            child: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Switch a driver's login off at once (after asking). The profile stays.
Future<void> endLoginNow(BuildContext context, WidgetRef ref, Employee employee) async {
  final messenger = ScaffoldMessenger.of(context);
  final crm = context.crmColors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('End login now?'),
      content: Text('${employee.name} will be signed out and cannot sign in again until you renew the login.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: crm.destructive),
          child: const Text('End login'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(userServiceProvider).setDriverLoginAccess(employeeId: employee.id, active: false);
    ref.refreshData.crmUsers();
    messenger.showSnackBar(SnackBar(content: Text('${employee.name}\'s login has been ended.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
  }
}
