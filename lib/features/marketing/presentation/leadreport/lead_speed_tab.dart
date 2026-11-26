import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/lead_speed_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_detail_sheet.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';

/// Lead Report → Speed to lead: how long leads that came in on their own (an ad form, the website) waited for their first contact —
/// counted in working minutes, so a form filled at night is not "late" by morning. Who is waiting right now, the median time and the
/// share inside the target, by salesperson and by source, and the slowest first contacts. A lead left waiting past the alert time tells
/// its salesperson and the sales managers (once). A Marketing Manager sets the target, the alert time and the working hours.
class LeadSpeedTab extends ConsumerStatefulWidget {
  const LeadSpeedTab({super.key});

  @override
  ConsumerState<LeadSpeedTab> createState() => _LeadSpeedTabState();
}

class _LeadSpeedTabState extends ConsumerState<LeadSpeedTab> {
  String _scope = 'auto';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leadSpeedProvider(_scope));
    return RefreshIndicator(
      onRefresh: () async => refreshLeadReport(ref),
      child: ListView(
        key: const Key('lr_speed_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            MktFilterChip(key: const Key('lr_speed_scope_auto'), label: 'Came in on their own', selected: _scope == 'auto', onTap: () => setState(() => _scope = 'auto')),
            MktFilterChip(key: const Key('lr_speed_scope_all'), label: 'All leads', selected: _scope == 'all', onTap: () => setState(() => _scope = 'all')),
            if (async.value?.settings.canEdit == true)
              TextButton.icon(key: const Key('lr_speed_settings'), onPressed: () => _editSettings(context, async.value!.settings), icon: const Icon(Icons.tune_rounded, size: 17), label: const Text('Target & alerts')),
          ]),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 90), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => refreshLeadReport(ref)),
            data: (d) => _body(context, d),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, LeadSpeed d) {
    final k = d.kpis;
    final p = d.previous;
    final st = d.settings;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MktKpiRow(minWidth: 168, children: [
        leadKpi(key: 'lr_speed_median', icon: Icons.timer_outlined, label: 'Median time to first contact', value: workingTime(k.medianMinutes), note: p.medianMinutes == null ? 'Working time' : 'Before: ${workingTime(p.medianMinutes)}', tint: Mkt.primary),
        leadKpi(key: 'lr_speed_within', icon: Icons.bolt_outlined, label: 'Inside ${st.targetMinutes} min', value: k.withinPct == null ? '—' : '${k.withinPct}%', note: p.withinPct == null ? 'Of those contacted' : 'Before: ${p.withinPct}%', tint: Mkt.good),
        leadKpi(key: 'lr_speed_contacted', icon: Icons.call_outlined, label: 'Contacted', value: '${k.contacted} of ${k.leads}', note: k.unrecorded > 0 ? '${k.unrecorded} moved on with no contact recorded' : 'Leads in the range', tint: Mkt.blue),
        leadKpi(key: 'lr_speed_waiting', icon: Icons.hourglass_top_rounded, label: 'Waiting now', value: '${k.waiting}', note: k.late > 0 ? '${k.late} past the target' : 'Not contacted yet', tint: k.late > 0 ? Mkt.bad : Mkt.warn),
      ]),
      const SizedBox(height: 6),
      Text(
        'Counted in working time, ${st.dayStart}–${st.dayEnd} IST. First contact = the first call, message or follow-up logged on the lead, or its first move out of New. ${st.alertsOn ? 'A lead waiting ${st.alertAfterMinutes} working minutes alerts its salesperson and the sales managers.' : 'Alerts are off.'}',
        key: const Key('lr_speed_note'),
        style: mktText(11.5, color: Mkt.inkSoft),
      ),
      const SizedBox(height: 12),
      MktCard(
        title: 'Waiting now',
        subtitle: d.waiting.isEmpty ? 'Nobody is waiting' : 'Longest wait first',
        icon: Icons.hourglass_top_rounded,
        child: d.waiting.isEmpty
            ? MktEmpty(k.leads == 0 ? 'No lead came in on its own in these days.' : 'Every lead in the range has been contacted.', icon: Icons.check_circle_outline_rounded, height: 90)
            : Column(children: [
                for (final w in d.waiting)
                  InkWell(
                    key: Key('lr_speed_wait_${w.id}'),
                    onTap: () => showLeadDetail(context, w.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Icon(Icons.circle, size: 9, color: w.late ? Mkt.bad : Mkt.warn),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w700)),
                            Text('${w.source} · ${w.assignee}${w.alerted ? ' · alert sent' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft)),
                          ]),
                        ),
                        Text(workingTime(w.waitingMinutes), style: mktText(13, weight: FontWeight.w800, color: w.late ? Mkt.bad : Mkt.ink)),
                      ]),
                    ),
                  ),
              ]),
      ),
      const SizedBox(height: 12),
      MktGrid(breakpoint: 900, rows: [
        [(6, _groupCard('By salesperson', 'lr_speed_person', d.byPerson, st)), (6, _groupCard('By source', 'lr_speed_source', d.bySource, st))],
      ]),
      if (d.slowest.isNotEmpty) ...[
        const SizedBox(height: 12),
        MktCard(
          title: 'Slowest first contacts',
          icon: Icons.slow_motion_video_outlined,
          child: MktTable(
            minWidth: 560,
            columns: const [MktCol('Lead', flex: 3), MktCol('Source', flex: 2), MktCol('Salesperson', flex: 2), MktCol('First contact', flex: 2), MktCol('Waited', flex: 2, align: Alignment.centerRight)],
            rowKeys: [for (final s in d.slowest) Key('lr_speed_slow_${s.id}')],
            onRowTap: (i) => showLeadDetail(context, d.slowest[i].id),
            rows: [
              for (final s in d.slowest)
                [lrCell(s.name, bold: true), lrCell(s.source), lrCell(s.assignee), lrCell([if (s.firstVia.isNotEmpty) s.firstVia == 'status' ? 'moved on' : s.firstVia, if (s.firstBy.isNotEmpty) 'by ${s.firstBy}'].join(' ')), lrCell(workingTime(s.minutes), bold: true)],
            ],
          ),
        ),
      ],
    ]);
  }

  Widget _groupCard(String title, String key, List<SpeedGroup> groups, SpeedSettings st) => MktCard(
        title: title,
        icon: Icons.groups_outlined,
        child: groups.isEmpty
            ? MktEmpty('No leads in these days.', icon: Icons.inbox_outlined, height: 80)
            : MktTable(
                minWidth: 460,
                columns: [const MktCol('Name', flex: 3), const MktCol('Leads', align: Alignment.centerRight), const MktCol('Median', flex: 2, align: Alignment.centerRight), MktCol('≤ ${st.targetMinutes} min', flex: 2, align: Alignment.centerRight), const MktCol('Waiting', align: Alignment.centerRight)],
                rowKeys: [for (final g in groups) Key('${key}_${g.name}')],
                rows: [
                  for (final g in groups)
                    [
                      lrCell(g.name, bold: true),
                      lrCell('${g.stats.leads}'),
                      lrCell(workingTime(g.stats.medianMinutes)),
                      lrCell(g.stats.withinPct == null ? '—' : '${g.stats.withinPct}%'),
                      lrCell('${g.stats.waiting}', color: g.stats.late > 0 ? Mkt.bad : Mkt.ink, bold: g.stats.late > 0),
                    ],
                ],
              ),
      );

  Future<void> _editSettings(BuildContext context, SpeedSettings s) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _SpeedSettingsDialog(settings: s));
    if (saved == true) refreshLeadReport(ref);
  }
}

class _SpeedSettingsDialog extends ConsumerStatefulWidget {
  const _SpeedSettingsDialog({required this.settings});
  final SpeedSettings settings;
  @override
  ConsumerState<_SpeedSettingsDialog> createState() => _SpeedSettingsDialogState();
}

class _SpeedSettingsDialogState extends ConsumerState<_SpeedSettingsDialog> {
  late final _target = TextEditingController(text: '${widget.settings.targetMinutes}');
  late final _alert = TextEditingController(text: '${widget.settings.alertAfterMinutes}');
  late final _start = TextEditingController(text: widget.settings.dayStart);
  late final _end = TextEditingController(text: widget.settings.dayEnd);
  late bool _on = widget.settings.alertsOn;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_target, _alert, _start, _end]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(leadReportServiceProvider).saveSpeedSettings({'targetMinutes': int.tryParse(_target.text.trim()) ?? -1, 'alertAfterMinutes': int.tryParse(_alert.text.trim()) ?? -1, 'dayStart': _start.text.trim(), 'dayEnd': _end.text.trim(), 'alertsOn': _on});
      if (mounted) Navigator.pop(context, true);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() => (_error = r.message, _saving = false));
    } catch (e) {
      if (mounted) setState(() => (_error = friendlyErrorMessage(e), _saving = false));
    }
  }

  InputDecoration _dec(String label, {String? suffix, String? hint}) => InputDecoration(labelText: label, suffixText: suffix, hintText: hint, isDense: true, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: const Text('Speed to lead'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: TextField(key: const Key('lr_speed_set_target'), controller: _target, keyboardType: TextInputType.number, inputFormatters: digits, decoration: _dec('Target', suffix: 'min'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(key: const Key('lr_speed_set_alert'), controller: _alert, keyboardType: TextInputType.number, inputFormatters: digits, decoration: _dec('Alert after', suffix: 'min'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(key: const Key('lr_speed_set_start'), controller: _start, decoration: _dec('Working from', hint: '09:00'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(key: const Key('lr_speed_set_end'), controller: _end, decoration: _dec('Working until', hint: '21:00'))),
          ]),
          SwitchListTile(key: const Key('lr_speed_set_on'), contentPadding: EdgeInsets.zero, title: const Text('Alert when a new lead waits'), value: _on, onChanged: (v) => setState(() => _on = v)),
          Text('Waiting is counted only in these hours (IST), every day.', style: mktText(11.5, color: Mkt.inkSoft)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('lr_speed_set_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(key: const Key('lr_speed_set_save'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
