import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/rupees.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_spend_widgets.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

export 'package:nizan_crm/core/utils/rupees.dart';

// A project's COST in the app: asked for in the project form, shown on the project, changed (with a reason once it was
// approved) and decided by the finance head. The rules are the server's (backend utils/projectCost.js); this only asks for
// what it needs and says what it will do.

/// What the cost section of a form holds: a single amount, or a breakdown whose total is the cost.
class CostInput {
  final double? typed;
  final List<CostLine> plan;
  const CostInput({this.typed, this.plan = const []});

  double get total => plan.isNotEmpty ? plan.fold<double>(0, (a, l) => a + l.amount) : (typed ?? 0);
  bool get valid => total > 0;
}

/// How a cost status reads: its words, colour and icon.
({String label, Color color, IconData icon}) costStatusLook(String status) => switch (status) {
  'pending' => (label: 'Awaiting finance approval', color: const Color(0xFFB45309), icon: Icons.hourglass_top_rounded),
  'approved' => (label: 'Cost approved', color: const Color(0xFF15803D), icon: Icons.verified_outlined),
  'returned' => (label: 'Sent back by Finance', color: const Color(0xFFB91C1C), icon: Icons.undo_rounded),
  _ => (label: 'No cost set', color: const Color(0xFF6B7280), icon: Icons.remove_circle_outline),
};

class CostStatusPill extends StatelessWidget {
  const CostStatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final look = costStatusLook(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: look.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(look.icon, size: 12, color: look.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              look.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: look.color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── the form section ─────────────────────────────────────────────────────────

class _Row {
  _Row(this.category, String amount) : controller = TextEditingController(text: amount);
  String category;
  final TextEditingController controller;
}

const _maxLines = 12;

/// "Estimated cost" for a project form: one amount, and an optional breakdown by kind of cost. With a breakdown the
/// amount is its total, so the two can never disagree.
class ProjectCostFields extends StatefulWidget {
  const ProjectCostFields({super.key, required this.onChanged, this.initial = const CostInput(), this.showError = false, this.helper});
  final CostInput initial;
  final ValueChanged<CostInput> onChanged;

  /// Show "Enter the estimated cost" under the amount (after a try to save without one).
  final bool showError;
  final String? helper;

  @override
  State<ProjectCostFields> createState() => _ProjectCostFieldsState();
}

class _ProjectCostFieldsState extends State<ProjectCostFields> {
  final _total = TextEditingController();
  final _rows = <_Row>[];
  bool _open = false;

  @override
  void initState() {
    super.initState();
    for (final l in widget.initial.plan) {
      _rows.add(_Row(l.category, l.amount == l.amount.roundToDouble() ? l.amount.round().toString() : l.amount.toString()));
    }
    _open = _rows.isNotEmpty;
    final typed = widget.initial.typed;
    _total.text = widget.initial.plan.isNotEmpty ? _plain(widget.initial.total) : (typed == null || typed == 0 ? '' : _plain(typed));
  }

  @override
  void dispose() {
    _total.dispose();
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  List<CostLine> get _lines => [
    for (final r in _rows)
      if ((parseAmount(r.controller.text) ?? 0) > 0) CostLine(category: r.category, amount: parseAmount(r.controller.text)!),
  ];

  bool get _fromBreakdown => _lines.isNotEmpty;

  void _emit() {
    final lines = _lines;
    if (lines.isNotEmpty) _total.text = _plain(lines.fold<double>(0, (a, l) => a + l.amount));
    widget.onChanged(CostInput(typed: lines.isEmpty ? parseAmount(_total.text) : null, plan: lines));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final fromBreakdown = _fromBreakdown;
    final missing = widget.showError && !(parseAmount(_total.text) != null && parseAmount(_total.text)! > 0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: missing ? crm.destructive : crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 16, color: crm.primary),
              const SizedBox(width: 6),
              Text(
                'Estimated cost',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('cost_total'),
            controller: _total,
            readOnly: fromBreakdown,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: 'Estimated cost (₹) *',
              prefixText: '₹ ',
              errorText: missing ? 'Enter the estimated cost of this project' : null,
              helperText: fromBreakdown
                  ? 'The total of the breakdown below'
                  : (widget.helper ?? 'The finance head approves it before the project can start'),
            ),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            key: const Key('cost_breakdown_toggle'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 32)),
            onPressed: () => setState(() {
              _open = !_open;
              if (_open && _rows.isEmpty) _rows.add(_Row('manpower', ''));
            }),
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(_open ? 'Hide the breakdown' : 'Break it down (optional)'),
          ),
          if (_open) ...[
            for (var i = 0; i < _rows.length; i++)
              Padding(
                key: Key('cost_line_$i'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        key: Key('cost_line_cat_$i'),
                        initialValue: _rows[i].category,
                        isExpanded: true,
                        isDense: true,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                        items: [
                          for (final c in projectCostCategories)
                            DropdownMenuItem(
                              value: c.$1,
                              child: Text(c.$2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _rows[i].category = v ?? 'other';
                          _emit();
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        key: Key('cost_line_amount_$i'),
                        controller: _rows[i].controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixText: '₹ ',
                          hintText: 'Amount',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onChanged: (_) => _emit(),
                      ),
                    ),
                    IconButton(
                      key: Key('cost_line_remove_$i'),
                      tooltip: 'Remove this line',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _rows.removeAt(i).controller.dispose();
                        if (_rows.isEmpty) _open = false;
                        _emit();
                      }),
                    ),
                  ],
                ),
              ),
            if (_rows.length < _maxLines)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('cost_add_line'),
                  onPressed: () => setState(() => _rows.add(_Row('other', ''))),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add a line'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── the cost on a project ────────────────────────────────────────────────────

/// What a project's cost looks like on its page: where it stands, the amounts (for those who may see them), the
/// breakdown, Finance's note and the changes — and the actions that person may take.
class ProjectCostCard extends ConsumerWidget {
  const ProjectCostCard({super.key, required this.project});
  final Project project;

  /// A project from before costs existed has nothing to say about it — unless this person can set one.
  static bool shows(Project p) => !(p.costStatus == 'none' && !(p.cost != null && p.access.canEditCost));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final p = project;
    final cost = p.cost;
    if (!shows(p)) return const SizedBox.shrink();

    final bodyLines = <Widget>[];
    if (cost == null) {
      bodyLines.add(
        Text(switch (p.costStatus) {
          'pending' => 'The estimated cost is waiting for the finance head. The project cannot start until it is approved.',
          'returned' => 'The finance head sent the cost back. The project manager is revising it.',
          _ => 'The estimated cost is approved.',
        }, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      );
    } else {
      if (p.costStatus == 'none') {
        bodyLines.add(
          Text(
            'No cost has been set for this project yet. Set one: the finance head approves it, and spending is held against it.',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
        );
      } else {
        bodyLines.add(_figure(crm, 'Estimated cost', rupees(cost.budget), key: const Key('cost_budget')));
        if (cost.hasApproval) {
          bodyLines.add(
            _figure(
              crm,
              p.costWaiting ? 'Limit until the change is approved' : 'Approved by Finance',
              rupees(cost.approvedBudget),
              key: const Key('cost_approved'),
            ),
          );
        }
        if (cost.hasApproval) {
          bodyLines.add(const SizedBox(height: 8));
          bodyLines.add(SpendMeter(cost: cost));
          bodyLines.add(
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('cost_spend_open'),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 32)),
                onPressed: () => showProjectSpendSheet(context, p),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('See spending'),
              ),
            ),
          );
        }
        if (cost.plan.isNotEmpty) {
          bodyLines.add(const SizedBox(height: 6));
          for (final l in cost.plan) {
            bodyLines.add(
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(costCategoryLabel(l.category), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ),
                    Text(
                      rupees(l.amount),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary),
                    ),
                  ],
                ),
              ),
            );
          }
        }
        if (cost.note.isNotEmpty) {
          bodyLines.add(const SizedBox(height: 6));
          bodyLines.add(
            Text(
              'Finance: ${cost.note}',
              key: const Key('cost_note'),
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: crm.textSecondary),
            ),
          );
        }
        if (cost.changes.isNotEmpty) {
          bodyLines.add(const SizedBox(height: 8));
          bodyLines.add(
            Text(
              'Changes',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
            ),
          );
          for (final c in cost.changes.take(3)) {
            bodyLines.add(
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '${DateFormat('d MMM').format(c.at)}${c.byName.isEmpty ? '' : ' · ${c.byName}'} — ${c.reason}${c.lines.isEmpty ? '' : ' (${c.lines.join('; ')})'}',
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                ),
              ),
            );
          }
        }
      }
    }

    final actions = <Widget>[
      if (p.access.canDecideCost)
        FilledButton.icon(
          key: const Key('cost_decide'),
          onPressed: () async {
            final result = await showCostDecisionDialog(
              context,
              ref,
              id: p.id,
              name: p.name,
              department: p.targetDepartment,
              requested: cost?.budget ?? 0,
              approvedBudget: cost?.approvedBudget ?? 0,
              changeReason: cost?.changes.firstOrNull?.reason ?? '',
            );
            if (result != null) ref.refreshData.projects();
          },
          icon: const Icon(Icons.fact_check_outlined, size: 16),
          label: const Text('Review & decide'),
        ),
      if (p.access.canEditCost)
        OutlinedButton.icon(
          key: const Key('cost_change'),
          onPressed: () async {
            final result = await showChangeCostDialog(context, ref, p);
            if (result != null) ref.refreshData.projects();
          },
          icon: Icon(p.costStatus == 'none' ? Icons.add : Icons.edit_outlined, size: 16),
          label: Text(switch (p.costStatus) {
            'none' => 'Set the cost',
            'returned' => 'Revise the cost',
            _ => 'Change the cost',
          }),
        ),
    ];

    return Container(
      key: const Key('project_cost_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: crm.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Project cost',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: CostStatusPill(p.costStatus)),
            ],
          ),
          const SizedBox(height: 10),
          ...bodyLines,
          if (actions.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: actions)],
        ],
      ),
    );
  }

  Widget _figure(CrmTheme crm, String label, String value, {Key? key}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        ),
        Text(
          value,
          key: key,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
        ),
      ],
    ),
  );
}

// ── changing the cost ────────────────────────────────────────────────────────

/// Set, revise or change the cost of [project]. Once it was approved a change needs a reason and goes back to the finance
/// head (the approved amount stays the limit meanwhile). Returns the project as the server now has it, or null.
Future<Project?> showChangeCostDialog(BuildContext context, WidgetRef ref, Project project) {
  final cost = project.cost;
  var input = CostInput(typed: (cost?.plan.isEmpty ?? true) && (cost?.budget ?? 0) > 0 ? cost!.budget : null, plan: cost?.plan ?? const []);
  final reason = TextEditingController();
  final needsReason = project.costApproved;
  var busy = false;
  var showError = false;
  final messenger = ScaffoldMessenger.of(context);

  return showDialog<Project>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(project.costStatus == 'none' ? 'Set the cost' : (project.costReturned ? 'Revise the cost' : 'Change the cost')),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (needsReason)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'This cost was approved. A change needs a reason and goes back to the finance head; ${rupees(cost?.approvedBudget ?? 0)} stays the limit until it is approved.',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ProjectCostFields(initial: input, showError: showError, onChanged: (v) => input = v),
                if (needsReason) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('cost_reason'),
                    controller: reason,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Why is the cost changing? *'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(key: const Key('cost_cancel'), onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            key: const Key('cost_save'),
            onPressed: busy
                ? null
                : () async {
                    if (!input.valid) {
                      setD(() => showError = true);
                      return;
                    }
                    if (needsReason && reason.text.trim().length < 3) {
                      messenger.showSnackBar(const SnackBar(content: Text('Say why the cost is changing')));
                      return;
                    }
                    setD(() => busy = true);
                    try {
                      final saved = await ref
                          .read(projectServiceProvider)
                          .saveCost(project.id, budget: input.typed, plan: input.plan, reason: reason.text);
                      if (ctx.mounted) Navigator.pop(ctx, saved);
                      messenger.showSnackBar(const SnackBar(content: Text('Sent to the finance head for approval')));
                    } catch (e) {
                      setD(() => busy = false);
                      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                    }
                  },
            child: Text(busy ? 'Saving…' : 'Send for approval'),
          ),
        ],
      ),
    ),
  );
}

// ── the finance head's decision ──────────────────────────────────────────────

/// Approve the cost (as asked, or a different amount with a reason) or send it back with what to change. Returns the
/// project as the server now has it, or null when cancelled.
Future<Project?> showCostDecisionDialog(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String name,
  required double requested,
  String department = '',
  double approvedBudget = 0,
  String changeReason = '',
}) {
  var approve = true;
  final amount = TextEditingController(text: requested == requested.roundToDouble() ? requested.round().toString() : requested.toString());
  final note = TextEditingController();
  var busy = false;
  final messenger = ScaffoldMessenger.of(context);

  return showDialog<Project>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final given = parseAmount(amount.text);
        final differs = approve && given != null && (given - requested).abs() > 0.004;
        return AlertDialog(
          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${department.isEmpty ? 'The project' : department} asks for ${rupees(requested)}.',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  if (approvedBudget > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('This is a change: ${rupees(approvedBudget)} is approved so far.', style: const TextStyle(fontSize: 12.5)),
                    ),
                  if (changeReason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Reason given: $changeReason', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: true, label: Text('Approve'), icon: Icon(Icons.check_circle_outline, size: 16)),
                      ButtonSegment(value: false, label: Text('Send back'), icon: Icon(Icons.undo_rounded, size: 16)),
                    ],
                    selected: {approve},
                    onSelectionChanged: (v) => setD(() => approve = v.first),
                  ),
                  const SizedBox(height: 12),
                  if (approve) ...[
                    TextField(
                      key: const Key('decide_amount'),
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(
                        labelText: 'Amount to approve (₹)',
                        prefixText: '₹ ',
                        helperText: 'This becomes the limit spending is held against',
                      ),
                      onChanged: (_) => setD(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    key: const Key('decide_note'),
                    controller: note,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: approve ? (differs ? 'Why a different amount? *' : 'Note (optional)') : 'What should be changed? *',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(key: const Key('decide_cancel'), onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              key: const Key('decide_confirm'),
              onPressed: busy
                  ? null
                  : () async {
                      if (approve && (given == null || given <= 0)) {
                        messenger.showSnackBar(const SnackBar(content: Text('Enter an amount above zero')));
                        return;
                      }
                      if ((!approve || differs) && note.text.trim().length < 3) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(approve ? 'Say why you approved a different amount' : 'Say what should be changed')),
                        );
                        return;
                      }
                      setD(() => busy = true);
                      try {
                        final saved = await ref
                            .read(projectServiceProvider)
                            .decideCost(id, approve: approve, approvedAmount: approve ? given : null, note: note.text);
                        if (ctx.mounted) Navigator.pop(ctx, saved);
                        // still pending after approving: the increase is above the limit, so the CEO / Executive Director decide
                        final held = approve && saved.costStatus == 'pending';
                        messenger.showSnackBar(SnackBar(content: Text(held ? 'Checked. The CEO / Executive Director will decide on this cost.' : (approve ? 'Cost approved' : 'Sent back to the project manager'))));
                      } catch (e) {
                        setD(() => busy = false);
                        messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                      }
                    },
              child: Text(busy ? 'Saving…' : (approve ? 'Approve' : 'Send back')),
            ),
          ],
        );
      },
    ),
  );
}
