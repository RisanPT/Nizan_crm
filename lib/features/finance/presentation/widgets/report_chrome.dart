import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

/// Company name printed on report headers. Set this to your registered business
/// name (shown centered above each statement, like Zoho Books).
const String kReportCompanyName = 'Team N ERP';

/// The books are kept on an accrual basis (posted double-entry vouchers).
const String kReportBasis = 'Accrual';

String _d(DateTime? d) => d == null ? '' : DateFormat('dd/MM/yyyy').format(d);

enum DateRangePreset {
  thisMonth,
  previousMonth,
  thisQuarter,
  thisFy,
  previousFy,
  allTime,
  custom,
}

String presetLabel(DateRangePreset p) => switch (p) {
      DateRangePreset.thisMonth => 'This Month',
      DateRangePreset.previousMonth => 'Previous Month',
      DateRangePreset.thisQuarter => 'This Quarter',
      DateRangePreset.thisFy => 'This Fiscal Year',
      DateRangePreset.previousFy => 'Previous Fiscal Year',
      DateRangePreset.allTime => 'All Time',
      DateRangePreset.custom => 'Custom',
    };

/// From/To for a preset. Indian fiscal year (April–March). `custom` returns
/// nulls — the caller supplies the range via a picker.
({DateTime? from, DateTime? to}) rangeForPreset(DateRangePreset p, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime mStart(int y, int m) => DateTime(y, m, 1);
  DateTime mEnd(int y, int m) => DateTime(y, m + 1, 0);
  int fyStart(DateTime d) => d.month >= 4 ? d.year : d.year - 1;
  switch (p) {
    case DateRangePreset.thisMonth:
      return (from: mStart(now.year, now.month), to: mEnd(now.year, now.month));
    case DateRangePreset.previousMonth:
      final m = DateTime(now.year, now.month - 1, 1);
      return (from: mStart(m.year, m.month), to: mEnd(m.year, m.month));
    case DateRangePreset.thisQuarter:
      final startM = ((now.month - 1) ~/ 3) * 3 + 1;
      return (from: mStart(now.year, startM), to: mEnd(now.year, startM + 2));
    case DateRangePreset.thisFy:
      return (from: DateTime(fyStart(now), 4, 1), to: today);
    case DateRangePreset.previousFy:
      final y = fyStart(now) - 1;
      return (from: DateTime(y, 4, 1), to: DateTime(y + 1, 3, 31));
    case DateRangePreset.allTime:
    case DateRangePreset.custom:
      return (from: null, to: null);
  }
}

/// Zoho-style report scaffold: a header (category • date range + Export/Refresh),
/// a "Date Range :" filter row with a preset dropdown, and the report [child].
/// Add [ReportTitleBlock] as the first item of the child's scroll view.
class ReportChrome extends StatelessWidget {
  const ReportChrome({
    super.key,
    required this.category,
    required this.title,
    required this.preset,
    required this.onPreset,
    required this.child,
    this.asOf = false,
    this.from,
    this.to,
    this.onExport,
    this.onRefresh,
  });

  final String category;
  final String title;
  final bool asOf; // true → "As on <to>"; false → "From <from> To <to>"
  final DateRangePreset preset;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateRangePreset> onPreset;
  final VoidCallback? onExport;
  final Future<void> Function()? onRefresh;
  final Widget child;

  String get _rangeText {
    if (asOf) return to == null ? 'All dates' : 'As on ${_d(to)}';
    if (from == null && to == null) return 'All dates';
    return 'From ${_d(from)} To ${_d(to)}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header: category breadcrumb + date-range subtitle + actions.
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
        decoration: BoxDecoration(
          color: crm.surface,
          border: Border(bottom: BorderSide(color: crm.border.faded(0.6))),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(category.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
              2.h,
              Row(children: [
                Flexible(
                  child: Text(title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: crm.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                8.w,
                Text('• $_rangeText',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ]),
          ),
          if (onExport != null)
            TextButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export'),
            ),
          if (onRefresh != null)
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => onRefresh!(),
              icon: Icon(Icons.refresh, size: 20, color: crm.textSecondary),
            ),
        ]),
      ),
      // Filters row.
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        color: crm.background,
        child: Row(children: [
          Icon(Icons.filter_alt_outlined, size: 16, color: crm.textSecondary),
          8.w,
          Text('Date Range :', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
          8.w,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.border.faded(0.8)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateRangePreset>(
                value: preset,
                isDense: true,
                borderRadius: BorderRadius.circular(10),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                items: [
                  for (final p in DateRangePreset.values)
                    DropdownMenuItem(value: p, child: Text(presetLabel(p))),
                ],
                onChanged: (p) => p == null ? null : onPreset(p),
              ),
            ),
          ),
        ]),
      ),
      Expanded(child: child),
    ]);
  }
}

/// The centered company / title / basis / date block printed atop a statement.
class ReportTitleBlock extends StatelessWidget {
  const ReportTitleBlock({
    super.key,
    required this.title,
    this.subtitle,
    this.asOf = false,
    this.from,
    this.to,
  });

  final String title;
  final String? subtitle; // e.g. the account name on an Account Transactions view
  final bool asOf;
  final DateTime? from;
  final DateTime? to;

  String get _rangeText {
    if (asOf) return to == null ? 'All dates' : 'As on ${_d(to)}';
    if (from == null && to == null) return 'All dates';
    return 'From ${_d(from)} To ${_d(to)}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        if (kReportCompanyName.isNotEmpty)
          Text(kReportCompanyName.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: crm.textSecondary)),
        6.h,
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: crm.textPrimary)),
        4.h,
        Text('Basis : $kReportBasis',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          6.h,
          Text(subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        ],
        2.h,
        Text(_rangeText,
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        14.h,
      ]),
    );
  }
}
