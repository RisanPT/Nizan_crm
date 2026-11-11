import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/consultation_provider.dart';
import '../../data/consultation.dart';
import '../../data/consultation_summary.dart';
import '../../data/stylist_client.dart';
import '../../services/consultation_service.dart';
import '../widgets/consultation_dialogs.dart';
import '../widgets/consultation_ui.dart';
import '../widgets/stylist_client_ui.dart';

/// Stylist "Today" page (SRS FR-13), built around one question: what needs me
/// now? A single list, most urgent first — calls that ended without an outcome,
/// today's calls, active clients with no call booked, then follow-ups — with
/// one button per row for the next step. Filter chips above it replace the old
/// summary tiles. Beside it (below on a phone): this week's calls and client
/// progress. The month report sits at the bottom, closed until opened; only it
/// follows the month picker.
class ConsultationsDashboardScreen extends ConsumerStatefulWidget {
  const ConsultationsDashboardScreen({super.key});

  @override
  ConsumerState<ConsultationsDashboardScreen> createState() => _ConsultationsDashboardScreenState();
}

/// Which part of "Needs you now" is shown.
enum _NowFilter { all, record, today, noCall, followUp }

class _ConsultationsDashboardScreenState extends ConsumerState<ConsultationsDashboardScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  _NowFilter _filter = _NowFilter.all;
  bool _reportOpen = false;

  /// Wide enough for the two-column layout.
  static const _wideBreakpoint = 760.0;
  static const _comingUpDays = 7;
  static const _clientsQuery = (q: '', company: '', status: 'Active', sort: 'event');

  SummaryQuery get _query => (
        from: ConsultationService.day(_month),
        to: ConsultationService.day(DateTime(_month.year, _month.month + 1, 0)),
      );

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months, 1));

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final query = _query;
    final async = ref.watch(consultationSummaryProvider(query));

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _wideBreakpoint;
      return Scaffold(
        backgroundColor: crm.background,
        floatingActionButton: wide
            ? null
            : FloatingActionButton.extended(
                onPressed: () => context.push('/consultations/new'),
                icon: const Icon(Icons.add),
                label: const Text('Schedule call'),
              ),
        body: Column(
          children: [
            _header(crm, async.value, wide),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(consultationSummaryProvider(query)),
                ),
                data: (s) => _body(crm, s, wide),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _header(CrmTheme crm, ConsultationSummary? s, bool wide) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final first = (ref.watch(authSessionProvider)?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final line = [
      DateFormat(wide ? 'EEEE, d MMMM' : 'EEE, d MMM').format(now),
      if (s != null) s.isTeam ? 'Whole team' : 'Your calls',
    ].join('  ·  ');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(first.isEmpty ? greeting : '$greeting, $first',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: crm.textPrimary)),
                  ],
                ),
              ),
              if (wide)
                FilledButton.icon(
                  onPressed: () => context.push('/consultations/new'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Schedule call'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────
  Widget _body(CrmTheme crm, ConsultationSummary s, bool wide) {
    final access = ref.watch(effectiveAccessProvider);
    final clientsAsync = ref.watch(stylistClientsProvider(_clientsQuery));
    final clients = clientsAsync.value ?? const <StylistClient>[];
    final items = _nowItems(s, clients, access);

    final now = DateTime.now();
    final weekEnd = DateTime(now.year, now.month, now.day + _comingUpDays + 1);
    final comingUp = s.upcoming.where((c) => c.scheduledAt.isBefore(weekEnd)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final laterCount = s.upcoming.length - comingUp.length;

    final needsNow = _needsNowCard(crm, items);
    final week = _card(
      crm,
      'This week',
      trailing: '${comingUp.length} ${comingUp.length == 1 ? 'call' : 'calls'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comingUp.isEmpty)
            _empty(crm, 'Nothing booked in the next $_comingUpDays days.')
          else
            _comingUp(crm, comingUp, showStylist: s.isTeam),
          _linkButton(
            laterCount > 0 ? '$laterCount more later · open calendar' : 'Open calendar',
            () => context.go('/consultations'),
          ),
        ],
      ),
    );
    final progress = _ClientsCard(activeClients: s.activeClients);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(consultationSummaryProvider(_query));
        ref.invalidate(stylistClientsProvider(_clientsQuery));
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // Room under the last card for the phone's Schedule button.
            padding: EdgeInsets.fromLTRB(16, 16, 16, wide ? 32 : 96),
            children: [
              if (items.isNotEmpty) ...[
                _filterChips(crm, items),
                const SizedBox(height: 12),
              ],
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: needsNow),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(children: [week, const SizedBox(height: 16), progress]),
                    ),
                  ],
                )
              else ...[
                needsNow,
                const SizedBox(height: 16),
                week,
                const SizedBox(height: 16),
                progress,
              ],
              const SizedBox(height: 16),
              _monthReport(crm, s, wide),
            ],
          ),
        ),
      ),
    );
  }

  // ── Needs you now ────────────────────────────────────────────────────────
  /// Everything that needs the stylist, most urgent first.
  List<_NowItem> _nowItems(ConsultationSummary s, List<StylistClient> clients, Access access) {
    final record = [...s.needsOutcome]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final recordIds = {for (final c in record) c.id};
    final today = s.today.where((c) => !recordIds.contains(c.id)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final noCall = clients.where((c) => c.isActive && c.progress.booked == 0 && !c.progress.seriesDone);
    final followUps = [...s.followUps]..sort((a, b) => (b.overdue ? 1 : 0) - (a.overdue ? 1 : 0));

    return [
      for (final c in record) _NowItem(_NowFilter.record, call: c),
      for (final c in today) _NowItem(_NowFilter.today, call: c),
      for (final c in noCall) _NowItem(_NowFilter.noCall, client: c),
      for (final f in followUps) _NowItem(_NowFilter.followUp, followUp: f, canOpenLead: access.canSeeSub('sales.leads')),
    ];
  }

  Widget _filterChips(CrmTheme crm, List<_NowItem> items) {
    int count(_NowFilter f) => items.where((i) => i.kind == f).length;
    final record = count(_NowFilter.record);
    final today = count(_NowFilter.today);
    final noCall = count(_NowFilter.noCall);
    final followUp = count(_NowFilter.followUp);
    final overdue = items.any((i) => i.followUp?.overdue ?? false);

    Widget chip(_NowFilter f, String label, {Color? tone}) => ChoiceChip(
          label: Text(label),
          selected: _filter == f,
          labelStyle: TextStyle(
            color: _filter == f ? crm.surface : (tone ?? crm.textPrimary),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          selectedColor: crm.primary,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() => _filter = _filter == f ? _NowFilter.all : f),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(_NowFilter.all, 'All ${items.length}'),
        if (record > 0) chip(_NowFilter.record, '$record to record', tone: crm.destructive),
        if (today > 0) chip(_NowFilter.today, '$today ${today == 1 ? 'call' : 'calls'} today'),
        if (noCall > 0) chip(_NowFilter.noCall, '$noCall ${noCall == 1 ? 'needs' : 'need'} a call', tone: crm.warning),
        if (followUp > 0)
          chip(_NowFilter.followUp, '$followUp ${followUp == 1 ? 'follow-up' : 'follow-ups'}',
              tone: overdue ? crm.destructive : null),
      ],
    );
  }

  Widget _needsNowCard(CrmTheme crm, List<_NowItem> items) {
    final shown = _filter == _NowFilter.all ? items : items.where((i) => i.kind == _filter).toList();
    return _card(
      crm,
      'Needs you now',
      trailing: items.isEmpty ? null : 'most urgent first',
      child: shown.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: crm.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      items.isEmpty ? "You're all caught up. Nothing needs you right now." : 'Nothing here.',
                      style: TextStyle(color: crm.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < shown.length; i++) _NowRow(item: shown[i], first: i == 0),
              ],
            ),
    );
  }

  // ── This week, grouped by day ─────────────────────────────────────────────
  Widget _comingUp(CrmTheme crm, List<Consultation> items, {required bool showStylist}) {
    final byDay = <DateTime, List<Consultation>>{};
    for (final c in items) {
      final d = DateTime(c.scheduledAt.year, c.scheduledAt.month, c.scheduledAt.day);
      byDay.putIfAbsent(d, () => []).add(c);
    }

    final days = byDay.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, entry) in days.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: i == 0 ? null : Border(top: BorderSide(color: crm.border.withValues(alpha: 0.7))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  child: Text(DateFormat('EEE d').format(entry.key),
                      style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary, fontSize: 13)),
                ),
                Expanded(
                  child: Column(
                    children: [
                      for (final c in entry.value)
                        InkWell(
                          onTap: () => context.push('/consultations/${c.id}'),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 64,
                                  child: Text(fmtTime(c.scheduledAt),
                                      style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                                ),
                                if (!c.client.isEmpty) ...[
                                  Tooltip(
                                    message: c.client.company,
                                    child: CircleAvatar(radius: 4, backgroundColor: companyColor(c.client.company)),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    [
                                      c.clientName.isEmpty ? 'Client' : c.clientName,
                                      if (c.callNumber != null) 'Call ${c.callNumber}',
                                      if (showStylist && c.stylistName.isNotEmpty) c.stylistName,
                                    ].join('  ·  '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: crm.textPrimary, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Month report (closed until opened) ───────────────────────────────────
  Widget _monthReport(CrmTheme crm, ConsultationSummary s, bool wide) {
    final ended = s.count('Completed') + s.count('No-show');
    final attended = ended == 0 ? null : (s.count('Completed') * 100 / ended).round();
    final summary = [
      '${s.total} ${s.total == 1 ? 'call' : 'calls'}',
      if (attended != null) '$attended% attended',
      if (wide && s.isTeam && s.perStylist.isNotEmpty) 'by stylist',
    ].join('  ·  ');

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _reportOpen = !_reportOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Month report · ${DateFormat('MMMM yyyy').format(_month)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: crm.textPrimary)),
                        const SizedBox(height: 2),
                        Text(summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(_reportOpen ? Icons.expand_less : Icons.expand_more, color: crm.textSecondary),
                ],
              ),
            ),
          ),
          if (_reportOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _shift(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(DateFormat('MMMM yyyy').format(_month),
                          style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => _shift(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _monthStats(crm, s, wide, attended),
                  const SizedBox(height: 20),
                  _subTitle(crm, 'Enquiries by status'),
                  _enquiryBars(crm, s),
                  if (s.isTeam && s.perStylist.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _subTitle(crm, 'By stylist'),
                    _stylistTable(crm, s),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _subTitle(CrmTheme crm, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: crm.textPrimary)),
      );

  Widget _monthStats(CrmTheme crm, ConsultationSummary s, bool wide, int? attended) {
    Widget stat(String label, String value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: crm.textSecondary, fontSize: 12)),
            ],
          ),
        );
    final first = [
      stat('Total', '${s.total}', crm.textPrimary),
      stat('Completed', '${s.count('Completed')}', consultationStatusColor('Completed')),
      stat('Scheduled', '${s.count('Scheduled')}', consultationStatusColor('Scheduled')),
    ];
    final second = [
      stat('No-shows', '${s.count('No-show')}', consultationStatusColor('No-show')),
      stat('Cancelled', '${s.count('Cancelled')}', consultationStatusColor('Cancelled')),
      stat('Attended', attended == null ? '—' : '$attended%', crm.textPrimary),
    ];
    return wide
        ? Row(children: [...first, ...second])
        : Column(children: [Row(children: first), const SizedBox(height: 14), Row(children: second)]);
  }

  // ── Shared pieces ────────────────────────────────────────────────────────
  Widget _card(CrmTheme crm, String title, {required Widget child, String? trailing}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
              Expanded(
                child: Text(title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary)),
              ),
              if (trailing != null)
                Text(trailing, style: TextStyle(color: crm.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _empty(CrmTheme crm, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: TextStyle(color: crm.textSecondary)),
      );

  Widget _enquiryBars(CrmTheme crm, ConsultationSummary s) {
    final entries = s.enquiryStatus.entries.toList();
    final maxValue = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    if (entries.isEmpty || maxValue == 0) return _empty(crm, 'No enquiries in this period.');

    return LayoutBuilder(
      builder: (context, box) {
        final labelWidth = box.maxWidth < 420 ? 130.0 : 180.0;
        return Column(
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: crm.textPrimary, fontSize: 13)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: e.value / maxValue,
                          minHeight: 10,
                          backgroundColor: crm.border.withValues(alpha: 0.4),
                          valueColor: AlwaysStoppedAnimation(clientStatusColor(e.key)),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('${e.value}',
                          textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _stylistTable(CrmTheme crm, ConsultationSummary s) {
    String rate(double? r) => r == null ? '—' : '${(r * 100).round()}%';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        columns: const [
          DataColumn(label: Text('Stylist')),
          DataColumn(label: Text('Total'), numeric: true),
          DataColumn(label: Text('Completed'), numeric: true),
          DataColumn(label: Text('No-show'), numeric: true),
          DataColumn(label: Text('Cancelled'), numeric: true),
          DataColumn(label: Text('Upcoming'), numeric: true),
          DataColumn(label: Text('Attended'), numeric: true),
        ],
        rows: [
          for (final r in s.perStylist)
            DataRow(cells: [
              DataCell(Text(r.name.isEmpty ? 'Unassigned' : r.name)),
              DataCell(Text('${r.total}')),
              DataCell(Text('${r.completed}')),
              DataCell(Text('${r.noShow}')),
              DataCell(Text('${r.cancelled}')),
              DataCell(Text('${r.scheduled}')),
              DataCell(Text(rate(r.attendedRate))),
            ]),
        ],
      ),
    );
  }
}

Widget _linkButton(String label, VoidCallback onPressed) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_forward, size: 16),
        label: Text(label),
      ),
    );

/// "today 4:00 PM", "yesterday 4:00 PM" or "8 Nov, 4:00 PM".
String _when(DateTime d) {
  final now = DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  final prefix = diff == 0
      ? 'today'
      : diff == 1
          ? 'yesterday'
          : diff == -1
              ? 'tomorrow'
              : '${fmtShortDay(d)},';
  return '$prefix ${fmtTime(d)}';
}

/// One entry on "Needs you now": exactly one of [call], [client] or
/// [followUp] is set, matching [kind].
class _NowItem {
  const _NowItem(this.kind, {this.call, this.client, this.followUp, this.canOpenLead = false});

  final _NowFilter kind;
  final Consultation? call;
  final StylistClient? client;
  final PendingFollowUp? followUp;
  final bool canOpenLead;
}

/// A row on "Needs you now": a time or badge on the left, who and why in the
/// middle, and the one button for the next step on the right.
class _NowRow extends ConsumerWidget {
  const _NowRow({required this.item, required this.first});

  final _NowItem item;
  final bool first;

  Future<void> _invite(BuildContext context, WidgetRef ref, Consultation c) async {
    try {
      final opened = await openWhatsAppInvite(c);
      if (!opened) {
        if (context.mounted) showWarningSnackBar(context, 'Could not open WhatsApp for this number');
        return;
      }
      await ref.read(consultationServiceProvider).markInviteSent(c.id);
      ref.refreshData.consultations();
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxWidth < 420;
      final (lead, title, company, sub, subTone, action, onTap) = switch (item.kind) {
        _NowFilter.record => _record(context, crm, item.call!, compact),
        _NowFilter.today => _today(context, ref, crm, item.call!, compact),
        _NowFilter.noCall => _noCall(context, crm, item.client!),
        _ => _followUp(context, crm, item.followUp!),
      };
      final muted = item.call?.status == 'Cancelled';
      final name = Text(
        title.isEmpty ? 'Client' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: muted ? crm.textSecondary : crm.textPrimary,
          decoration: muted ? TextDecoration.lineThrough : null,
        ),
      );
      final subtitle = sub.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subTone ?? crm.textSecondary, fontSize: 12)),
            );

      // Phone: time or badge sits inline before the name, and a company dot
      // replaces the tag, so each row stays two lines.
      final Widget middle = compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.kind == _NowFilter.today)
                      Text(fmtTime(item.call!.scheduledAt),
                          style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary, fontSize: 13))
                    else
                      lead,
                    const SizedBox(width: 6),
                    if (company.isNotEmpty) ...[
                      Tooltip(
                        message: company,
                        child: CircleAvatar(radius: 4, backgroundColor: companyColor(company)),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(child: name),
                  ],
                ),
                ?subtitle,
              ],
            )
          : Row(
              children: [
                SizedBox(width: 72, child: Align(alignment: Alignment.centerLeft, child: lead)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [name, CompanyTag(company)],
                      ),
                      ?subtitle,
                    ],
                  ),
                ),
              ],
            );

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: first ? null : Border(top: BorderSide(color: crm.border.withValues(alpha: 0.7))),
          ),
          child: Row(
            children: [
              Expanded(child: middle),
              const SizedBox(width: 8),
              action,
            ],
          ),
        ),
      );
    });
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _time(CrmTheme crm, Consultation c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fmtTime(c.scheduledAt),
              style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary, fontSize: 13)),
          Text('${c.durationMins} min', style: TextStyle(color: crm.textSecondary, fontSize: 11)),
        ],
      );

  _RowParts _record(BuildContext context, CrmTheme crm, Consultation c, bool compact) {
    void open() => context.push('/consultations/${c.id}/details?complete=1');
    return (
      _badge('Ended', crm.destructive),
      c.clientName,
      c.client.company,
      [if (c.callLabel.isNotEmpty) c.callLabel, _when(c.scheduledAt)].join('  ·  '),
      null,
      FilledButton(onPressed: open, child: Text(compact ? 'Record' : 'Record outcome')),
      open,
    );
  }

  _RowParts _today(BuildContext context, WidgetRef ref, CrmTheme crm, Consultation c, bool compact) {
    final ended = c.endsAt.isBefore(DateTime.now());
    final noLink = c.isVideo && c.meetingLink.isEmpty;
    final noInvite = c.inviteSentAt == null;
    final sub = [
      if (c.callLabel.isNotEmpty) c.callLabel,
      if (!compact) c.isVideo ? 'Video' : 'In-person',
      if (c.isScheduled && !ended && noLink)
        'Link missing'
      else if (c.isScheduled && !ended && noInvite)
        'Invite not sent',
    ].join('  ·  ');

    Widget action;
    if (!c.isScheduled) {
      action = ConsultationStatusChip(c.status);
    } else if (ended) {
      action = FilledButton(
        onPressed: () => context.push('/consultations/${c.id}/details?complete=1'),
        child: Text(compact ? 'Record' : 'Record outcome'),
      );
    } else if (noLink) {
      action = OutlinedButton(onPressed: () => showEditMeetingDialog(context, c), child: const Text('Add link'));
    } else if (noInvite) {
      action = OutlinedButton.icon(
        onPressed: () => _invite(context, ref, c),
        icon: const Icon(Icons.send_outlined, size: 16),
        label: Text(compact ? 'Invite' : 'Send invite'),
      );
    } else if (c.isVideo) {
      action = FilledButton.icon(
        onPressed: () => launchUrl(Uri.parse(c.meetingLink), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.videocam_outlined, size: 18),
        label: const Text('Join'),
      );
    } else {
      action = OutlinedButton(onPressed: () => context.push('/consultations/${c.id}'), child: const Text('Open'));
    }
    return (
      _time(crm, c),
      c.clientName,
      c.client.company,
      sub,
      null,
      action,
      () => context.push('/consultations/${c.id}'),
    );
  }

  _RowParts _noCall(BuildContext context, CrmTheme crm, StylistClient c) {
    final days = c.daysToEvent;
    final event = [
      if (c.eventType.isNotEmpty) c.eventType,
      if (days != null) fmtDaysToEvent(days).toLowerCase(),
    ].join(' ');
    return (
      _badge('No call', crm.warning),
      c.name,
      c.company,
      [if (event.isNotEmpty) event, '${c.progress.done} of ${c.requiredCalls} done'].join('  ·  '),
      null,
      OutlinedButton(
        onPressed: () => context.push('/consultations/new?clientId=${c.id}'),
        child: const Text('Schedule'),
      ),
      () => context.push('/stylist/clients/${c.id}'),
    );
  }

  _RowParts _followUp(BuildContext context, CrmTheme crm, PendingFollowUp f) {
    final when = f.followUpDate == null ? '' : 'Follow-up ${fmtShortDay(f.followUpDate!)}, ${fmtTime(f.followUpDate!)}';
    return (
      f.overdue ? _badge('Overdue', crm.destructive) : _badge('Follow-up', crm.textSecondary),
      f.name,
      '',
      when.isEmpty ? f.phone : when,
      null,
      f.phone.isEmpty
          ? const SizedBox.shrink()
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'WhatsApp',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chat_outlined, size: 20),
                  onPressed: () => launchUrl(Uri.https('wa.me', '/${whatsAppNumber(f.phone)}'),
                      mode: LaunchMode.externalApplication),
                ),
                IconButton(
                  tooltip: 'Call',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.call_outlined, size: 20),
                  onPressed: () => launchUrl(Uri.parse('tel:${f.phone}')),
                ),
              ],
            ),
      item.canOpenLead && f.leadId.isNotEmpty ? () => context.push('/sales/leads/${f.leadId}') : null,
    );
  }
}

/// lead, title, company, subtitle, subtitle colour, action, onTap.
typedef _RowParts = (Widget, String, String, String, Color?, Widget, VoidCallback?);

/// Active clients by soonest event, with call progress and their next call.
/// Clients with no call booked are on "Needs you now", so they are not
/// repeated at the top here.
class _ClientsCard extends ConsumerWidget {
  const _ClientsCard({required this.activeClients});

  final int activeClients;

  static const _query = (q: '', company: '', status: 'Active', sort: 'event');
  static const _shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(stylistClientsProvider(_query));
    final all = async.value ?? const <StylistClient>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
              Expanded(
                child: Text('Client progress',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary)),
              ),
              Text('$activeClients active', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          if (async.isLoading && all.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
          else if (async.hasError)
            AppErrorView(error: async.error, compact: true, onRetry: () => ref.invalidate(stylistClientsProvider(_query)))
          else if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('No active clients yet.', style: TextStyle(color: crm.textSecondary)),
            )
          else
            for (var i = 0; i < all.length && i < _shown; i++) _clientRow(context, crm, all[i], i == 0),
          _linkButton(all.length > _shown ? 'See all ${all.length} clients' : 'Open clients',
              () => context.go('/stylist/clients')),
        ],
      ),
    );
  }

  Widget _clientRow(BuildContext context, CrmTheme crm, StylistClient c, bool first) {
    final days = c.daysToEvent;
    final event = [
      if (c.eventType.isNotEmpty) c.eventType,
      if (days != null) fmtDaysToEvent(days).toLowerCase(),
    ].join(' ');
    final next = c.progress.nextCallAt;
    final needsCall = c.progress.booked == 0 && !c.progress.seriesDone;
    return InkWell(
      onTap: () => context.push('/stylist/clients/${c.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: crm.border.withValues(alpha: 0.7))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      CompanyTag(c.company),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (needsCall)
                        'No call booked'
                      else if (next != null)
                        'Next call ${fmtShortDay(next)}',
                      if (event.isNotEmpty) event,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: needsCall ? crm.warning : crm.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CallProgressDots(done: c.progress.done, required: c.requiredCalls, size: 8),
          ],
        ),
      ),
    );
  }
}
