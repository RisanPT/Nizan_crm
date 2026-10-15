import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr/travel/data/travel_models.dart';
import 'package:nizan_crm/features/hr/travel/service/travel_service.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]}';
}

Color _statusColor(String s, CrmTheme crm) {
  switch (s) {
    case 'approved':
      return crm.success;
    case 'rejected':
      return crm.destructive;
    case 'cancelled':
      return crm.textSecondary;
    default:
      return crm.warning;
  }
}

Widget _chip(String s, CrmTheme crm) =>
    hrStatusChip(s[0].toUpperCase() + s.substring(1), _statusColor(s, crm));

/// HR Travel — employees request trips (with optional advance) for approval; the
/// travel desk / HR reviews from Team Requests.
class HrTravelScreen extends ConsumerWidget {
  const HrTravelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    final hasEmployee = (session?.employeeId ?? '').isNotEmpty;
    final isManager = access.isFullAccess || access.isDepartmentHead || access.has('travel', false) || access.has('staff', false);

    final tabs = <Tab>[
      if (hasEmployee) const Tab(text: 'My Requests'),
      if (isManager) const Tab(text: 'Travel Desk'),
    ];
    final views = <Widget>[
      if (hasEmployee) _MineTab(crm: crm),
      if (isManager) _RequestsTab(crm: crm),
    ];
    if (tabs.isEmpty) {
      return Scaffold(backgroundColor: crm.background, body: Center(child: Text('No employee record is linked to your account.', style: TextStyle(color: crm.textSecondary))));
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            Material(
              color: crm.surface,
              child: TabBar(labelColor: crm.primary, unselectedLabelColor: crm.textSecondary, indicatorColor: crm.primary, tabs: tabs),
            ),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
    );
  }
}

class _MineTab extends ConsumerWidget {
  const _MineTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myTravelProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Trip'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTravelProvider),
        child: mine.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(myTravelProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No travel requests yet.', style: TextStyle(color: crm.textSecondary))))])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: list.map((t) => _row(context, ref, t, mine: true)).toList()),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, TravelRequest t, {required bool mine}) {
    final dates = (t.fromDate != null || t.toDate != null) ? '${_fmt(t.fromDate)} – ${_fmt(t.toDate)}' : '';
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
                Text('${mine ? '' : '${t.employeeName} · '}${t.destination}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text(
                  [
                    travelModeLabel(t.mode),
                    if (dates.isNotEmpty) dates,
                    if (t.estimatedCost > 0) '₹${t.estimatedCost.toStringAsFixed(0)}',
                    if (t.advanceRequested) 'advance ₹${t.advanceAmount.toStringAsFixed(0)}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                ),
              ],
            ),
          ),
          _chip(t.status, crm),
          if (mine && t.status == 'pending')
            IconButton(
              icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
              onPressed: () async {
                try {
                  await ref.read(travelServiceProvider).cancel(t.id);
                  ref.invalidate(myTravelProvider);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _TravelDialog());
    if (ok == true) {
      ref.invalidate(myTravelProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Travel request submitted')));
    }
  }
}

class _TravelDialog extends ConsumerStatefulWidget {
  const _TravelDialog();
  @override
  ConsumerState<_TravelDialog> createState() => _TravelDialogState();
}

class _TravelDialogState extends ConsumerState<_TravelDialog> {
  final _dest = TextEditingController();
  final _purpose = TextEditingController();
  final _cost = TextEditingController();
  final _advance = TextEditingController();
  String _mode = 'flight';
  DateTime? _from;
  DateTime? _to;
  bool _advanceRequested = false;
  bool _busy = false;

  @override
  void dispose() {
    _dest.dispose();
    _purpose.dispose();
    _cost.dispose();
    _advance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_dest.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination is required')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(travelServiceProvider).apply(
            destination: _dest.text.trim(),
            purpose: _purpose.text.trim(),
            mode: _mode,
            fromDate: _from,
            toDate: _to,
            estimatedCost: double.tryParse(_cost.text.trim()) ?? 0,
            advanceRequested: _advanceRequested,
            advanceAmount: double.tryParse(_advance.text.trim()) ?? 0,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New travel request'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _dest, decoration: const InputDecoration(labelText: 'Destination')),
              const SizedBox(height: 10),
              TextField(controller: _purpose, decoration: const InputDecoration(labelText: 'Purpose')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: kTravelModes.map((m) => DropdownMenuItem(value: m, child: Text(travelModeLabel(m)))).toList(),
                onChanged: (v) => setState(() => _mode = v ?? 'flight'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(context: context, initialDate: _from ?? now, firstDate: now, lastDate: DateTime(now.year + 2));
                      if (d != null) setState(() => _from = d);
                    },
                    child: Text(_from == null ? 'From' : 'From ${_fmt(_from)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final base = _from ?? DateTime.now();
                      final d = await showDatePicker(context: context, initialDate: _to ?? base, firstDate: base, lastDate: DateTime(base.year + 2));
                      if (d != null) setState(() => _to = d);
                    },
                    child: Text(_to == null ? 'To' : 'To ${_fmt(_to)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Estimated cost (₹)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _advanceRequested,
                title: const Text('Request advance'),
                onChanged: (v) => setState(() => _advanceRequested = v),
              ),
              if (_advanceRequested)
                TextField(
                  controller: _advance,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Advance amount (₹)'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),
        ),
      ],
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(travelRequestsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(travelRequestsProvider),
      child: reqs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(travelRequestsProvider))]),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Travel desk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            Text('Approve or decline from the Approvals inbox', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No travel requests.', style: TextStyle(color: crm.textSecondary))))
            else
              ...list.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: hrCardDecoration(crm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t.employeeName} · ${t.destination}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                              Text('${travelModeLabel(t.mode)} · ${_fmt(t.fromDate)}–${_fmt(t.toDate)}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                            ],
                          ),
                        ),
                        _chip(t.status, crm),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
