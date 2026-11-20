import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_widgets.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';

/// CRM → Cases (/crm/cases): complaints, follow-ups, re-engagement calls and trial follow-ups — each with an owner, a due time and a
/// status. A member sees their own cases and the ones nobody has; the head and management see all.
class CrmCasesScreen extends ConsumerWidget {
  const CrmCasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final me = ref.watch(crmMeProvider);
    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        title: const Text('CRM Cases'),
        actions: [
          TextButton.icon(onPressed: () => context.go('/crm/re-engagement'), icon: const Icon(Icons.phone_callback_outlined, size: 18), label: const Text('Clients to call')),
          IconButton(tooltip: 'Refresh', onPressed: () => refreshCrm(ref), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmMeProvider)),
        data: (who) => CrmCasesView(me: who, padding: const EdgeInsets.all(16)),
      ),
    );
  }
}

const _tabs = [('active', 'Open'), ('overdue', 'Overdue'), ('resolved', 'Resolved'), ('closed', 'Closed'), ('', 'All')];

/// The case list with its filters (also the dashboard's Cases tab).
class CrmCasesView extends ConsumerStatefulWidget {
  const CrmCasesView({super.key, required this.me, this.padding = EdgeInsets.zero});
  final CrmMe me;
  final EdgeInsets padding;

  @override
  ConsumerState<CrmCasesView> createState() => _CrmCasesViewState();
}

class _CrmCasesViewState extends ConsumerState<CrmCasesView> {
  CrmCaseQuery _q = const CrmCaseQuery();
  String _tab = 'active';
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setTab(String t) => setState(() {
    _tab = t;
    _q = _q.copyWith(status: t == 'overdue' ? 'active' : t, overdue: t == 'overdue', page: 1);
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(crmCasesProvider(_q));
    final counts = async.value?.counts ?? const <String, int>{};
    int? countOf(String t) => switch (t) {
      'active' => (counts['open'] ?? 0) + (counts['in_progress'] ?? 0),
      'overdue' => counts['overdue'],
      'resolved' => counts['resolved'],
      'closed' => counts['closed'],
      _ => null,
    };
    return ListView(
      padding: widget.padding,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (k, l) in _tabs)
              ChoiceChip(
                key: Key('crmCaseTab_${k.isEmpty ? 'all' : k}'),
                label: Text(countOf(k) == null || async.value == null ? l : '$l (${countOf(k)})'),
                selected: _tab == k,
                onSelected: (_) => _setTab(k),
              ),
            DropdownButton<String>(
              value: _q.kind ?? '',
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: '', child: Text('Every kind')),
                for (final k in crmCaseKinds) DropdownMenuItem(value: k, child: Text(crmCaseKindLabel(k))),
              ],
              onChanged: (v) => setState(() => _q = (v == null || v.isEmpty) ? _q.copyWith(clearKind: true, page: 1) : _q.copyWith(kind: v, page: 1)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search case no., client, phone',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: crm.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.border)),
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) setState(() => _q = _q.copyWith(search: v.trim(), page: 1));
                  });
                },
              ),
            ),
            if (widget.me.canWrite) ...[
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const Key('crmNewCase'),
                onPressed: () async {
                  final c = await showCrmNewCaseDialog(context, ref, me: widget.me);
                  if (c != null && context.mounted) context.go('/crm/cases/${c.id}');
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New case'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmCasesProvider(_q))),
          data: (page) {
            if (page.items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text(_tab == 'overdue' ? 'No case is overdue.' : 'No cases here.', key: const Key('crmCasesEmpty'), style: TextStyle(color: crm.textSecondary))),
              );
            }
            return Column(
              children: [
                for (final c in page.items) CrmCaseRow(c: c),
                if (page.totalPages > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: page.page > 1 ? () => setState(() => _q = _q.copyWith(page: page.page - 1)) : null, icon: const Icon(Icons.chevron_left)),
                      Text('Page ${page.page} of ${page.totalPages} · ${page.totalItems} cases', style: TextStyle(color: crm.textSecondary)),
                      IconButton(onPressed: page.page < page.totalPages ? () => setState(() => _q = _q.copyWith(page: page.page + 1)) : null, icon: const Icon(Icons.chevron_right)),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

Color crmCaseStatusColor(CrmTheme crm, CrmCase c) {
  if (c.overdue) return crm.destructive;
  return switch (c.status) {
    'open' => crm.warning,
    'in_progress' => crm.primary,
    'resolved' => crm.success,
    _ => crm.textSecondary,
  };
}

class CrmCaseRow extends StatelessWidget {
  const CrmCaseRow({super.key, required this.c});
  final CrmCase c;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = crmCaseStatusColor(crm, c);
    return CrmPanel(
      key: Key('crmCase_${c.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      radius: 12,
      borderColor: c.overdue ? crm.destructive.withValues(alpha: 0.45) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/crm/cases/${c.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(c.kind == 'complaint' ? Icons.report_problem_outlined : (c.kind == 're_engagement' ? Icons.phone_callback_outlined : Icons.assignment_outlined), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    Text(
                      [c.caseNumber, c.kindLabel, if (c.priority == 'high') 'high priority'].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CrmOwnerChip(name: c.ownerName, assigned: c.ownerId != null),
                        Text(
                          c.isOpen ? crmDueText(c.dueAt) : '${c.statusLabel} ${crmWhen(c.resolvedAt ?? c.closedAt)}',
                          style: TextStyle(fontSize: 11.5, fontWeight: c.overdue ? FontWeight.w700 : FontWeight.w500, color: c.overdue ? crm.destructive : crm.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(c.overdue ? 'Overdue' : c.statusLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a case by hand. A member's case is theirs; the head may give it to someone or leave it unassigned. Prefill from a review /
/// booking with [initial]. → the new case, or null.
Future<CrmCase?> showCrmNewCaseDialog(BuildContext context, WidgetRef ref, {required CrmMe me, Map<String, dynamic> initial = const {}}) {
  return showDialog<CrmCase>(context: context, builder: (_) => _NewCaseDialog(me: me, initial: initial));
}

class _NewCaseDialog extends ConsumerStatefulWidget {
  const _NewCaseDialog({required this.me, required this.initial});
  final CrmMe me;
  final Map<String, dynamic> initial;

  @override
  ConsumerState<_NewCaseDialog> createState() => _NewCaseDialogState();
}

class _NewCaseDialogState extends ConsumerState<_NewCaseDialog> {
  late String _kind = (widget.initial['kind'] as String?) ?? 'complaint';
  String _priority = 'normal';
  late final _name = TextEditingController(text: (widget.initial['customerName'] as String?) ?? '');
  late final _phone = TextEditingController(text: (widget.initial['phone'] as String?) ?? '');
  late final _title = TextEditingController(text: (widget.initial['title'] as String?) ?? '');
  late final _desc = TextEditingController(text: (widget.initial['description'] as String?) ?? '');
  String? _owner;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty && _title.text.trim().isEmpty) {
      showErrorSnackBar(context, 'Give the client\'s name or a title.');
      return;
    }
    setState(() => _saving = true);
    try {
      final c = await ref.read(crmServiceProvider).createCase({
        ...widget.initial,
        'kind': _kind,
        'priority': _priority,
        'customerName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        if (_owner != null) 'ownerId': _owner,
      });
      refreshCrm(ref);
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.me.canAssign ? ref.watch(crmTeamProvider).value : null;
    return AlertDialog(
      title: const Text('New case'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('crmNewCaseKind'),
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: [for (final k in crmCaseKinds) DropdownMenuItem(value: k, child: Text(crmCaseKindLabel(k)))],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Client')),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title (optional)')),
              TextField(controller: _desc, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'What happened')),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'low', label: Text('Low')), ButtonSegment(value: 'normal', label: Text('Normal')), ButtonSegment(value: 'high', label: Text('High'))],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
              if (team != null)
                DropdownButtonFormField<String?>(
                  initialValue: _owner,
                  decoration: const InputDecoration(labelText: 'Owner'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Not assigned yet')),
                    for (final m in team.members) DropdownMenuItem<String?>(value: m.userId, child: Text(m.name)),
                  ],
                  onChanged: (v) => setState(() => _owner = v),
                )
              else
                Padding(padding: const EdgeInsets.only(top: 10), child: Text('The case will be yours.', style: TextStyle(color: context.crmColors.textSecondary))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('crmNewCaseSave'), onPressed: _saving ? null : _save, child: const Text('Open the case')),
      ],
    );
  }
}
