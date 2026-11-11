import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';

/// Add / rename / re-group / archive / delete the EXPENSE HEADS — the choices under "Expense Head" on
/// the expense form. Each head is an expense ledger in the books, so a new one is ready to post to at
/// once. Renaming is always safe (everything refers to the code); a head that has been used is
/// archived, not deleted, and the built-in ones can only be archived.
///
/// For Accounts / admin (the backend refuses anyone else).
class ManageExpenseHeadsDialog extends ConsumerStatefulWidget {
  const ManageExpenseHeadsDialog({super.key});

  @override
  ConsumerState<ManageExpenseHeadsDialog> createState() => _ManageExpenseHeadsDialogState();
}

class _ManageExpenseHeadsDialogState extends ConsumerState<ManageExpenseHeadsDialog> {
  final _searchCtrl = TextEditingController();
  bool _showArchived = false;
  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.refreshData.expenseHeads();
      if (done != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm(List<ExpenseHead> heads, {ExpenseHead? head}) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _HeadForm(head: head, groups: {for (final h in heads) if (h.group.isNotEmpty) h.group}.toList()..sort()),
    );
    if (saved == null) return;
    ref.refreshData.expenseHeads();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved)));
  }

  Future<void> _archive(ExpenseHead h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive this head?'),
        content: Text(
          '"${h.label}" will no longer be offered under Expense Head. Expenses already filed under it keep it, '
          'and you can restore it any time.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(key: const Key('head_archive_confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Archive')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(adminExpenseServiceProvider).updateExpenseHead(h.id, active: false);
    }, done: '"${h.label}" archived');
  }

  Future<void> _restore(ExpenseHead h) => _run(() async {
        await ref.read(adminExpenseServiceProvider).updateExpenseHead(h.id, active: true);
      }, done: '"${h.label}" restored');

  Future<void> _delete(ExpenseHead h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this head?'),
        content: Text('"${h.label}" (${h.code}) and its ledger will be removed for good. Nothing uses it, so no expense is affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('head_delete_confirm'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(adminExpenseServiceProvider).deleteExpenseHead(h.id);
    }, done: '"${h.label}" deleted');
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final headsAsync = ref.watch(allExpenseHeadsProvider);
    final all = headsAsync.value ?? const <ExpenseHead>[];
    final archivedCount = all.where((h) => !h.active).length;
    final q = _searchCtrl.text.trim().toLowerCase();
    final shown = all
        .where((h) => (_showArchived || h.active) && (q.isEmpty || '${h.code} ${h.label} ${h.group}'.toLowerCase().contains(q)))
        .toList();
    final byGroup = <String, List<ExpenseHead>>{};
    for (final h in shown) {
      byGroup.putIfAbsent(h.group.isEmpty ? 'Other' : h.group, () => []).add(h);
    }
    final groups = byGroup.keys.toList()..sort();

    return Dialog(
      backgroundColor: crm.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Manage Expense Heads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                  ),
                  IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'These are the choices under Expense Head when an expense is recorded. Each one is also a ledger in the books. '
                  'Rename or re-group freely; a head that has been used can be archived but not deleted.',
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.35),
                ),
              ),
              12.h,
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('head_search'),
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText: 'Search heads',
                        ),
                      ),
                    ),
                    8.w,
                    FilledButton.icon(
                      key: const Key('head_add'),
                      onPressed: _busy || headsAsync.isLoading ? null : () => _openForm(all),
                      style: FilledButton.styleFrom(backgroundColor: crm.primary),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add head'),
                    ),
                  ],
                ),
              ),
              if (archivedCount > 0) ...[
                8.h,
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    key: const Key('head_show_archived'),
                    label: Text('Show archived ($archivedCount)'),
                    selected: _showArchived,
                    onSelected: (v) => setState(() => _showArchived = v),
                  ),
                ),
              ],
              8.h,
              Divider(color: crm.border, height: 1),
              Flexible(
                child: headsAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(allExpenseHeadsProvider)),
                  data: (_) {
                    if (shown.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(child: Text(q.isEmpty ? 'No expense heads yet — add one above.' : 'No head matches "$q".', style: TextStyle(color: crm.textSecondary))),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(right: 8),
                      children: [
                        for (final g in groups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 14, 0, 2),
                            child: Text(g.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
                          ),
                          for (final h in byGroup[g]!)
                            _HeadTile(
                              head: h,
                              busy: _busy,
                              onEdit: () => _openForm(all, head: h),
                              onArchive: () => _archive(h),
                              onRestore: () => _restore(h),
                              onDelete: () => _delete(h),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadTile extends StatelessWidget {
  final ExpenseHead head;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _HeadTile({required this.head, required this.busy, required this.onEdit, required this.onArchive, required this.onRestore, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final h = head;
    final dim = !h.active;
    final canDelete = !h.system && h.used == 0;
    final deleteNote = h.system ? ' (built-in)' : h.used > 0 ? ' (in use)' : '';
    return Opacity(
      opacity: dim ? 0.6 : 1,
      child: ListTile(
        key: Key('head_${h.code}'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
          child: Text(h.code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.primary)),
        ),
        title: Text(h.label, style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!h.active) const _Tag('Archived', Colors.grey),
              if (h.system) const _Tag('Built-in', Colors.blueGrey),
              if (h.jobLinked) const _Tag('Job-linked', Colors.deepPurple),
              if (h.recurring) const _Tag('Recurring', Colors.teal),
              if (h.foreign) const _Tag('Foreign · RCM', Colors.orange),
              Text(h.used == 0 ? 'Not used yet' : '${h.used} expense${h.used == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          key: Key('head_menu_${h.code}'),
          enabled: !busy,
          tooltip: 'Actions',
          onSelected: (v) {
            switch (v) {
              case 'edit':
                onEdit();
              case 'archive':
                onArchive();
              case 'restore':
                onRestore();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (h.active) const PopupMenuItem(value: 'archive', child: Text('Archive')) else const PopupMenuItem(value: 'restore', child: Text('Restore')),
            PopupMenuItem(value: 'delete', enabled: canDelete, child: Text('Delete$deleteNote')),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}

/// The add / edit form. Pops with the message to show when it saved, null when cancelled.
class _HeadForm extends ConsumerStatefulWidget {
  final ExpenseHead? head;
  final List<String> groups;
  const _HeadForm({required this.head, required this.groups});

  @override
  ConsumerState<_HeadForm> createState() => _HeadFormState();
}

class _HeadFormState extends ConsumerState<_HeadForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _group;
  late final TextEditingController _code;
  late bool _jobLinked;
  late bool _recurring;
  late bool _foreign;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.head != null;

  @override
  void initState() {
    super.initState();
    final h = widget.head;
    _name = TextEditingController(text: h?.label ?? '');
    _group = TextEditingController(text: h?.group ?? '');
    _code = TextEditingController(text: h?.code ?? '');
    _jobLinked = h?.jobLinked ?? false;
    _recurring = h?.recurring ?? false;
    _foreign = h?.foreign ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _group.dispose();
    _code.dispose();
    super.dispose();
  }

  /// A built-in head's code never changes, and neither does one that is already used.
  String? get _codeLocked {
    final h = widget.head;
    if (h == null) return null;
    if (h.system) return 'The code of a built-in head cannot change.';
    if (h.used > 0) return 'This head is in use, so its code cannot change.';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final service = ref.read(adminExpenseServiceProvider);
    try {
      final name = _name.text.trim();
      final h = widget.head;
      if (h == null) {
        final made = await service.createExpenseHead(
          name: name,
          group: _group.text.trim(),
          code: _code.text.trim(),
          jobLinked: _jobLinked,
          recurring: _recurring,
          foreign: _foreign,
        );
        if (mounted) Navigator.of(context).pop('"${made.label}" added as ${made.code}');
      } else {
        await service.updateExpenseHead(
          h.id,
          name: name,
          group: _group.text.trim(),
          code: _codeLocked == null && _code.text.trim() != h.code ? _code.text.trim() : null,
          jobLinked: _jobLinked,
          recurring: _recurring,
          foreign: _foreign,
        );
        if (mounted) Navigator.of(context).pop('"$name" saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final locked = _codeLocked;
    return AlertDialog(
      title: Text(_editing ? 'Edit expense head' : 'Add expense head'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const Key('head_name'),
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Head name *', hintText: 'e.g. Courier Charges'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Give the head a name' : null,
                ),
                12.h,
                TextFormField(
                  key: const Key('head_group'),
                  controller: _group,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Group', hintText: 'Operating Expense', helperText: 'Where it sits in the reports'),
                ),
                if (widget.groups.isNotEmpty) ...[
                  6.h,
                  Wrap(
                    spacing: 6,
                    runSpacing: 0,
                    children: [
                      for (final g in widget.groups)
                        ActionChip(
                          label: Text(g, style: const TextStyle(fontSize: 11.5)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _group.text = g),
                        ),
                    ],
                  ),
                ],
                12.h,
                TextFormField(
                  key: const Key('head_code'),
                  controller: _code,
                  enabled: locked == null,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Code',
                    helperText: locked ?? (_editing ? 'Can only change while nothing uses it' : 'Optional — leave blank and one is made from the name, e.g. COU-01'),
                    helperMaxLines: 2,
                  ),
                ),
                8.h,
                SwitchListTile(
                  key: const Key('head_job_linked'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Needs a bride / event cost tag'),
                  subtitle: const Text('For costs that belong to one job'),
                  value: _jobLinked,
                  onChanged: (v) => setState(() => _jobLinked = v),
                ),
                SwitchListTile(
                  key: const Key('head_recurring'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Can be a monthly bill'),
                  subtitle: const Text('Shows the Recurring option'),
                  value: _recurring,
                  onChanged: (v) => setState(() => _recurring = v),
                ),
                SwitchListTile(
                  key: const Key('head_foreign'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Foreign / subscription'),
                  subtitle: const Text('Suggests GST reverse charge (RCM)'),
                  value: _foreign,
                  onChanged: (v) => setState(() => _foreign = v),
                ),
                if (_error != null) ...[
                  8.h,
                  Text(_error!, key: const Key('head_error'), style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text('Cancel', style: TextStyle(color: crm.textSecondary))),
        FilledButton(
          key: const Key('head_save'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: crm.primary),
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
