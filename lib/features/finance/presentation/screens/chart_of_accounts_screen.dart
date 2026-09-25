import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/chart_account.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_search_field.dart';
import 'package:nizan_crm/core/error/errors.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

Color _natureColor(String nature, CrmTheme crm) {
  switch (nature) {
    case 'asset':
      return const Color(0xFF0D9488);
    case 'liability':
      return const Color(0xFFB44A2C);
    case 'equity':
      return const Color(0xFF7C3AED);
    case 'income':
      return crm.success;
    case 'expense':
      return const Color(0xFFB45309);
    default:
      return crm.textSecondary;
  }
}

/// Finance → Chart of Accounts. The ledger hierarchy that every journal line
/// posts to. Seed the default chart, then add your own accounts.
class ChartOfAccountsScreen extends ConsumerStatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  ConsumerState<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends ConsumerState<ChartOfAccountsScreen> {
  bool _showArchived = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(chartAccountsProvider('all'));

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: async.maybeWhen(
        data: (accounts) => accounts.isEmpty
            ? null
            : FloatingActionButton.extended(
                backgroundColor: crm.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('New Account', style: TextStyle(color: Colors.white)),
                onPressed: () => _openForm(context, ref),
              ),
        orElse: () => null,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(chartAccountsProvider('all')),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            AppErrorView(error: e, onRetry: () => ref.invalidate(chartAccountsProvider('all'))),
          ]),
          data: (all) {
            if (all.isEmpty) return _emptySeed(context, ref, crm);
            final archivedCount = all.where((a) => a.status == 'archived').length;
            final q = _search.trim().toLowerCase();
            final accounts = all.where((a) {
              if (!_showArchived && a.status == 'archived') return false;
              if (q.isNotEmpty && !'${a.code} ${a.name} ${a.group}'.toLowerCase().contains(q)) return false;
              return true;
            }).toList();
            final byNature = <String, List<ChartAccount>>{};
            for (final a in accounts) {
              byNature.putIfAbsent(a.nature, () => []).add(a);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                ReportSearchField(
                  hint: 'Search code, name or group…',
                  onChanged: (v) => setState(() => _search = v),
                ),
                10.h,
                if (archivedCount > 0) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilterChip(
                      label: Text(_showArchived ? 'Showing archived' : 'Show archived ($archivedCount)'),
                      selected: _showArchived,
                      onSelected: (v) => setState(() => _showArchived = v),
                    ),
                  ),
                  10.h,
                ],
                for (final nature in kAccountNatures)
                  if ((byNature[nature] ?? const []).isNotEmpty) ...[
                    _natureHeader(crm, nature, byNature[nature]!.length),
                    8.h,
                    for (final a in byNature[nature]!)
                      _accountTile(context, ref, crm, a),
                    16.h,
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _natureHeader(CrmTheme crm, String nature, int n) {
    final color = _natureColor(nature, crm);
    return Row(children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      8.w,
      Text(natureLabel(nature).toUpperCase(),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
      8.w,
      Text('$n', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
    ]);
  }

  Widget _accountTile(BuildContext context, WidgetRef ref, CrmTheme crm, ChartAccount a) {
    final color = _natureColor(a.nature, crm);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border.faded(0.7)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(a.code,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
        12.w,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (a.status == 'archived') ...[6.w, _chip(crm, 'Archived', crm.textSecondary)],
              if (a.isBank) ...[6.w, _chip(crm, 'Bank', const Color(0xFF2563EB))],
              if (a.isCash) ...[6.w, _chip(crm, 'Cash', const Color(0xFF0D9488))],
              if (a.isParty) ...[6.w, _chip(crm, 'Party', const Color(0xFF7C3AED))],
              if (a.gstApplicable) ...[6.w, _chip(crm, 'GST', const Color(0xFF0D9488))],
            ]),
            if (a.group.isNotEmpty) ...[
              2.h,
              Text(a.group, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ],
          ]),
        ),
        if (a.openingBalance > 0) ...[
          8.w,
          Text('${_money(a.openingBalance)} ${a.openingType.toUpperCase()}',
              style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ],
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: crm.textSecondary),
          onSelected: (v) {
            if (v == 'edit') _openForm(context, ref, existing: a);
            if (v == 'archive') _setArchived(context, ref, a, true);
            if (v == 'restore') _setArchived(context, ref, a, false);
            if (v == 'delete') _delete(context, ref, a);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (a.status == 'archived')
              const PopupMenuItem(value: 'restore', child: Text('Restore'))
            else
              const PopupMenuItem(value: 'archive', child: Text('Archive')),
            if (!a.isSystem) const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ]),
    );
  }

  Widget _chip(CrmTheme crm, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _emptySeed(BuildContext context, WidgetRef ref, CrmTheme crm) {
    return ListView(children: [
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.account_tree_outlined, size: 60, color: crm.border),
              16.h,
              Text('No chart of accounts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              8.h,
              Text('Seed a standard chart (assets, liabilities, equity, income and your\nexpense heads) to start posting entries.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: crm.textSecondary)),
              20.h,
              ElevatedButton.icon(
                onPressed: () => _seed(context, ref),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Seed default chart'),
                style: ElevatedButton.styleFrom(backgroundColor: crm.primary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              ),
              12.h,
              TextButton(onPressed: () => _openForm(context, ref), child: const Text('or add one manually')),
            ]),
          ),
        ),
      ),
    ]);
  }

  Future<void> _seed(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await ref.read(accountingServiceProvider).seedAccounts();
      ref.refreshData.chartOfAccounts();
      messenger.showSnackBar(SnackBar(content: Text('Seeded $n accounts')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ChartAccount a) async {
    final crm = context.crmColors;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: crm.surface,
        title: const Text('Delete account?'),
        content: Text('Delete "${a.code} · ${a.name}"?', style: TextStyle(color: crm.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: crm.destructive))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(accountingServiceProvider).deleteAccount(a.id);
      ref.refreshData.chartOfAccounts();
      messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _setArchived(BuildContext context, WidgetRef ref, ChartAccount a, bool archived) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(accountingServiceProvider)
          .saveAccount({'status': archived ? 'archived' : 'active'}, id: a.id);
      ref.refreshData.chartOfAccounts();
      messenger.showSnackBar(SnackBar(content: Text(archived ? 'Account archived' : 'Account restored')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  void _openForm(BuildContext context, WidgetRef ref, {ChartAccount? existing}) {
    showDialog(context: context, builder: (_) => _AccountDialog(existing: existing));
  }
}

class _AccountDialog extends ConsumerStatefulWidget {
  const _AccountDialog({this.existing});
  final ChartAccount? existing;
  @override
  ConsumerState<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<_AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _group;
  late final TextEditingController _opening;
  late final TextEditingController _gstRate;
  late String _nature;
  String _openingType = 'dr';
  bool _gst = false;
  bool _isBank = false;
  bool _isCash = false;
  bool _isParty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _code = TextEditingController(text: a?.code ?? '');
    _name = TextEditingController(text: a?.name ?? '');
    _group = TextEditingController(text: a?.group ?? '');
    _opening = TextEditingController(text: a != null && a.openingBalance > 0 ? a.openingBalance.toStringAsFixed(0) : '');
    _gstRate = TextEditingController(
        text: a != null && a.gstRate > 0
            ? (a.gstRate == a.gstRate.roundToDouble() ? a.gstRate.toStringAsFixed(0) : a.gstRate.toString())
            : '');
    _nature = a?.nature ?? 'expense';
    _openingType = a?.openingType ?? 'dr';
    _gst = a?.gstApplicable ?? false;
    _isBank = a?.isBank ?? false;
    _isCash = a?.isCash ?? false;
    _isParty = a?.isParty ?? false;
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _group, _opening, _gstRate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(accountingServiceProvider).saveAccount({
        'code': _code.text.trim(),
        'name': _name.text.trim(),
        'nature': _nature,
        'group': _group.text.trim(),
        'isBank': _isBank,
        'isCash': _isCash,
        'isParty': _isParty,
        'gstApplicable': _gst,
        'gstRate': _gst ? (double.tryParse(_gstRate.text.trim()) ?? 0) : 0,
        'openingBalance': double.tryParse(_opening.text.trim()) ?? 0,
        'openingType': _openingType,
      }, id: widget.existing?.id);
      ref.refreshData.chartOfAccounts();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Account saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final editing = widget.existing != null;
    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${editing ? 'Edit' : 'New'} account',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              16.h,
              Row(children: [
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _code,
                    enabled: !(editing && widget.existing!.isSystem),
                    decoration: const InputDecoration(labelText: 'Code *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                12.w,
                Expanded(
                  child: TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Account name *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ]),
              12.h,
              DropdownButtonFormField<String>(
                initialValue: _nature,
                decoration: const InputDecoration(labelText: 'Nature'),
                items: [for (final n in kAccountNatures) DropdownMenuItem(value: n, child: Text(natureLabel(n)))],
                onChanged: editing && widget.existing!.isSystem ? null : (v) => setState(() => _nature = v ?? _nature),
              ),
              12.h,
              TextFormField(controller: _group, decoration: const InputDecoration(labelText: 'Group', hintText: 'e.g. Current Assets')),
              12.h,
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _opening,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Opening balance (₹)'),
                  ),
                ),
                12.w,
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    initialValue: _openingType,
                    decoration: const InputDecoration(labelText: 'Dr/Cr'),
                    items: const [
                      DropdownMenuItem(value: 'dr', child: Text('Debit')),
                      DropdownMenuItem(value: 'cr', child: Text('Credit')),
                    ],
                    onChanged: (v) => setState(() => _openingType = v ?? 'dr'),
                  ),
                ),
              ]),
              12.h,
              Text('ROLE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
              6.h,
              Wrap(spacing: 8, children: [
                FilterChip(
                  label: const Text('Bank'),
                  selected: _isBank,
                  onSelected: (v) => setState(() {
                    _isBank = v;
                    if (v) _isCash = false;
                  }),
                ),
                FilterChip(
                  label: const Text('Cash'),
                  selected: _isCash,
                  onSelected: (v) => setState(() {
                    _isCash = v;
                    if (v) _isBank = false;
                  }),
                ),
                FilterChip(
                  label: const Text('Party (A/R–A/P)'),
                  selected: _isParty,
                  onSelected: (v) => setState(() => _isParty = v),
                ),
              ]),
              4.h,
              Text('Bank / Cash accounts show up in Bank Reconciliation.',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              6.h,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _gst,
                onChanged: (v) => setState(() => _gst = v),
                title: const Text('GST applicable', style: TextStyle(fontSize: 14)),
              ),
              if (_gst) ...[
                TextFormField(
                  controller: _gstRate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'GST rate (%)', isDense: true, suffixText: '%'),
                ),
              ],
              12.h,
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                8.w,
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
