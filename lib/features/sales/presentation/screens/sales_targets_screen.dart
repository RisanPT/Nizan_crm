import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/sales/data/sales_target.dart';
import 'package:nizan_crm/features/sales/presentation/widgets/my_target_card.dart';
import 'package:nizan_crm/features/sales/services/sales_target_service.dart';

/// Sales → Sales Targets. A sales manager sets each salesperson's monthly
/// target (₹ value and/or number of bookings) and sees achievement live.
class SalesTargetsScreen extends ConsumerStatefulWidget {
  const SalesTargetsScreen({super.key});

  @override
  ConsumerState<SalesTargetsScreen> createState() => _SalesTargetsScreenState();
}

class _Edit {
  final TextEditingController value;
  final TextEditingController count;
  final TextEditingController note;
  _Edit(SalesTarget? t)
      : value = TextEditingController(text: t == null || t.salesTarget <= 0 ? '' : t.salesTarget.round().toString()),
        count = TextEditingController(text: t == null || t.bookingsTarget <= 0 ? '' : '${t.bookingsTarget}'),
        note = TextEditingController(text: t?.note ?? '');

  double get valueNum => double.tryParse(value.text.trim()) ?? 0;
  int get countNum => int.tryParse(count.text.trim()) ?? 0;

  bool differsFrom(SalesTarget? t) =>
      valueNum != (t?.salesTarget ?? 0) || countNum != (t?.bookingsTarget ?? 0) || note.text.trim() != (t?.note ?? '');

  void dispose() {
    value.dispose();
    count.dispose();
    note.dispose();
  }
}

class _SalesTargetsScreenState extends ConsumerState<SalesTargetsScreen> {
  late TargetPeriod _period = (month: DateTime.now().month, year: DateTime.now().year);
  final Map<String, _Edit> _edits = {};
  TargetPeriod? _editsFor;
  bool _saving = false;
  String _search = '';

  @override
  void dispose() {
    for (final e in _edits.values) {
      e.dispose();
    }
    super.dispose();
  }

  void _resetEdits() {
    for (final e in _edits.values) {
      e.dispose();
    }
    _edits.clear();
    _editsFor = null;
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved targets?'),
        content: const Text('You have changed targets that are not saved yet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _shift(int delta) async {
    if (!await _confirmDiscard()) return;
    final d = DateTime(_period.year, _period.month + delta);
    setState(() {
      _resetEdits();
      _period = (month: d.month, year: d.year);
    });
  }

  TeamTargets? get _data => ref.read(teamTargetsProvider(_period)).value;

  bool get _hasChanges {
    final data = _data;
    if (data == null) return false;
    return data.rows.any((r) => _edits[r.userId]?.differsFrom(r.target) ?? false);
  }

  Future<void> _save() async {
    final data = _data;
    if (data == null) return;
    final changed = [
      for (final r in data.rows)
        if (_edits[r.userId]?.differsFrom(r.target) ?? false)
          SalesTargetInput(
            userId: r.userId,
            salesTarget: _edits[r.userId]!.valueNum,
            bookingsTarget: _edits[r.userId]!.countNum,
            note: _edits[r.userId]!.note.text.trim(),
          ),
    ];
    if (changed.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(salesTargetServiceProvider).save(_period, changed);
      setState(_resetEdits);
      ref.invalidate(teamTargetsProvider(_period));
      ref.invalidate(myTargetProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${changed.length} target${changed.length == 1 ? '' : 's'}')),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy() async {
    if (!await _confirmDiscard()) return;
    try {
      final n = await ref.read(salesTargetServiceProvider).copyLastMonth(_period);
      setState(_resetEdits);
      ref.invalidate(teamTargetsProvider(_period));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n == 0
              ? 'Nothing to copy — last month had no targets, or everyone already has one.'
              : 'Copied $n target${n == 1 ? '' : 's'} from last month'),
        ));
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final role = ref.watch(authSessionProvider)?.role;
    if (!canSetSalesTargets(role)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Only sales managers can set targets. Your own target is on My Dashboard.',
              textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
        ),
      );
    }

    final async = ref.watch(teamTargetsProvider(_period));
    final data = async.value;
    if (data != null && _editsFor != _period) {
      _resetEdits();
      for (final r in data.rows) {
        _edits[r.userId] = _Edit(r.target);
      }
      _editsFor = _period;
    }

    return Scaffold(
      backgroundColor: crm.background,
      body: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 760;
        final pad = compact ? 12.0 : 24.0;
        return Column(children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (!await _confirmDiscard()) return;
                setState(_resetEdits);
                ref.invalidate(teamTargetsProvider(_period));
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
                children: [
                  _header(crm, compact),
                  const SizedBox(height: 14),
                  async.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => AppErrorView(
                      error: e,
                      onRetry: () => ref.invalidate(teamTargetsProvider(_period)),
                    ),
                    data: (d) => _body(crm, d, compact),
                  ),
                ],
              ),
            ),
          ),
          if (data != null) _saveBar(crm),
        ]);
      }),
    );
  }

  Widget _header(CrmTheme crm, bool compact) {
    final nav = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton.filledTonal(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
      SizedBox(
        width: 150,
        child: Text(DateFormat('MMMM yyyy').format(DateTime(_period.year, _period.month)),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
      ),
      IconButton.filledTonal(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
    ]);
    final copy = OutlinedButton.icon(
      onPressed: _copy,
      icon: const Icon(Icons.content_copy_rounded, size: 18),
      label: const Text('Copy last month'),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sales Targets', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary)),
      Text('Set each salesperson’s monthly target. Achieved = bookings made this month, net of discount.',
          style: TextStyle(fontSize: 13, color: crm.textSecondary)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: nav),
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: compact ? 200 : 240,
              child: TextField(
                onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Search salesperson…',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
              ),
            ),
            copy,
          ]),
        ],
      ),
    ]);
  }

  Widget _body(CrmTheme crm, TeamTargets d, bool compact) {
    final elapsed = d.daysInMonth == 0 ? 1.0 : (d.daysInMonth - d.daysLeft) / d.daysInMonth;
    final expected = d.daysLeft == 0 ? 1.0 : elapsed;
    final teamPct = d.salesTarget > 0 ? d.salesValue / d.salesTarget : 0.0;
    final rows = d.rows.where((r) => _search.isEmpty || r.name.toLowerCase().contains(_search)).toList();

    final summary = [
      ('Team target', targetRupees(d.salesTarget), Icons.flag_rounded, crm.primary, null),
      ('Achieved', targetRupees(d.salesValue), Icons.trending_up_rounded,
          targetStatusColor(teamPct, expectedPct: expected), d.salesTarget > 0 ? teamPct : null),
      ('Bookings', d.bookingsTarget > 0 ? '${d.bookings} / ${d.bookingsTarget}' : '${d.bookings}',
          Icons.event_available_rounded, const Color(0xFF7C3AED), null),
      ('Days left', '${d.daysLeft}', Icons.calendar_today_rounded, const Color(0xFF0D9488), null),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, c) {
        final per = c.maxWidth >= 900 ? 4 : 2;
        final w = (c.maxWidth - 10 * (per - 1)) / per;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (label, value, icon, color, pct) in summary)
            Container(
              width: w,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    ),
                    if (pct != null) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0, 1).toDouble(),
                          minHeight: 4,
                          backgroundColor: color.withValues(alpha: 0.15),
                          color: color,
                        ),
                      ),
                      Text('${(pct * 100).toStringAsFixed(0)}% of team target',
                          style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                    ],
                  ]),
                ),
              ]),
            ),
        ]);
      }),
      const SizedBox(height: 16),
      if (rows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            d.rows.isEmpty ? 'No salespeople found. Users with a sales role appear here.' : 'No one matches the search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: crm.textSecondary),
          ),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crm.border),
          ),
          child: Column(children: [
            if (!compact) _tableHeader(crm),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0 || !compact) Divider(height: 1, color: crm.border),
              _row(crm, rows[i], compact, expected),
            ],
          ]),
        ),
    ]);
  }

  Widget _tableHeader(CrmTheme crm) {
    TextStyle s = TextStyle(fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: crm.textSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(children: [
        Expanded(flex: 4, child: Text('SALESPERSON', style: s)),
        Expanded(flex: 3, child: Text('₹ TARGET', style: s)),
        Expanded(flex: 2, child: Text('BOOKINGS TARGET', style: s)),
        Expanded(flex: 5, child: Text('ACHIEVED', style: s)),
      ]),
    );
  }

  Widget _row(CrmTheme crm, TeamTargetRow r, bool compact, double expected) {
    final e = _edits[r.userId];
    if (e == null) return const SizedBox.shrink();
    final changed = e.differsFrom(r.target);
    final target = e.valueNum;
    final pct = target > 0 ? r.achieved.salesValue / target : null;
    final countTarget = e.countNum;
    final countPct = countTarget > 0 ? r.achieved.bookings / countTarget : null;
    final color = targetStatusColor(pct ?? countPct ?? 0, expectedPct: expected);

    InputDecoration deco(String hint, {String? prefix}) => InputDecoration(
          isDense: true,
          hintText: hint,
          prefixText: prefix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        );
    final valueField = TextField(
      controller: e.value,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      decoration: deco('No target', prefix: '₹ '),
    );
    final countField = TextField(
      controller: e.count,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      decoration: deco('—'),
    );

    final name = Row(children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: crm.primary.withValues(alpha: 0.12),
        child: Text(r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(r.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
            ),
            if (changed) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Not saved yet',
                child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle)),
              ),
            ],
          ]),
          Text(
            [r.role.replaceAll('_', ' '), if (!r.active) 'inactive'].join(' · '),
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
          ),
        ]),
      ),
    ]);

    final achieved = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(targetRupees(r.achieved.salesValue),
            style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
        Text('  ·  ${r.achieved.bookings} booking${r.achieved.bookings == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        const Spacer(),
        if (pct != null)
          Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (pct ?? countPct ?? 0).clamp(0, 1).toDouble(),
          minHeight: 6,
          backgroundColor: crm.input,
          color: pct == null && countPct == null ? crm.border : color,
        ),
      ),
      if (pct == null && countPct == null)
        Text('No target set', style: TextStyle(fontSize: 11.5, color: crm.textSecondary))
      else if (countPct != null)
        Text('Bookings ${r.achieved.bookings} / $countTarget',
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
    ]);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          name,
          const SizedBox(height: 10),
          Row(children: [
            Expanded(flex: 3, child: valueField),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: countField),
          ]),
          const SizedBox(height: 10),
          achieved,
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(flex: 4, child: name),
        Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(right: 12), child: valueField)),
        Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(right: 16), child: countField)),
        Expanded(flex: 5, child: achieved),
      ]),
    );
  }

  Widget _saveBar(CrmTheme crm) {
    final changes = _hasChanges;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(top: BorderSide(color: crm.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: Text(
              changes ? 'You have unsaved target changes.' : 'Targets are up to date.',
              style: TextStyle(fontSize: 13, color: changes ? const Color(0xFFD97706) : crm.textSecondary),
            ),
          ),
          if (changes)
            TextButton(
              onPressed: _saving ? null : () => setState(_resetEdits),
              child: const Text('Undo'),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: !changes || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save targets'),
          ),
        ]),
      ),
    );
  }
}
