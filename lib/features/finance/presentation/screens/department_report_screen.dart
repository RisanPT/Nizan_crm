import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/dept_report.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/month_year_picker.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';

const _monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Finance → Departmental Month-End Review. One config-driven screen for any of
/// the 7 departments: auto-computed metrics render read-only, everything the CRM
/// doesn't track yet is a manual field. Part B (targets + action items) saves
/// alongside.
class DepartmentReportScreen extends ConsumerStatefulWidget {
  const DepartmentReportScreen({super.key, required this.dept});
  final String dept;

  @override
  ConsumerState<DepartmentReportScreen> createState() => _DepartmentReportScreenState();
}

class _DepartmentReportScreenState extends ConsumerState<DepartmentReportScreen> {
  late int _month;
  late int _year;
  String? _loadedFor; // "dept-month-year" currently populated

  final Map<String, TextEditingController> _values = {};
  final Map<String, TextEditingController> _targets = {};
  final _notes = TextEditingController();
  List<({TextEditingController text, TextEditingController owner})> _actions = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
  }

  @override
  void dispose() {
    for (final c in _values.values) {
      c.dispose();
    }
    for (final c in _targets.values) {
      c.dispose();
    }
    _notes.dispose();
    for (final a in _actions) { a.text.dispose(); a.owner.dispose(); }
    super.dispose();
  }

  DeptPeriod get _key => (dept: widget.dept, month: _month, year: _year);
  String get _stamp => '${widget.dept}-$_month-$_year';

  void _shift(int d) => setState(() {
        var m = _month + d, y = _year;
        if (m < 1) { m = 12; y--; }
        if (m > 12) { m = 1; y++; }
        _month = m; _year = y; _loadedFor = null;
      });

  Future<void> _pickMonth() async {
    final p = await showMonthYearPicker(context, month: _month, year: _year);
    if (p != null) setState(() { _month = p.month; _year = p.year; _loadedFor = null; });
  }

  void _populate(DeptReport r) {
    for (final c in _values.values) { c.dispose(); }
    for (final c in _targets.values) { c.dispose(); }
    for (final a in _actions) { a.text.dispose(); a.owner.dispose(); }
    _values.clear();
    _targets.clear();
    for (final metric in r.manualMetrics) {
      _values[metric.key] = TextEditingController(text: metric.hasValue ? metric.value.toString() : '');
    }
    for (final t in r.targetsConfig) {
      final v = r.targets[t.key];
      _targets[t.key] = TextEditingController(text: v == null ? '' : v.toString());
    }
    _notes.text = r.notes;
    _actions = r.actionItems
        .map((a) => (text: TextEditingController(text: a.text), owner: TextEditingController(text: a.owner)))
        .toList();
    _loadedFor = _stamp;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(departmentReportProvider(_key));
    async.whenData((r) {
      if (_loadedFor != _stamp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _loadedFor != _stamp) setState(() => _populate(r));
        });
      }
    });

    return Scaffold(
      backgroundColor: crm.background,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          _monthBar(crm, null),
          AppErrorView(error: e, onRetry: () => ref.invalidate(departmentReportProvider(_key))),
        ]),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
          children: [
            _monthBar(crm, r),
            12.h,
            if (r.kpis.isNotEmpty) _kpiStrip(crm, r),
            14.h,
            for (final s in r.sections) _sectionCard(crm, s),
            12.h,
            _planningCard(crm, r),
            18.h,
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Save ${r.label} report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthBar(CrmTheme crm, DeptReport? r) {
    final label = r?.label ?? widget.dept;
    return Row(children: [
      IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
      Expanded(
        child: InkWell(
          onTap: _pickMonth,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              Text('$label — Month-End Review',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${_monthNames[_month]} $_year',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                4.w,
                Icon(Icons.arrow_drop_down, color: crm.textSecondary),
              ]),
            ]),
          ),
        ),
      ),
      IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
    ]);
  }

  Widget _kpiStrip(CrmTheme crm, DeptReport r) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: r.kpis.length,
        separatorBuilder: (_, _) => 10.w,
        itemBuilder: (_, i) {
          final k = r.kpis[i];
          return Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: crm.border.faded(0.6)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(k.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              6.h,
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(k.display, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: k.hasValue ? crm.textPrimary : crm.textSecondary)),
              ),
              if (!k.auto) Text('manual', style: TextStyle(fontSize: 9.5, color: crm.textSecondary)),
            ]),
          );
        },
      ),
    );
  }

  Widget _sectionCard(CrmTheme crm, DeptSection s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border.faded(0.6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          10.h,
          for (final metric in s.metrics) _metricRow(crm, metric),
        ]),
      ),
    );
  }

  Widget _metricRow(CrmTheme crm, DeptMetric metric) {
    if (metric.auto) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text(metric.label, style: TextStyle(fontSize: 13.5, color: crm.textSecondary))),
          Text(metric.display, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          6.w,
          Icon(Icons.bolt, size: 13, color: crm.success),
        ]),
      );
    }
    // Manual metric → inline editable.
    final ctrl = _values[metric.key];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(metric.label, style: TextStyle(fontSize: 13.5, color: crm.textSecondary))),
        8.w,
        SizedBox(
          width: metric.isText ? 150 : 110,
          child: TextField(
            controller: ctrl,
            textAlign: metric.isText ? TextAlign.start : TextAlign.end,
            keyboardType: metric.isText
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: metric.isText ? null : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              hintText: _unitHint(metric.unit),
              prefixText: metric.unit == 'inr' ? '₹' : null,
              suffixText: metric.unit == 'pct' ? '%' : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ]),
    );
  }

  String _unitHint(String unit) => switch (unit) {
        'inr' => '0',
        'pct' => '0',
        'count' => '0',
        'days' => 'days',
        'ratio' => '0.0',
        _ => 'enter…',
      };

  Widget _planningCard(CrmTheme crm, DeptReport r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.primary.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.flag_outlined, size: 18, color: crm.primary),
          8.w,
          Text('Next-Month Planning', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        ]),
        4.h,
        Text('Targets, action items and notes for the planning meeting.',
            style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        14.h,
        Text('MONTHLY TARGETS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
        8.h,
        for (final t in r.targetsConfig)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _targets[t.key],
              keyboardType: t.unit == 'text' ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: t.unit == 'text' ? null : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: t.label,
                prefixText: t.unit == 'inr' ? '₹' : null,
                suffixText: t.unit == 'pct' ? '%' : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        14.h,
        Row(children: [
          Text('ACTION ITEMS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _actions.add((text: TextEditingController(), owner: TextEditingController()))),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          ),
        ]),
        for (var i = 0; i < _actions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(flex: 3, child: TextField(controller: _actions[i].text, decoration: const InputDecoration(hintText: 'Action item', border: OutlineInputBorder(), isDense: true))),
              8.w,
              Expanded(flex: 2, child: TextField(controller: _actions[i].owner, decoration: const InputDecoration(hintText: 'Owner', border: OutlineInputBorder(), isDense: true))),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
                onPressed: () => setState(() { _actions[i].text.dispose(); _actions[i].owner.dispose(); _actions.removeAt(i); }),
              ),
            ]),
          ),
        12.h,
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes / strategic decisions', border: OutlineInputBorder(), isDense: true),
        ),
      ]),
    );
  }

  double? _numOrNull(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim());

  Future<void> _save() async {
    setState(() => _saving = true);
    // Manual metric values: number when parseable, else raw text.
    final values = <String, dynamic>{};
    _values.forEach((k, c) {
      final t = c.text.trim();
      if (t.isEmpty) return;
      values[k] = _numOrNull(t) ?? t;
    });
    final targets = <String, dynamic>{};
    _targets.forEach((k, c) {
      final t = c.text.trim();
      if (t.isEmpty) return;
      targets[k] = _numOrNull(t) ?? t;
    });
    final actions = _actions
        .where((a) => a.text.text.trim().isNotEmpty)
        .map((a) => DeptActionItem(text: a.text.text.trim(), owner: a.owner.text.trim()))
        .toList();
    try {
      await ref.read(monthEndServiceProvider).saveDepartmentReport(
            widget.dept,
            month: _month,
            year: _year,
            values: values,
            targets: targets,
            allocations: const [],
            actionItems: actions,
            notes: _notes.text.trim(),
          );
      ref.refreshData.monthEnd();
      if (mounted) showSuccessSnackBar(context, 'Saved');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
