import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/ceo/data/decision_models.dart';
import 'package:nizan_crm/features/ceo/services/decision_service.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show kDashBad, kDashGood;

/// What has to come to the CEO / Executive Director, set by hand. Nothing is escalated until an amount is entered: a blank limit
/// is off. The team checks an item first (Accounts, HR, the finance head), and only then does it come to a leader.
class DecisionRulesScreen extends ConsumerStatefulWidget {
  const DecisionRulesScreen({super.key});

  @override
  ConsumerState<DecisionRulesScreen> createState() => _DecisionRulesScreenState();
}

class _DecisionRulesScreenState extends ConsumerState<DecisionRulesScreen> {
  final _expense = TextEditingController();
  final _payout = TextEditingController();
  final _budget = TextEditingController();
  bool _hiring = false;
  bool _loaded = false;
  bool _saving = false;
  String? _error;
  String? _errorField;
  DecisionPolicy? _saved;

  @override
  void dispose() {
    _expense.dispose();
    _payout.dispose();
    _budget.dispose();
    super.dispose();
  }

  String _text(double? v) => v == null ? '' : NumberFormat.decimalPattern('en_IN').format(v.round());

  void _load(DecisionPolicy p) {
    _saved = p;
    _expense.text = _text(p.expense);
    _payout.text = _text(p.payout);
    _budget.text = _text(p.projectBudget);
    _hiring = p.hiringPlansNeedLeadership;
    _loaded = true;
  }

  /// null = blank (off). A value that is not a number is returned as NaN so the form can say so.
  double? _amount(TextEditingController c) {
    final t = c.text.replaceAll(RegExp(r'[₹,\s]'), '');
    if (t.isEmpty) return null;
    return double.tryParse(t) ?? double.nan;
  }

  bool get _dirty {
    final p = _saved;
    if (p == null) return false;
    bool same(double? a, double? b) => (a == null && b == null) || (a != null && b != null && (a - b).abs() < 0.5);
    return !(same(_amount(_expense), p.expense) && same(_amount(_payout), p.payout) && same(_amount(_budget), p.projectBudget) && _hiring == p.hiringPlansNeedLeadership);
  }

  Future<void> _save() async {
    final e = _amount(_expense), p = _amount(_payout), b = _amount(_budget);
    if ([e, p, b].any((v) => v != null && v.isNaN)) {
      setState(() {
        _error = 'Enter amounts as numbers, or leave a box blank to switch it off.';
        _errorField = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _errorField = null;
    });
    try {
      final saved = await ref.read(decisionServiceProvider).savePolicy(expense: e, payout: p, projectBudget: b, hiring: _hiring);
      ref.invalidate(decisionPolicyProvider);
      if (!mounted) return;
      setState(() => _load(saved));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved.on ? 'Saved. ${saved.summary}' : 'Saved. Nothing is escalated.')));
    } on DecisionConflict catch (c) {
      if (mounted) {
        setState(() {
          _error = c.message;
          _errorField = c.field;
        });
      }
    } catch (err) {
      if (mounted) showErrorSnackBar(context, err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final access = ref.watch(effectiveAccessProvider);
    final policy = ref.watch(decisionPolicyProvider);
    return policy.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(decisionPolicyProvider)),
      data: (p) {
        if (!_loaded) _load(p);
        final canEdit = access.canEditDecisionRules && p.canEdit;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
              children: [
                Text('Decision rules', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text('Choose what has to come to the CEO or the Executive Director. The team checks it first (Accounts, HR, the finance head); only then does it reach a leader.',
                    style: TextStyle(fontSize: 13, color: crm.textSecondary)),
                const SizedBox(height: 14),
                Container(
                  key: const Key('rules_summary'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: (p.on ? kDashGood : crm.textSecondary).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(p.on ? Icons.rule_rounded : Icons.do_not_disturb_on_outlined, size: 18, color: p.on ? kDashGood : crm.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.on ? 'Currently: ${p.summary}' : 'Currently: nothing is escalated.', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary))),
                  ]),
                ),
                if (!p.hasLeadership)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      key: const Key('rules_no_leader'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: kDashBad.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                      child: const Text('There is no CEO or Executive Director login yet, so nothing could be decided. Create one first, then set these rules.', style: TextStyle(color: kDashBad)),
                    ),
                  ),
                const SizedBox(height: 18),
                _label(crm, 'Send to a leader when…'),
                _field(key: 'rules_expense', c: _expense, label: 'A department expense is above', field: 'expense', enabled: canEdit),
                _field(key: 'rules_payout', c: _payout, label: 'An artist payout is above', field: 'payout', enabled: canEdit),
                _field(key: 'rules_budget', c: _budget, label: 'A project budget goes up by more than', field: 'projectBudget', enabled: canEdit, helper: 'Only the increase counts; a first approval counts from zero.'),
                SwitchListTile(
                  key: const Key('rules_hiring'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Every hiring plan needs their approval'),
                  subtitle: const Text('HR vets the plan, then the CEO or Executive Director approves it.'),
                  value: _hiring,
                  onChanged: canEdit ? (v) => setState(() => _hiring = v) : null,
                ),
                Text('A blank amount is off. An amount applies to each item on its own, not added up, and only to what is above it.', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                if (_error != null)
                  Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, key: const Key('rules_error'), style: const TextStyle(color: kDashBad, fontWeight: FontWeight.w600))),
                const SizedBox(height: 16),
                if (canEdit)
                  FilledButton(
                    key: const Key('rules_save'),
                    onPressed: _dirty && !_saving ? _save : null,
                    child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save rules'),
                  )
                else
                  Text('Only an administrator, the CEO or the Executive Director can change these.', key: const Key('rules_read_only'), style: TextStyle(color: crm.textSecondary)),
                if (p.updatedByName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Last changed by ${p.updatedByName}${p.updatedAt == null ? '' : ' · ${DateFormat('d MMM yyyy').format(p.updatedAt!)}'}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ),
                if (p.history.length > 1) ...[
                  const SizedBox(height: 10),
                  _label(crm, 'Earlier changes'),
                  for (final h in p.history.skip(1))
                    Text('${h.at == null ? '' : DateFormat('d MMM yyyy').format(h.at!)} · ${h.byName}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(CrmTheme crm, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
      );

  Widget _field({required String key, required TextEditingController c, required String label, required String field, required bool enabled, String? helper}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: Key(key),
          controller: c,
          enabled: enabled,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            prefixText: '₹ ',
            hintText: 'Off',
            helperText: helper,
            errorText: _errorField == field ? _error : null,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}
