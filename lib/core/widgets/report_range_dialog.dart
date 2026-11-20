import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';

// "WHICH DATES?" — the question every report download asks. Quick choices (Today … Last financial year, All time) and a Custom range
// from a calendar; the answer is a [ReportRange] of whole days, both ends inclusive (core/utils/report_range.dart).

/// The presets offered unless a screen asks for others. All time is only offered when [allowAll] says the report can be unbounded.
List<ReportPreset> defaultReportPresets({bool allowAll = false}) => [
  ReportPreset.today,
  ReportPreset.yesterday,
  ReportPreset.last7,
  ReportPreset.last30,
  ReportPreset.thisMonth,
  ReportPreset.lastMonth,
  ReportPreset.thisFy,
  ReportPreset.lastFy,
  if (allowAll) ReportPreset.all,
  ReportPreset.custom,
];

/// Asks which dates to download for. Returns the chosen days, or null when the person backs out.
///
/// [initial] is what is chosen to begin with (the screen's own period, so "Download" matches what is on screen unless they change it).
Future<ReportRange?> showReportRangeDialog(
  BuildContext context, {
  String title = 'Choose the dates',
  String? subtitle,
  String confirmLabel = 'Download',
  ReportRange? initial,
  bool allowAll = false,
  List<ReportPreset>? presets,
  DateTime? firstDate,
  DateTime? lastDate,

  /// The most days the report can cover (the server refuses more): a longer choice is said so, and cannot be downloaded.
  int? maxDays,

  /// What "today" is — for tests.
  DateTime? now,
}) {
  return showDialog<ReportRange>(
    context: context,
    builder: (_) => ReportRangeDialog(
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      initial: initial,
      presets: presets ?? defaultReportPresets(allowAll: allowAll),
      firstDate: firstDate,
      lastDate: lastDate,
      maxDays: maxDays,
      now: now,
    ),
  );
}

class ReportRangeDialog extends StatefulWidget {
  const ReportRangeDialog({
    super.key,
    this.title = 'Choose the dates',
    this.subtitle,
    this.confirmLabel = 'Download',
    this.initial,
    required this.presets,
    this.firstDate,
    this.lastDate,
    this.maxDays,
    this.now,
  });
  final String title;
  final String? subtitle;
  final String confirmLabel;
  final ReportRange? initial;
  final List<ReportPreset> presets;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final int? maxDays;
  final DateTime? now;

  @override
  State<ReportRangeDialog> createState() => _ReportRangeDialogState();
}

class _ReportRangeDialogState extends State<ReportRangeDialog> {
  late ReportRange _range;
  late ReportPreset _preset;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final start = widget.initial;
    if (start != null) {
      _range = start;
      // which chip it matches, if any (a screen's month is "This month" when it is the current one)
      _preset =
          widget.presets
              .where(
                (p) =>
                    p != ReportPreset.custom &&
                    reportRangeFor(p, _now) == start,
              )
              .firstOrNull ??
          (start.isAll ? ReportPreset.all : ReportPreset.custom);
      if (!widget.presets.contains(_preset)) _preset = ReportPreset.custom;
    } else {
      _preset = widget.presets.contains(ReportPreset.thisMonth)
          ? ReportPreset.thisMonth
          : widget.presets.first;
      _range = reportRangeFor(_preset, _now);
    }
  }

  Future<void> _pick(ReportPreset p) async {
    if (p != ReportPreset.custom) {
      setState(() {
        _preset = p;
        _range = reportRangeFor(p, _now);
      });
      return;
    }
    final today = dayOf(_now);
    final picked = await showBrandedDateRangePicker(
      context,
      initialDateRange: _range.asDateTimeRange,
      firstDate: widget.firstDate ?? DateTime(2020),
      lastDate: widget.lastDate ?? DateTime(today.year + 2, 12, 31),
      helpText: 'Download from – to',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preset = ReportPreset.custom;
      _range = ReportRange(
        from: picked.start,
        to: picked.end,
        preset: ReportPreset.custom,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final days = _range.days;
    final max = widget.maxDays;
    // all time, or more days than the report can hold
    final tooLong = max != null && (_range.isAll || (days != null && days > max));
    return AlertDialog(
      key: const Key('report_range_dialog'),
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.subtitle != null) ...[
                Text(
                  widget.subtitle!,
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in widget.presets)
                    ChoiceChip(
                      key: Key('report_range_chip_${p.name}'),
                      label: Text(
                        p == ReportPreset.custom &&
                                _preset == ReportPreset.custom
                            ? 'Custom: ${_range.label}'
                            : p.label,
                      ),
                      avatar: p == ReportPreset.custom
                          ? const Icon(Icons.date_range_rounded, size: 16)
                          : null,
                      selected: _preset == p,
                      onSelected: (_) => _pick(p),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: crm.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: crm.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 18,
                      color: crm.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _range.label,
                        key: const Key('report_range_summary'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: crm.textPrimary,
                        ),
                      ),
                    ),
                    if (days != null)
                      Text(
                        '$days ${days == 1 ? 'day' : 'days'}',
                        key: const Key('report_range_days'),
                        style: TextStyle(
                          fontSize: 12,
                          color: tooLong ? crm.destructive : crm.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (tooLong) ...[
                const SizedBox(height: 8),
                Text(
                  'This report covers at most $max days at a time — choose fewer.',
                  key: const Key('report_range_too_long'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.destructive),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('report_range_cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('report_range_confirm'),
          onPressed: tooLong ? null : () => Navigator.pop(context, _range.ordered),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// The dates chosen so far, as a tappable row for a download form: tap it to change them with [showReportRangeDialog]. Keeps a form
/// that already has its own fields (format, artist …) to one line for the dates.
class ReportRangeTile extends StatelessWidget {
  const ReportRangeTile({
    super.key,
    required this.range,
    required this.onChanged,
    this.allowAll = false,
    this.label = 'Dates',
    this.enabled = true,
    this.presets,
    this.firstDate,
    this.lastDate,
    this.maxDays,
  });
  final ReportRange range;
  final ValueChanged<ReportRange> onChanged;
  final bool allowAll;
  final String label;
  final bool enabled;
  final List<ReportPreset>? presets;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final int? maxDays;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final days = range.days;
    return InkWell(
      key: const Key('report_range_tile'),
      borderRadius: BorderRadius.circular(12),
      onTap: !enabled
          ? null
          : () async {
              final picked = await showReportRangeDialog(
                context,
                title: 'Choose the dates',
                confirmLabel: 'Use these dates',
                initial: range,
                allowAll: allowAll,
                presets: presets,
                firstDate: firstDate,
                lastDate: lastDate,
                maxDays: maxDays,
              );
              if (picked != null) onChanged(picked);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded, size: 20, color: crm.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary, letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(
                    range.label,
                    key: const Key('report_range_tile_label'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary),
                  ),
                ],
              ),
            ),
            if (days != null) Text('$days ${days == 1 ? 'day' : 'days'}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            const SizedBox(width: 8),
            Icon(Icons.edit_calendar_outlined, size: 18, color: enabled ? crm.textSecondary : crm.border),
          ],
        ),
      ),
    );
  }
}
