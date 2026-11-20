import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/rupees.dart';
import 'package:nizan_crm/features/it/domain/task_cost.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_spend_widgets.dart'
    show spendLevelColor;

// The planned cost of tasks, in the app: the cost boxes of the task editor, the ask for a budget increase when a task would take the
// project over its approved budget, and the "planned by tasks" block on the project's cost card. The rules are the server's
// (backend utils/taskCost.js); what is shown here is advice — the server decides.

/// The cost boxes of the task editor: none / an amount / hours × a rate, with what it works out to and what it does to the plan.
class TaskCostFields extends StatefulWidget {
  const TaskCostFields({
    super.key,
    required this.hours,
    required this.onChanged,
    this.initialMode = TaskCostMode.none,
    this.initialAmount = 0,
    this.initialRate = 0,
    this.plan,
    this.existingPlanned = 0,
  });

  /// The editor's "Est. hours" box: an hours-based cost follows it as it is typed.
  final TextEditingController hours;
  final ValueChanged<TaskCostInput> onChanged;
  final String initialMode;
  final double initialAmount;
  final double initialRate;

  /// Where the project's plan stands (to say what this change does to it); null when not known.
  final TaskPlan? plan;

  /// What this task is planned at now (0 for a new task), so the plan "with this" can be worked out.
  final double existingPlanned;

  @override
  State<TaskCostFields> createState() => _TaskCostFieldsState();
}

class _TaskCostFieldsState extends State<TaskCostFields> {
  late String _mode = widget.initialMode;
  late final TextEditingController _amount = TextEditingController(
    text: _plain(
      widget.initialMode == TaskCostMode.amount ? widget.initialAmount : 0,
    ),
  );
  late final TextEditingController _rate = TextEditingController(
    text: _plain(
      widget.initialMode == TaskCostMode.rate ? widget.initialRate : 0,
    ),
  );

  static String _plain(double v) => v <= 0
      ? ''
      : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  @override
  void initState() {
    super.initState();
    // the first value is the starting one, so the editor never has to guess
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    super.dispose();
  }

  TaskCostInput _input() {
    final a = parseAmount(_amount.text);
    final r = parseAmount(_rate.text);
    final invalid =
        (_mode == TaskCostMode.amount &&
            _amount.text.trim().isNotEmpty &&
            a == null) ||
        (_mode == TaskCostMode.rate &&
            _rate.text.trim().isNotEmpty &&
            r == null);
    return TaskCostInput(
      mode: _mode,
      amount: a ?? 0,
      rate: r ?? 0,
      invalid: invalid,
    );
  }

  void _emit() => widget.onChanged(_input());

  void _set(VoidCallback f) {
    setState(f);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget chip(String key, String mode, String label) => ChoiceChip(
      key: Key('task_cost_mode_$key'),
      label: Text(label),
      selected: _mode == mode,
      onSelected: (_) => _set(() => _mode = mode),
    );
    final amountFilter = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    ];

    return Column(
      key: const Key('task_cost_fields'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.payments_outlined, size: 17, color: crm.primary),
            const SizedBox(width: 6),
            const Text(
              'Planned cost',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            chip('none', TaskCostMode.none, 'No cost'),
            chip('amount', TaskCostMode.amount, 'An amount'),
            chip('rate', TaskCostMode.rate, 'Hours × rate'),
          ],
        ),
        if (_mode == TaskCostMode.amount) ...[
          const SizedBox(height: 10),
          TextField(
            key: const Key('task_cost_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: amountFilter,
            onChanged: (_) => _set(() {}),
            decoration: const InputDecoration(
              labelText: 'Cost (₹)',
              prefixText: '₹ ',
            ),
          ),
        ],
        if (_mode == TaskCostMode.rate) ...[
          const SizedBox(height: 10),
          TextField(
            key: const Key('task_cost_rate'),
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: amountFilter,
            onChanged: (_) => _set(() {}),
            decoration: const InputDecoration(
              labelText: 'Rate per hour (₹)',
              prefixText: '₹ ',
              helperText: 'Multiplied by the estimated hours above.',
            ),
          ),
        ],
        if (_mode != TaskCostMode.none)
          ListenableBuilder(
            listenable: widget.hours,
            builder: (context, _) {
              final planned = _input().planned(
                double.tryParse(widget.hours.text.trim()) ?? 0,
              );
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _effect(crm, planned),
              );
            },
          ),
      ],
    );
  }

  /// What this works out to, and what it does to the plan against the project's budget.
  Widget _effect(CrmTheme crm, double? planned) {
    final plan = widget.plan;
    final lines = <Widget>[
      Text(
        planned == null ? '' : 'Planned cost: ${rupees(planned)}',
        key: const Key('task_cost_preview'),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: crm.textPrimary,
        ),
      ),
    ];
    if (_mode == TaskCostMode.rate &&
        (double.tryParse(widget.hours.text.trim()) ?? 0) <= 0) {
      lines.add(
        Text(
          'Enter the estimated hours above: the cost is hours × rate.',
          style: TextStyle(fontSize: 12, color: crm.textSecondary),
        ),
      );
    }
    if (plan != null && plan.ceiling > 0 && planned != null) {
      final after = plan.planned - widget.existingPlanned + planned;
      final adds = planned > widget.existingPlanned;
      final over = after > plan.ceiling && adds;
      lines.add(
        Text(
          over
              ? 'With this the tasks add up to ${rupees(after)}, ${rupees(after - plan.ceiling)} above the ${rupees(plan.ceiling)} ${plan.awaiting ? 'asked for' : 'approved'}. A budget increase will be asked of the finance head.'
              : 'With this the tasks add up to ${rupees(after)} of the ${rupees(plan.ceiling)} ${plan.awaiting ? 'asked for' : 'approved'}.',
          key: const Key('task_cost_plan_effect'),
          style: TextStyle(
            fontSize: 12,
            color: over ? spendLevelColor('over') : crm.textSecondary,
            fontWeight: over ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }
}

/// What a person types into the budget-increase dialog.
typedef BudgetIncreaseRequest = ({String reason, double amount});

/// The server refused a task because it would take the project over its approved budget: ask for an increase. [over] has the
/// numbers. Returns the reason and the new budget to send, or null when the person backs out.
Future<BudgetIncreaseRequest?> showBudgetIncreaseDialog(
  BuildContext context,
  OverBudget over,
) {
  final reason = TextEditingController();
  final amount = TextEditingController(
    text: over.planned == null ? '' : _wholeOr(over.planned!),
  );
  String? error;
  return showDialog<BudgetIncreaseRequest>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        key: const Key('over_budget_dialog'),
        title: const Text('Over the approved budget'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(over.message, key: const Key('over_budget_message')),
              const SizedBox(height: 14),
              TextField(
                key: const Key('over_budget_amount'),
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'New budget to ask for (₹)',
                  prefixText: '₹ ',
                  helperText: over.planned == null
                      ? null
                      : 'At least ${rupees(over.planned!)} to cover the tasks.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('over_budget_reason'),
                controller: reason,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Why is more needed?',
                  alignLabelWithHint: true,
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  key: const Key('over_budget_error'),
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('over_budget_cancel'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('over_budget_send'),
            onPressed: () {
              final a = parseAmount(amount.text);
              if (a == null || a <= 0) {
                setState(() => error = 'Enter the new budget as an amount.');
              } else if (over.planned != null && a < over.planned!) {
                setState(
                  () => error =
                      'The new budget has to cover the tasks: at least ${rupees(over.planned!)}.',
                );
              } else if (reason.text.trim().length < 3) {
                setState(() => error = 'Say why more is needed.');
              } else {
                Navigator.pop(ctx, (reason: reason.text.trim(), amount: a));
              }
            },
            child: const Text('Save and ask the finance head'),
          ),
        ],
      ),
    ),
  );
}

/// The same refusal for someone who may not ask for an increase: say so, and who can.
Future<void> showOverBudgetNotice(BuildContext context, OverBudget over) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('over_budget_notice'),
        title: const Text('Over the approved budget'),
        content: Text(over.message, key: const Key('over_budget_message')),
        actions: [
          FilledButton(
            key: const Key('over_budget_ok'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );

String _wholeOr(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

/// "Planned by tasks" on the project's cost card: what the tasks add up to against the budget, how many still have no cost, who
/// asked for what, and where the money is planned by department.
class TaskPlanBlock extends StatelessWidget {
  const TaskPlanBlock({super.key, required this.plan});
  final TaskPlan plan;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final p = plan;
    final color = spendLevelColor(p.level);
    final share = (p.usedFraction ?? 0).clamp(0.0, 1.0);
    final depts = p.byDepartment.where((d) => d.planned > 0).toList();
    return Column(
      key: const Key('task_plan_block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Planned by tasks',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: crm.textSecondary,
                ),
              ),
            ),
            if (p.ceiling > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p.level == 'over'
                      ? 'Over budget'
                      : '${((p.usedFraction ?? 0) * 100).round()}% of ${p.awaiting ? 'the request' : 'the budget'}',
                  key: const Key('task_plan_level'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          rupees(p.planned),
          key: const Key('task_plan_planned'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: crm.textPrimary,
          ),
        ),
        if (p.ceiling > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 9,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: crm.background)),
                  FractionallySizedBox(
                    widthFactor: share,
                    child: ColoredBox(
                      key: const Key('task_plan_bar'),
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of ${rupees(p.ceiling)} ${p.awaiting ? 'asked for (waiting for the finance head)' : 'approved'}',
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
        ],
        if (p.level == 'over')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${rupees(p.over)} above the budget. Cut a task, or ask the finance head for an increase.',
              key: const Key('task_plan_over'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        if (p.unpriced > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${p.unpriced} of ${p.leaves} ${p.leaves == 1 ? 'task has' : 'tasks have'}${p.unpriced == p.leaves ? ' no cost yet.' : ' no cost yet — the plan will grow.'}',
              key: const Key('task_plan_unpriced'),
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            ),
          ),
        if (depts.length > 1) ...[
          const SizedBox(height: 6),
          for (final d in depts)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.name.isEmpty ? 'Owning department' : d.name,
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                  ),
                  Text(
                    rupees(d.planned),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: crm.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// The tasks behind a project's plan, one line each: what it is, where it hangs, and what it is planned to cost — or "No cost yet".
/// Shows the first few; "Show all" opens the rest. With [onTap] a line can be opened (to give it a cost).
class TaskCostList extends StatefulWidget {
  const TaskCostList({
    super.key,
    required this.lines,
    this.more = 0,
    this.initialShown = 5,
    this.onTap,
  });
  final List<TaskCostLine> lines;

  /// How many more tasks exist than are in [lines] (the server lists only so many).
  final int more;
  final int initialShown;
  final ValueChanged<TaskCostLine>? onTap;

  @override
  State<TaskCostList> createState() => _TaskCostListState();
}

class _TaskCostListState extends State<TaskCostList> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final lines = widget.lines;
    if (lines.isEmpty) return const SizedBox.shrink();
    final shown = _all ? lines : lines.take(widget.initialShown).toList();
    final hidden = lines.length - shown.length;
    const amber = Color(0xFFB45309);
    return Column(
      key: const Key('task_cost_list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Task costs',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: crm.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < shown.length; i++)
          InkWell(
            key: Key('task_cost_line_${shown[i].id.isEmpty ? i : shown[i].id}'),
            borderRadius: BorderRadius.circular(6),
            onTap: widget.onTap == null ? null : () => widget.onTap!(shown[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shown[i].title.trim().isEmpty ? 'Untitled task' : shown[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: crm.textPrimary,
                          ),
                        ),
                        if ([shown[i].phase, shown[i].department].any((s) => s.isNotEmpty))
                          Text(
                            [shown[i].phase, shown[i].department].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: crm.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    shown[i].hasCost ? rupees(shown[i].planned) : 'No cost yet',
                    key: Key('task_cost_amount_${shown[i].id.isEmpty ? i : shown[i].id}'),
                    style: TextStyle(
                      fontSize: shown[i].hasCost ? 12.5 : 11.5,
                      fontWeight: shown[i].hasCost ? FontWeight.w700 : FontWeight.w600,
                      color: shown[i].hasCost ? crm.textPrimary : amber,
                    ),
                  ),
                  if (widget.onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 16, color: crm.textSecondary),
                  ],
                ],
              ),
            ),
          ),
        if (hidden > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('task_cost_show_all'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                minimumSize: const Size(0, 30),
              ),
              onPressed: () => setState(() => _all = true),
              child: Text('Show all ${lines.length + widget.more} tasks', style: const TextStyle(fontSize: 12)),
            ),
          ),
        if (_all && widget.more > 0)
          Text(
            '… and ${widget.more} more.',
            key: const Key('task_cost_more'),
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
          ),
      ],
    );
  }
}

/// What a person chooses for one task's cost: how it is stated, and the hours an hours-based cost is worked out from.
typedef TaskCostChoice = ({TaskCostInput input, double hours});

/// A small dialog to give ONE task a cost — none, an amount, or hours × a rate — for places that have no cost boxes of their own (the
/// plan wizard). Returns what was chosen, or null when the person backs out.
Future<TaskCostChoice?> showTaskCostDialog(
  BuildContext context, {
  TaskCostInput initial = const TaskCostInput(),
  double initialHours = 0,
  String title = 'Planned cost',
}) {
  return showDialog<TaskCostChoice>(
    context: context,
    builder: (_) => _TaskCostDialog(
      title: title,
      initial: initial,
      initialHours: initialHours,
    ),
  );
}

class _TaskCostDialog extends StatefulWidget {
  const _TaskCostDialog({
    required this.title,
    required this.initial,
    required this.initialHours,
  });
  final String title;
  final TaskCostInput initial;
  final double initialHours;

  @override
  State<_TaskCostDialog> createState() => _TaskCostDialogState();
}

class _TaskCostDialogState extends State<_TaskCostDialog> {
  late String _mode = widget.initial.mode;
  late final TextEditingController _amount = TextEditingController(
    text: _plain(
      widget.initial.mode == TaskCostMode.amount ? widget.initial.amount : 0,
    ),
  );
  late final TextEditingController _rate = TextEditingController(
    text: _plain(
      widget.initial.mode == TaskCostMode.rate ? widget.initial.rate : 0,
    ),
  );
  late final TextEditingController _hours = TextEditingController(
    text: _plain(
      widget.initial.mode == TaskCostMode.rate ? widget.initialHours : 0,
    ),
  );
  String? _error;

  static String _plain(double v) => v <= 0
      ? ''
      : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _hours.dispose();
    super.dispose();
  }

  double? get _planned {
    if (_mode == TaskCostMode.amount) return parseAmount(_amount.text);
    if (_mode == TaskCostMode.rate) {
      return hoursTimesRate(_hours.text, _rate.text);
    }
    return null;
  }

  void _save() {
    if (_mode == TaskCostMode.amount) {
      final a = parseAmount(_amount.text);
      if (a == null || a <= 0) {
        setState(() => _error = 'Enter the cost as an amount above zero.');
        return;
      }
      Navigator.pop(context, (
        input: TaskCostInput(mode: _mode, amount: a),
        hours: 0.0,
      ));
    } else if (_mode == TaskCostMode.rate) {
      final r = parseAmount(_rate.text);
      final h = double.tryParse(_hours.text.trim());
      if (r == null || r <= 0 || h == null || h <= 0) {
        setState(() => _error = 'Enter the hours and the rate per hour.');
        return;
      }
      Navigator.pop(context, (
        input: TaskCostInput(mode: _mode, rate: r),
        hours: h,
      ));
    } else {
      Navigator.pop(context, (input: const TaskCostInput(), hours: 0.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final amountFilter = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    ];
    Widget chip(String key, String mode, String label) => ChoiceChip(
      key: Key('wizard_cost_mode_$key'),
      label: Text(label),
      selected: _mode == mode,
      onSelected: (_) => setState(() {
        _mode = mode;
        _error = null;
      }),
    );
    final planned = _planned;
    return AlertDialog(
      key: const Key('wizard_cost_dialog'),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  chip('none', TaskCostMode.none, 'No cost'),
                  chip('amount', TaskCostMode.amount, 'An amount'),
                  chip('rate', TaskCostMode.rate, 'Hours × rate'),
                ],
              ),
              if (_mode == TaskCostMode.amount) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('wizard_cost_amount'),
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: amountFilter,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(
                    labelText: 'Cost (₹)',
                    prefixText: '₹ ',
                  ),
                ),
              ],
              if (_mode == TaskCostMode.rate) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('wizard_cost_hours'),
                        controller: _hours,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: amountFilter,
                        onChanged: (_) => setState(() => _error = null),
                        decoration: const InputDecoration(labelText: 'Hours'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const Key('wizard_cost_rate'),
                        controller: _rate,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: amountFilter,
                        onChanged: (_) => setState(() => _error = null),
                        decoration: const InputDecoration(
                          labelText: 'Rate per hour (₹)',
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (planned != null && planned > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Planned cost: ${rupees(planned)}',
                    key: const Key('wizard_cost_preview'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: const Key('wizard_cost_error'),
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('wizard_cost_cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('wizard_cost_save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
