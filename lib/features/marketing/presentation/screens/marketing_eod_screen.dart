import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/export_utils.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import '../../data/marketing_eod_models.dart';
import '../../services/marketing_eod_service.dart';
import '../../utils/marketing_eod_pdf.dart';
import '../widgets/marketing_eod_panels.dart';
import '../team/team_activity_tab.dart' show MyDayPanel;

class MarketingEodScreen extends ConsumerStatefulWidget {
  const MarketingEodScreen({super.key, this.initialTab = ''});

  /// The tab to open on (`/marketing/eod?tab=setup` — the sidebar's "Setup" link); else the first.
  final String initialTab;

  @override
  ConsumerState<MarketingEodScreen> createState() => _MarketingEodScreenState();
}

class _MarketingEodScreenState extends ConsumerState<MarketingEodScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDate;
  late String _selectedMonth; // YYYY-MM
  String? _selectedMemberId; // For manager viewing other members

  /// The eight tabs, in the order the [TabBarView] below lays them out.
  static const _tabSpecs = [
    MktTabSpec('log', 'Log Activity', Icons.edit_calendar_outlined),
    MktTabSpec('mine', 'My Dashboard', Icons.person_outline),
    MktTabSpec('team', 'Team Dashboards', Icons.people_outline),
    MktTabSpec('summary', 'Team Summary', Icons.table_chart_outlined),
    MktTabSpec('missed', 'Missed EODs', Icons.warning_amber_rounded),
    MktTabSpec('weekly', 'Weekly Stats', Icons.analytics_outlined),
    MktTabSpec('setup', 'Setup', Icons.tune_outlined),
    MktTabSpec('close', 'Month Close', Icons.verified_outlined),
  ];

  /// Every tab's content sits inside the page's 16px inset.
  static const _pad = EdgeInsets.fromLTRB(16, 4, 16, 32);

  @override
  void initState() {
    super.initState();
    final start = _tabSpecs.indexWhere((t) => t.id == widget.initialTab);
    _tabController = TabController(length: _tabSpecs.length, vsync: this, initialIndex: start < 0 ? 0 : start);
    _selectedDate = DateTime.now();
    _selectedMonth = DateFormat('yyyy-MM').format(_selectedDate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeMonth(int monthDelta) {
    setState(() {
      final parts = _selectedMonth.split('-');
      var y = int.parse(parts[0]);
      var m = int.parse(parts[1]) + monthDelta;
      if (m > 12) {
        y++;
        m = 1;
      } else if (m < 1) {
        y--;
        m = 12;
      }
      _selectedMonth = '$y-${m.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final accessAsync = ref.watch(marketingEodAccessProvider);
    final access = accessAsync.value ?? const MarketingEodAccess();
    final isManagerOrAdmin = access.isManager;
    final canViewTeam = access.canViewTeam;
    final accessReady = accessAsync.hasValue || accessAsync.hasError;

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 10),
            Expanded(
              child: !accessReady
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        const MyDayPanel(),
                        _buildIndividualDashboardTab(isMobile, forSelf: true),
                        canViewTeam
                            ? _buildIndividualDashboardTab(isMobile, forSelf: false)
                            : _restricted('Team dashboards are for the Marketing Manager and Management.'),
                        canViewTeam
                            ? _buildTeamSummaryTab(isMobile)
                            : _restricted('The Team Summary is for the Marketing Manager and Management.'),
                        canViewTeam
                            ? _buildMissedEodsTab(isMobile, isManagerOrAdmin)
                            : _restricted('Missed-EOD tracking is for the Marketing Manager and Management.'),
                        _buildWeeklyStatsTab(isMobile, access),
                        isManagerOrAdmin
                            ? _buildSetupTab(isMobile)
                            : _restricted('Setup is for the Marketing Manager and Admin.'),
                        isManagerOrAdmin
                            ? _buildMonthCloseTab(isMobile)
                            : _restricted('Month close is for the Marketing Manager.'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restricted(String message) {
    return ListView(
      padding: _pad,
      children: [
        MktCard(
          title: 'Restricted',
          icon: Icons.lock_outline,
          child: MktEmpty(message, icon: Icons.lock_outline, height: 120),
        ),
      ],
    );
  }

  /// The page header (icon tile, title, the month switcher) and the pill tabs under it.
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MktHeader(
            icon: Icons.assessment_outlined,
            title: 'EOD & Team Log',
            subtitle: 'Daily activity logging · Role profiles · Individual dashboards · Team summary',
            actions: [_monthSwitcher()],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) => MktTabPills(
              keyPrefix: 'eod_tab',
              tabs: _tabSpecs,
              selected: _tabSpecs[_tabController.index].id,
              onSelect: (id) => _tabController.animateTo(_tabSpecs.indexWhere((t) => t.id == id)),
            ),
          ),
        ],
      ),
    );
  }

  /// "‹ 2026-11 ›" — the month every tab reads.
  Widget _monthSwitcher() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Mkt.card,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Mkt.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18, color: Mkt.inkSoft),
            onPressed: () => _changeMonth(-1),
            tooltip: 'Previous Month',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
          ),
          Text(_selectedMonth, style: mktText(12.5, weight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18, color: Mkt.inkSoft),
            onPressed: () => _changeMonth(1),
            tooltip: 'Next Month',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 1: DAILY EOD ENTRY (FR-5, FR-6, FR-7)
  // ==========================================================================

  Future<String?> _askReason(String title, String hint) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    final text = c.text.trim();
    c.dispose();
    if (ok != true || text.isEmpty) return null;
    return text;
  }

  Widget _buildIndividualDashboardTab(bool isMobile, {required bool forSelf}) {
    final setupAsync = ref.watch(marketingEodSetupProvider);
    final members = setupAsync.value?.members ?? [];
    final effectiveMemberId = forSelf
        ? null
        : (_selectedMemberId ?? (members.isNotEmpty ? members.first.id : null));
    final query = (month: _selectedMonth, memberId: effectiveMemberId);
    final dashAsync = ref.watch(marketingIndividualDashboardProvider(query));

    return dashAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        title: "Couldn't load the dashboard",
        onRetry: () => ref.invalidate(marketingIndividualDashboardProvider(query)),
      ),
      data: (data) {
        final showPicker = !forSelf && setupAsync.hasValue;
        final tiles = data.summaryTiles;
        return ListView(
          padding: _pad,
          children: [
            // Member switcher (for the manager view) + PDF actions.
            _headerWithActions(
              isMobile,
              _titleBlock('${data.member.name} (${data.member.role ?? ""})', 'Period: ${data.period}'),
              [
                if (showPicker && members.isNotEmpty)
                  _memberPicker(members, effectiveMemberId ?? data.member.id, (val) => setState(() => _selectedMemberId = val)),
                MktPill(label: 'PDF', icon: Icons.download, trailing: false, onTap: () => downloadIndividualDashboardPdf(data)),
                MktPrimaryButton(label: 'Print', icon: Icons.print, onPressed: () => printIndividualDashboardPdf(data)),
              ],
            ),
            const SizedBox(height: 14),

            // Summary KPI tiles (FR-8)
            MktKpiRow(
              children: [
                MktKpiCard(icon: Icons.today, value: tiles['daysReported']?.toString() ?? '—', label: 'Days Reported', tint: Mkt.primary),
                MktKpiCard(icon: Icons.done_all, value: tiles['totalOutput']?.toString() ?? '0', label: 'Total Output', tint: Mkt.blue),
                MktKpiCard(
                  icon: Icons.stars,
                  value: '${tiles['targetAchievedPct'] ?? 0}%',
                  label: 'Target Achieved',
                  tint: _scoreColor(tiles['targetAchievedPct'] as int? ?? 0),
                ),
                MktKpiCard(
                  icon: Icons.speed,
                  value: tiles['mtdPacePct'] != null ? '${tiles['mtdPacePct']}%' : '—',
                  label: 'MTD vs Expected (${tiles['workingDaysElapsed'] ?? 0}/${tiles['workingDays'] ?? 0} days)',
                  tint: tiles['mtdPacePct'] != null ? _scoreColor((tiles['mtdPacePct'] as num).toInt()) : Mkt.primary,
                ),
                MktKpiCard(icon: Icons.schedule, value: tiles['hoursWorked']?.toString() ?? '—', label: 'Hours Worked', tint: Mkt.teal),
              ],
            ),
            const SizedBox(height: 12),

            // Table 1: Activity Numbers — Target vs Achieved (FR-8)
            MktCard(
              title: 'Activity Numbers - Target vs Achieved',
              icon: Icons.flag_outlined,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Mkt.bg),
                  columns: const [
                    DataColumn(label: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Target', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('Achieved', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('Achieved %', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('Expected by Today', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('MTD vs Expected', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('Daily Avg', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('Best Day', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: data.activityNumbers.map((row) {
                    return DataRow(cells: [
                      DataCell(Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(row.groupName)),
                      DataCell(Text(row.target != null ? row.target!.toStringAsFixed(0) : '—')),
                      DataCell(Text(row.achieved.toStringAsFixed(0))),
                      DataCell(Text(row.achievedPct != null ? '${row.achievedPct}%' : '—')),
                      DataCell(Text(row.expectedToDate != null ? row.expectedToDate!.toStringAsFixed(1) : '—')),
                      DataCell(row.pacePct != null
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${row.pacePct}%  '),
                              _statusBadge(row.paceStatus),
                            ])
                          : const Text('—')),
                      DataCell(Text(row.dailyAvg)),
                      DataCell(Text(row.bestDay['count'] != null && row.bestDay['count'] > 0
                          ? '${row.bestDay['count']} (${row.bestDay['date']?.toString().split('-').last ?? ""})'
                          : '—')),
                      DataCell(_statusBadge(row.status)),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Table 2: Week-wise Activity Numbers (FR-8)
            MktCard(
              title: 'Week-wise Activity Numbers (Fixed Date Blocks)',
              icon: Icons.view_week_outlined,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Mkt.bg),
                  columns: const [
                    DataColumn(label: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('W1 (01-07)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('W2 (08-14)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('W3 (15-21)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('W4 (22-28)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('W5 (29-31)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('Month Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  ],
                  rows: [
                    ...data.weekWiseRows.map((w) {
                      return DataRow(cells: [
                        DataCell(Text(w.name)),
                        DataCell(Text(w.w1.toStringAsFixed(0))),
                        DataCell(Text(w.w2.toStringAsFixed(0))),
                        DataCell(Text(w.w3.toStringAsFixed(0))),
                        DataCell(Text(w.w4.toStringAsFixed(0))),
                        DataCell(Text(w.w5.toStringAsFixed(0))),
                        DataCell(Text(w.monthTotal.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                      ]);
                    }),
                    // Total Output Row
                    DataRow(
                      color: WidgetStateProperty.all(Mkt.primarySoft),
                      cells: [
                        DataCell(Text('TOTAL OUTPUT', style: mktText(14, weight: FontWeight.bold, color: Mkt.primary))),
                        DataCell(Text(data.totalOutputRow.w1.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(data.totalOutputRow.w2.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(data.totalOutputRow.w3.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(data.totalOutputRow.w4.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(data.totalOutputRow.w5.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(data.totalOutputRow.monthTotal.toStringAsFixed(0), style: mktText(14, weight: FontWeight.bold, color: Mkt.primary))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Interactive Daily Calendar Output Grid (FR-8)
            MktCard(
              title: 'Daily Output Calendar Grid',
              icon: Icons.grid_view_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _gridLegendItem(Mkt.good, 'Reported'),
                      _gridLegendItem(Mkt.bad, 'Missed EOD'),
                      _gridLegendItem(Mkt.grey, 'Off / Sunday'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.dailyGrid.map((d) {
                      Color tileColor = Mkt.bg;
                      Color textColor = Mkt.ink;
                      if (d.color == 'green') {
                        tileColor = Mkt.tint(Mkt.good, 0.15);
                        textColor = Mkt.good;
                      } else if (d.color == 'red') {
                        tileColor = Mkt.tint(Mkt.bad, 0.15);
                        textColor = Mkt.bad;
                      } else if (d.color == 'grey') {
                        tileColor = Mkt.tint(Mkt.grey);
                        textColor = Mkt.inkSoft;
                      }

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDate = DateTime.parse(d.date);
                            _tabController.animateTo(0); // Jump to EOD Entry for that day!
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tileColor.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${d.day}', style: mktText(10, color: textColor)),
                              // Shrinks a 5+ digit output instead of wrapping it out of the 52px tile.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  d.output > 0 ? d.output.toStringAsFixed(0) : (d.color == 'grey' ? 'OFF' : '0'),
                                  maxLines: 1,
                                  style: mktText(13, weight: FontWeight.bold, color: textColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Highlights & Remarks Card (FR-12)
            MktCard(
              title: 'Highlights & Manager Remarks',
              icon: Icons.rate_review_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.remarks['managerRemarks']?.toString().isNotEmpty == true
                        ? data.remarks['managerRemarks'].toString()
                        : 'No remarks published yet.',
                    style: mktText(13),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Mkt.border),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            data.remarks['memberAckAt'] != null
                                ? 'Acknowledged on: ${DateFormat('d MMM yyyy').format(DateTime.parse(data.remarks['memberAckAt']))}'
                                : 'Not yet acknowledged',
                            style: mktText(12, color: Mkt.inkSoft),
                          ),
                          if (forSelf && data.remarks['memberAckAt'] == null)
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: Mkt.primary),
                              onPressed: () async {
                                try {
                                  await ref.read(marketingEodServiceProvider).signOffMonth(
                                        memberId: data.member.id,
                                        month: _selectedMonth,
                                        action: 'member_ack',
                                      );
                                  ref.invalidate(marketingIndividualDashboardProvider(query));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not acknowledge: $e'), backgroundColor: Mkt.bad),
                                  );
                                }
                              },
                              child: const Text('Acknowledge'),
                            ),
                        ],
                      ),
                      Text(
                        data.remarks['managerSignedAt'] != null
                            ? 'Signed off on: ${DateFormat('d MMM yyyy').format(DateTime.parse(data.remarks['managerSignedAt']))}'
                            : 'Pending Manager Sign-off',
                        style: mktText(12, color: Mkt.inkSoft),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// A member picker in the shape of the header pills — the name is capped so a long one can't push the
  /// pill past the screen edge.
  Widget _memberPicker(List<MarketingTeamMemberModel> members, String? current, ValueChanged<String> onChanged) {
    final value = members.any((m) => m.id == current) ? current! : members.first.id;
    final label = members.firstWhere((m) => m.id == value).shortName;
    return PopupMenuButton<String>(
      key: const Key('eod_member_picker'),
      tooltip: 'Team member',
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final m in members)
          PopupMenuItem<String>(
            value: m.id,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                m.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mktText(13, weight: m.id == value ? FontWeight.w800 : FontWeight.w500),
              ),
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Mkt.card,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Mkt.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 15, color: Mkt.inkSoft),
              const SizedBox(width: 7),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: Mkt.inkSoft),
            ],
          ),
        ),
      ),
    );
  }

  /// A tab's heading: a bold title with a quiet line under it.
  Widget _titleBlock(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: mktText(16, weight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle, style: mktText(12, color: Mkt.inkSoft)),
      ],
    );
  }

  /// Title block with action buttons: one Row on wide screens, the buttons on
  /// their own wrapping line under the title on phones.
  Widget _headerWithActions(bool isMobile, Widget title, List<Widget> actions) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
          ],
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ],
    );
  }

  Widget _gridLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: mktText(11, color: Mkt.inkSoft)),
      ],
    );
  }

  Color _scoreColor(int pct) {
    if (pct >= 100) return Mkt.good;
    if (pct >= 70) return Mkt.warn;
    return Mkt.bad;
  }

  Widget _statusBadge(String status) {
    var color = Mkt.grey;
    if (status == 'green') {
      color = Mkt.good;
    } else if (status == 'amber') {
      color = Mkt.warn;
    } else if (status == 'red') {
      color = Mkt.bad;
    }
    return MktChip(status.toUpperCase(), color: color);
  }

  // ==========================================================================
  // TAB 4: TEAM SUMMARY (FR-9)
  // ==========================================================================

  Future<void> _exportRecordsCsv() async {
    try {
      final data = await ref.read(marketingEodServiceProvider).exportRecords(_selectedMonth);
      if (data.rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No EOD records for this month yet.')),
        );
        return;
      }
      await ExportUtils.exportCsv('marketing-eod-records-$_selectedMonth.csv', [data.headers, ...data.rows]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Mkt.bad),
      );
    }
  }

  Widget _buildTeamSummaryTab(bool isMobile) {
    final summaryAsync = ref.watch(marketingTeamSummaryProvider(_selectedMonth));

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        title: "Couldn't load the team summary",
        onRetry: () => ref.invalidate(marketingTeamSummaryProvider(_selectedMonth)),
      ),
      data: (data) {
        final ov = data.overviewRows;

        return ListView(
          padding: _pad,
          children: [
            MktCard(
              title: 'Marketing Team Summary - $_selectedMonth',
              subtitle: 'All members side-by-side with team totals',
              icon: Icons.table_chart_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MktPill(label: 'Export records (CSV)', icon: Icons.table_view, trailing: false, onTap: _exportRecordsCsv),
                      Tooltip(
                        message: 'Export PDF (Landscape)',
                        child: MktPill(label: 'Export PDF', icon: Icons.download, trailing: false, onTap: () => downloadTeamSummaryPdf(data)),
                      ),
                      MktPrimaryButton(label: 'Print', icon: Icons.print, onPressed: () => printTeamSummaryPdf(data)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Mkt.bg),
                      columns: [
                        const DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold))),
                        ...data.members.map((m) => DataColumn(
                              label: Text(m.shortName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true,
                            )),
                        const DataColumn(label: Text('TEAM TOTAL', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: [
                        // Overview Rows
                        _teamOverviewRow('OVERVIEW', 'Days Reported', ov['daysReported'], data.members),
                        _teamOverviewRow('OVERVIEW', 'Hours Worked', ov['hoursWorked'], data.members),
                        _teamOverviewRow('OVERVIEW', 'Total Output', ov['totalOutput'], data.members),
                        _teamOverviewRow('OVERVIEW', 'Avg Target Achieved', ov['avgTargetAchieved'], data.members),
                        _teamOverviewRow('OVERVIEW', 'MTD vs Expected', ov['mtdPace'], data.members),
                        _teamOverviewRow('OVERVIEW', 'Working Days (so far / month)', ov['workingDaysElapsed'], data.members),

                        // Metric Rows
                        ...data.metricRows.map((m) {
                          return DataRow(cells: [
                            DataCell(Text(m.groupName, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            ...data.members.map((mem) {
                              final val = m.memberValues[mem.id];
                              return DataCell(Text(val != null ? val.toString() : '—'));
                            }),
                            DataCell(m.teamExpected != null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(m.teamTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        'exp ${m.teamExpected!.toStringAsFixed(1)}'
                                        '${m.teamPacePct != null ? ' · ${m.teamPacePct}%' : ''}',
                                        style: mktText(10, color: Mkt.inkSoft),
                                      ),
                                    ],
                                  )
                                : Text(m.teamTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                          ]);
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  DataRow _teamOverviewRow(
    String group,
    String label,
    dynamic obj,
    List<MarketingTeamMemberModel> members,
  ) {
    final mVals = (obj is Map ? obj['memberValues'] as Map? : null) ?? {};
    final tTotal = (obj is Map ? obj['teamTotal'] : null) ?? '—';

    return DataRow(
      color: WidgetStateProperty.all(Mkt.primarySoft.withValues(alpha: 0.5)),
      cells: [
        DataCell(Text(group, style: mktText(11, weight: FontWeight.bold, color: Mkt.primary))),
        DataCell(Text(label, style: mktText(14, weight: FontWeight.bold, color: Mkt.primary))),
        ...members.map((mem) => DataCell(
              Text(mVals[mem.id]?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
        DataCell(Text(tTotal.toString(), style: mktText(14, weight: FontWeight.bold, color: Mkt.primary))),
      ],
    );
  }

  // ==========================================================================
  // TAB 5: MISSED EODs TRACKER (FR-11)
  // ==========================================================================

  Widget _buildMissedEodsTab(bool isMobile, bool isManager) {
    final missedAsync = ref.watch(marketingMissedEodsProvider(_selectedMonth));

    return missedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        title: "Couldn't load the missed EODs",
        onRetry: () => ref.invalidate(marketingMissedEodsProvider(_selectedMonth)),
      ),
      data: (data) {
        return ListView(
          padding: _pad,
          children: [
            MktCard(
              title: 'Missed EODs Tracking - $_selectedMonth',
              subtitle: 'List of past working days without filed hours',
              icon: Icons.warning_amber_rounded,
              iconColor: Mkt.bad,
              trailing: MktChip('${data.totalMissedCount} Missed Reports', color: Mkt.bad),
              child: data.missedList.isEmpty
                  ? const MktEmpty('Awesome! No missed EOD logs for this month.', icon: Icons.check_circle_outline, height: 120)
                  : Column(
                      children: [
                        for (var idx = 0; idx < data.missedList.length; idx++)
                          _missedRow(data.missedList[idx], isManager: isManager, last: idx == data.missedList.length - 1),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _missedRow(MissedEodItem item, {required bool isManager, required bool last}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Mkt.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Mkt.tint(Mkt.bad), shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: Mkt.bad, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.memberName, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(13.5, weight: FontWeight.w800)),
                Text('Missed Working Day: ${item.date}', style: mktText(11.5, color: Mkt.inkSoft)),
              ],
            ),
          ),
          if (isManager) ...[
            const SizedBox(width: 8),
            MktPill(
              label: 'Send Reminder',
              icon: Icons.notifications_active_outlined,
              trailing: false,
              onTap: () async {
                try {
                  final message = await ref
                      .read(marketingEodServiceProvider)
                      .sendReminder(memberId: item.memberId, date: item.date);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Mkt.bad),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 6: WEEKLY PAGE STATS (FR-18)
  // ==========================================================================

  Widget _buildWeeklyStatsTab(bool isMobile, MarketingEodAccess access) {
    return ListView(
      padding: _pad,
      children: [
        _titleBlock(
          'Weekly Social Media Page Performance (FR-18)',
          'Posts, reach and engagement per week for both pages (Team N Makeovers & Team N Kerala)',
        ),
        const SizedBox(height: 12),
        EodWeeklyStatsPanel(month: _selectedMonth, access: access),
      ],
    );
  }

  // ==========================================================================
  // TAB 7: SETUP & MASTER DATA (FR-1 to FR-4, FR-17)
  // ==========================================================================

  Widget _buildSetupTab(bool isMobile) {
    final setupAsync = ref.watch(marketingEodSetupProvider);

    return setupAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        title: "Couldn't load the setup",
        onRetry: () => ref.invalidate(marketingEodSetupProvider),
      ),
      data: (setup) {
        return ListView(
          padding: _pad,
          children: [
            _headerWithActions(
              isMobile,
              _titleBlock(
                'Marketing EOD Setup (FR-1 to FR-4, FR-17)',
                'Settings, targets, groups, activities, roles, role profiles and team members — no developer needed.',
              ),
              [
                MktPill(label: 'Audit log', icon: Icons.history, trailing: false, onTap: () => showEodAuditLog(context, ref)),
              ],
            ),
            const SizedBox(height: 12),
            EodSettingsPanel(setup: setup),
            EodTargetsPanel(setup: setup, month: _selectedMonth),
            EodCataloguePanel(setup: setup),
            EodRoleProfilesPanel(setup: setup, month: _selectedMonth),
            EodMembersPanel(setup: setup, month: _selectedMonth),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 8: MONTH CLOSE & SIGN-OFF (FR-12)
  // ==========================================================================

  Widget _buildMonthCloseTab(bool isMobile) {
    final setupAsync = ref.watch(marketingEodSetupProvider);
    final members = setupAsync.value?.members ?? [];
    final effectiveMemberId = _selectedMemberId ?? (members.isNotEmpty ? members.first.id : null);
    final dashQuery = (month: _selectedMonth, memberId: effectiveMemberId);
    final dashAsync = ref.watch(marketingIndividualDashboardProvider(dashQuery));
    final remarksController = TextEditingController();

    return dashAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        title: "Couldn't load the month",
        onRetry: () => ref.invalidate(marketingIndividualDashboardProvider(dashQuery)),
      ),
      data: (data) {
        remarksController.text = data.remarks['managerRemarks']?.toString() ?? '';
        final isClosed = data.remarks['monthStatus'] == 'closed';

        return ListView(
          padding: _pad,
          children: [
            _headerWithActions(
              isMobile,
              _titleBlock(
                'Month Close & Digital Sign-off - $_selectedMonth',
                'Publish manager remarks, sign off dashboard, and close the month against further edits.',
              ),
              [
                if (members.isNotEmpty)
                  _memberPicker(members, effectiveMemberId, (val) => setState(() => _selectedMemberId = val)),
              ],
            ),
            const SizedBox(height: 12),

            MktCard(
              title: 'Month Status',
              icon: Icons.verified_outlined,
              trailing: MktChip(isClosed ? 'CLOSED / LOCKED' : 'OPEN', color: isClosed ? Mkt.bad : Mkt.good),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: remarksController,
                    style: mktText(13),
                    decoration: InputDecoration(
                      labelText: 'Manager Highlights & Remarks',
                      filled: true,
                      fillColor: Mkt.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.primary)),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      MktPrimaryButton(
                        icon: Icons.publish,
                        label: 'Save & Publish Remarks',
                        onPressed: () async {
                          await ref.read(marketingEodServiceProvider).saveRemarks({
                            'memberId': data.member.id,
                            'month': _selectedMonth,
                            'managerRemarks': remarksController.text.trim(),
                            'published': true,
                          });
                          ref.invalidate(marketingIndividualDashboardProvider(dashQuery));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Remarks published!')),
                          );
                        },
                      ),
                      if (!isClosed)
                        FilledButton.icon(
                          onPressed: () async {
                            await ref.read(marketingEodServiceProvider).signOffMonth(
                                  memberId: data.member.id,
                                  month: _selectedMonth,
                                  action: 'manager_sign',
                                );
                            ref.invalidate(marketingIndividualDashboardProvider(dashQuery));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Month signed off and closed!')),
                            );
                          },
                          icon: const Icon(Icons.lock, size: 17),
                          label: const Text('Sign-off & Lock Month'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Mkt.bad,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            textStyle: mktText(13, weight: FontWeight.w700),
                          ),
                        )
                      else
                        MktPill(
                          label: 'Reopen Month',
                          icon: Icons.lock_open,
                          trailing: false,
                          onTap: () async {
                            final reason = await _askReason('Reopen this month?', 'Reason for reopening (kept in the audit log)');
                            if (reason == null) return;
                            try {
                              await ref.read(marketingEodServiceProvider).reopenMonth(
                                    memberId: data.member.id,
                                    month: _selectedMonth,
                                    reason: reason,
                                  );
                              ref.invalidate(marketingIndividualDashboardProvider(dashQuery));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Month reopened for editing!')),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e'), backgroundColor: Mkt.bad),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
