import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr_shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr_ess/service/ess_service.dart';

/// HR Employee Logins — provision self-service (ESS) accounts. Each invite
/// creates (or refreshes) a login and emails a one-time set-password link; no
/// admin ever sets or sees the employee's password.
class HrLoginsScreen extends ConsumerStatefulWidget {
  const HrLoginsScreen({super.key});
  @override
  ConsumerState<HrLoginsScreen> createState() => _HrLoginsScreenState();
}

class _HrLoginsScreenState extends ConsumerState<HrLoginsScreen> {
  final _busy = <String>{};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final employees = ref.watch(employeesProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(
        children: [
          Container(
            color: crm.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search employee by name or email',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Invite employees to self-service. An email with a set-password link is sent to each.',
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _inviteAll,
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text('Invite all'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: employees.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(employeesProvider)),
              data: (list) {
                final active = list.where((e) => e.status == 'active').toList();
                final filtered = _search.isEmpty
                    ? active
                    : active
                        .where((e) =>
                            e.name.toLowerCase().contains(_search) ||
                            e.email.toLowerCase().contains(_search))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(child: Text('No employees found.', style: TextStyle(color: crm.textSecondary)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _row(crm, filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(CrmTheme crm, Employee e) {
    final busy = _busy.contains(e.id);
    final hasEmail = e.email.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text(hasEmail ? e.email : 'No email on file',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: hasEmail ? crm.textSecondary : crm.destructive)),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            FilledButton.tonalIcon(
              onPressed: hasEmail ? () => _invite(e) : null,
              icon: const Icon(Icons.mail_outline, size: 16),
              label: const Text('Invite'),
            ),
        ],
      ),
    );
  }

  Future<void> _invite(Employee e) async {
    setState(() => _busy.add(e.id));
    try {
      final res = await ref.read(essServiceProvider).provision(e.id);
      if (!mounted) return;
      if (res.emailSent) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invite sent to ${e.email}')));
      } else if (res.setupLink != null && res.setupLink!.isNotEmpty) {
        _showLinkDialog(e, res.setupLink!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(err))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(e.id));
    }
  }

  // When mail isn't configured the backend hands back the set-password link so
  // HR can share it directly.
  void _showLinkDialog(Employee e, String link) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set-password link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email delivery is not configured, so share this link with ${e.name}:'),
            const SizedBox(height: 10),
            SelectableText(link, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
            },
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _inviteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite all employees'),
        content: const Text(
            'Create logins for every active employee who has an email and no account yet, '
            'and email each a set-password link. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Invite all')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await ref.read(essServiceProvider).provisionAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Created ${res.created}, emailed ${res.invited}, skipped ${res.skipped} of ${res.total}.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }
}
