import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/core/widgets/report_range_dialog.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/presentation/screens/crm_cases_screen.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_dashboard_widgets.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_settings_dialog.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_widgets.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';

/// The CRM Head's dashboard (/crm/dashboard) — also management's and leadership's (leadership only reads). How the team handled booking
/// requests, client chats, reviews, cases, trials and re-engagement over a period, compared with the period before; who has what open;
/// the work nobody has yet (to hand out); the cases; the reports.
class CrmDashboardScreen extends ConsumerStatefulWidget {
  const CrmDashboardScreen({super.key, this.now});

  /// What "today" is — for tests.
  final DateTime? now;

  @override
  ConsumerState<CrmDashboardScreen> createState() => _CrmDashboardScreenState();
}

class _CrmDashboardScreenState extends ConsumerState<CrmDashboardScreen> with SingleTickerProviderStateMixin {
  late ReportRange _range = reportRangeFor(ReportPreset.thisMonth, widget.now ?? DateTime.now());
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final me = ref.watch(crmMeProvider);
    return Scaffold(
      backgroundColor: crm.background,
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmMeProvider)),
        // the title, the period and the tabs stay put; each tab scrolls on its own
        data: (who) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(crm, who),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: crm.primary,
                unselectedLabelColor: crm.textPrimary,
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                indicator: UnderlineTabIndicator(borderSide: BorderSide(color: crm.primary, width: 3), borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: crm.border,
                tabs: const [Tab(text: 'Overview'), Tab(text: 'Team'), Tab(text: 'Queue'), Tab(text: 'Cases'), Tab(text: 'Reports')],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _OverviewTab(query: CrmOverviewQuery(_range), onOpenQueue: () => _tabs.animateTo(2), onOpenCases: () => _tabs.animateTo(3), now: widget.now),
                  _TeamTab(query: CrmOverviewQuery(_range)),
                  _QueueTab(canAssign: who.canAssign, now: widget.now),
                  CrmCasesView(me: who, padding: const EdgeInsets.all(16)),
                  _ReportsTab(range: _range, me: who),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(CrmTheme crm, CrmMe who) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CRM Dashboard', style: TextStyle(fontSize: wide ? 30 : 22, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.4)),
            // on a phone the subtitle is left out: the tabs below say it, and the screen is short
            if (wide || who.viewer == 'leadership')
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  who.viewer == 'leadership' ? 'The client relations team — view only' : 'Booking requests, client chat, reviews, cases, trials and re-engagement',
                  style: TextStyle(fontSize: 13.5, color: crm.textSecondary),
                ),
              ),
          ],
        );
        Widget round(Key key, String tip, IconData icon, VoidCallback onTap) => Tooltip(
          message: tip,
          child: InkResponse(
            key: key,
            onTap: onTap,
            radius: 24,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: crm.surface, shape: BoxShape.circle, border: Border.all(color: crm.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
              child: Icon(icon, size: 20, color: crm.textPrimary),
            ),
          ),
        );
        final buttons = [
          round(const Key('crmRefresh'), 'Refresh', Icons.refresh_rounded, () => refreshCrm(ref)),
          if (who.canAssign) round(const Key('crmSettingsButton'), 'Time limits and settings', Icons.tune_rounded, () => showCrmSettingsDialog(context, ref)),
          if (wide)
            FilledButton.icon(
              key: const Key('crmDownloadReport'),
              style: FilledButton.styleFrom(backgroundColor: crm.primary, minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 22), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => downloadCrmReport(context, ref, initial: _range),
              icon: const Icon(Icons.download_rounded, size: 19),
              label: const Text('Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            )
          else
            IconButton.filled(
              key: const Key('crmDownloadReport'),
              tooltip: 'Download the report',
              style: IconButton.styleFrom(backgroundColor: crm.primary),
              onPressed: () => downloadCrmReport(context, ref, initial: _range),
              icon: const Icon(Icons.download_rounded, size: 19),
            ),
        ];
        final period = CrmPeriodPill(range: _range, now: widget.now, onChanged: (r) => setState(() => _range = r));
        return Padding(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, wide ? 22 : 14, wide ? 28 : 16, 6),
          child: wide
              ? Row(children: [Expanded(child: title), period, for (final b in buttons) Padding(padding: const EdgeInsets.only(left: 12), child: b)])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [Expanded(child: title), for (final b in buttons) Padding(padding: const EdgeInsets.only(left: 8), child: b)]),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: period),
                ]),
        );
      },
    );
  }
}

/// The period as one pill ("1 Nov 2026 – 30 Nov 2026 ▾"); a tap offers Today, Last 7 days, This month, Last month or dates picked.
class CrmPeriodPill extends StatelessWidget {
  const CrmPeriodPill({super.key, required this.range, required this.onChanged, this.now});
  final ReportRange range;
  final ValueChanged<ReportRange> onChanged;
  final DateTime? now;

  static const _presets = [ReportPreset.today, ReportPreset.last7, ReportPreset.thisMonth, ReportPreset.lastMonth];

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final f = DateFormat('d MMM yyyy');
    final label = range.from == null || range.to == null ? range.label : '${f.format(range.from!)}  –  ${f.format(range.to!)}';
    return PopupMenuButton<ReportPreset>(
      key: const Key('crmPeriodPill'),
      tooltip: 'Which dates',
      position: PopupMenuPosition.under,
      onSelected: (p) async {
        if (p != ReportPreset.custom) return onChanged(reportRangeFor(p, now ?? DateTime.now()));
        final r = await showReportRangeDialog(context, title: 'Which dates?', confirmLabel: 'Show', initial: range, maxDays: kCrmMaxDays, now: now);
        if (r != null) onChanged(ReportRange(from: r.from, to: r.to, preset: ReportPreset.custom).ordered);
      },
      itemBuilder: (_) => [
        for (final p in _presets) CheckedPopupMenuItem(key: Key('crmPeriod_${p.name}'), value: p, checked: range.preset == p, child: Text(p.label)),
        CheckedPopupMenuItem(key: const Key('crmPeriod_custom'), value: ReportPreset.custom, checked: range.preset == ReportPreset.custom, child: const Text('Pick dates…')),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_month_outlined, size: 18, color: crm.primary),
          const SizedBox(width: 10),
          Flexible(child: Text(label, key: const Key('crmPeriodLabel'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: crm.textPrimary))),
          const SizedBox(width: 10),
          Container(width: 1, height: 22, color: crm.border),
          const SizedBox(width: 8),
          Icon(Icons.keyboard_arrow_down_rounded, color: crm.textSecondary),
        ]),
      ),
    );
  }
}

// ── overview ────────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.query, required this.onOpenQueue, required this.onOpenCases, this.now});
  final CrmOverviewQuery query;
  final VoidCallback onOpenQueue, onOpenCases;
  final DateTime? now;

  // a link to another screen of the app (inside the app's router only — a test has none)
  static void _go(BuildContext context, String path) {
    if (GoRouter.maybeOf(context) != null) context.go(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crmOverviewProvider(query));
    // "Today's Summary" is today's whatever period is chosen (the same read when the period IS today)
    final todayQuery = CrmOverviewQuery(reportRangeFor(ReportPreset.today, now ?? DateTime.now()), memberId: query.memberId);
    final today = ref.watch(crmOverviewProvider(todayQuery));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmOverviewProvider(query))),
      data: (o) => RefreshIndicator(
        onRefresh: () async => refreshCrm(ref),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final pad = w >= 760 ? 22.0 : 14.0;
          final inner = w - pad * 2;
          const gap = 16.0;
          final openWork = CrmOpenWorkCard(now: o.now, unassigned: o.unassigned, onViewAll: onOpenQueue);
          final todayCard = CrmTodayCard(today: today.value, loading: today.isLoading && !today.hasValue);
          Widget chart(double h) => CrmRequestsChartCard(trend: o.trend, height: h, onViewAll: () => _go(context, '/booking/requests'));
          final chats = CrmMiniStatsCard(
            key: const Key('crmChatCard'),
            title: 'Client Chat',
            icon: Icons.forum_outlined,
            onViewAll: () => _go(context, '/client-chat'),
            viewAllKey: const Key('crmChatViewAll'),
            stats: [
              CrmMiniStat(label: 'Clients waiting now', value: '${o.now.chats}', icon: Icons.mark_chat_unread_outlined, color: kCrmIndigo, valueKey: const Key('crmMini_chatsWaiting')),
              _mini(o, 'chatMedianReplyMins', 'Time to answer', Icons.timer_outlined, kCrmAmber),
              _mini(o, 'chatWithinSlaPct', 'Answered in time', Icons.verified_outlined, kCrmSky),
              _mini(o, 'chatUnanswered', 'Left unanswered', Icons.speaker_notes_off_outlined, kCrmRose),
            ],
          );
          final care = CrmMiniStatsCard(
            key: const Key('crmCareCard'),
            title: 'Reviews & Cases',
            icon: Icons.star_outline_rounded,
            onViewAll: onOpenCases,
            viewAllKey: const Key('crmCareViewAll'),
            stats: [
              _mini(o, 'avgRating', 'Average rating', Icons.sentiment_satisfied_alt_outlined, kCrmGreen),
              _mini(o, 'nps', 'NPS', Icons.thumb_up_alt_outlined, kCrmIndigo),
              _mini(o, 'reviewResponseRate', 'Reviews answered', Icons.rate_review_outlined, kCrmSky),
              _mini(o, 'casesResolved', 'Cases resolved', Icons.check_circle_outline_rounded, kCrmGreen),
            ],
          );
          final recent = CrmRecentCard(
            items: o.recent,
            now: now ?? DateTime.now(),
            onOpen: (e) => _go(context, switch (e.refType) {
              'conversation' => '/client-chat/${e.refId}',
              'case' => '/crm/cases/${e.refId}',
              'review' => '/reviews',
              _ => '/booking/requests',
            }),
          );
          final trials = CrmUpcomingTrialsCard(trials: o.upcomingTrials, onViewAll: () => _go(context, '/trials'));

          Widget row(List<(int, Widget)> cells) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < cells.length; i++) ...[if (i > 0) const SizedBox(width: gap), Expanded(flex: cells[i].$1, child: cells[i].$2)],
          ]);

          // wide: the ring, the chart and today side by side (one height); a tablet: ring and today, then the chart; a phone: one by one
          final List<Widget> middle;
          if (inner >= 1060) {
            middle = [row([(4, SizedBox(height: 300, child: openWork)), (5, chart(300)), (4, SizedBox(height: 300, child: todayCard))])];
          } else if (inner >= 700) {
            middle = [row([(1, openWork), (1, todayCard)]), const SizedBox(height: gap), chart(280)];
          } else {
            middle = [openWork, const SizedBox(height: gap), chart(250), const SizedBox(height: gap), todayCard];
          }
          final wideCards = inner >= 980;
          return ListView(
            key: const Key('crmOverviewList'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad, 18, pad, 32),
            children: [
              if (o.partial) ...[CrmTrackingBanner(since: o.trackingSince), const SizedBox(height: 14)],
              _statsGrid(_stats(context, o), inner, gap),
              const SizedBox(height: gap),
              ...middle,
              const SizedBox(height: gap),
              if (wideCards) row([(1, chats), (1, care)]) else ...[chats, const SizedBox(height: gap), care],
              const SizedBox(height: gap),
              if (wideCards) row([(11, recent), (9, trials)]) else ...[recent, const SizedBox(height: gap), trials],
              const SizedBox(height: gap),
              CrmBreachesCard(overview: o, now: now),
            ],
          );
        }),
      ),
    );
  }

  static Widget _mini(CrmOverview o, String key, String label, IconData icon, Color color) {
    final k = o.kpi(key);
    // "4.5 / 5" reads as a big 4.5 and a small "/ 5"
    final parts = k.display.split(' / ');
    return CrmMiniStat(label: label, value: parts.first, suffix: parts.length > 1 ? ' / ${parts.last}' : null, icon: icon, color: color, valueKey: Key('crmKpiValue_$key'), unknown: k.value == null);
  }

  List<Widget> _stats(BuildContext context, CrmOverview o) => [
    CrmStatCard(kpiKey: 'requestsReceived', label: 'Booking Requests', icon: Icons.event_note_outlined, kpi: o.kpi('requestsReceived'), highlight: true, onTap: () => _go(context, '/booking/requests')),
    CrmStatCard(kpiKey: 'chatWaits', label: 'Client Chats', icon: Icons.chat_bubble_outline_rounded, kpi: o.kpi('chatWaits'), onTap: () => _go(context, '/client-chat')),
    CrmStatCard(kpiKey: 'casesOpened', label: 'Cases Opened', icon: Icons.layers_outlined, kpi: o.kpi('casesOpened'), onTap: onOpenCases),
    CrmStatCard(kpiKey: 'trialsScheduled', label: 'Trials', icon: Icons.science_outlined, kpi: o.kpi('trialsScheduled'), onTap: () => _go(context, '/trials')),
    CrmStatCard(kpiKey: 'reviewsSubmitted', label: 'Client Reviews', icon: Icons.star_outline_rounded, kpi: o.kpi('reviewsSubmitted'), onTap: () => _go(context, '/reviews')),
  ];

  /// Five across on a wide screen, three then two on a tablet, two a row on a phone.
  static Widget _statsGrid(List<Widget> cards, double width, double gap) {
    if (width >= 1060) {
      return Row(children: [for (var i = 0; i < cards.length; i++) ...[if (i > 0) SizedBox(width: gap), Expanded(child: cards[i])]]);
    }
    final cols = width >= 640 ? 3 : 2;
    final w = (width - gap * (cols - 1)) / cols;
    return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in cards) SizedBox(width: w, child: c)]);
  }
}

/// Requests and chats over the period, day by day (month by month for a long period).
class CrmTrendCard extends StatelessWidget {
  const CrmTrendCard({super.key, required this.trend});
  final List<CrmTrendPoint> trend;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    const reqColor = Color(0xFF6366F1);
    const chatColor = Color(0xFF10B981);
    final points = trend;
    final maxY = points.fold<int>(1, (m, p) => [m, p.requestsReceived ?? 0, p.chatWaits ?? 0].reduce((a, b) => a > b ? a : b));
    String label(String key) => key.length == 7 ? key.substring(5) : key.substring(8);
    Widget legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(t, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
    ]);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Requests and chats', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            legend(reqColor, 'requests'),
            const SizedBox(width: 10),
            legend(chatColor, 'chat waits'),
          ]),
          const SizedBox(height: 12),
          if (points.isEmpty)
            Text('Nothing in this period.', style: TextStyle(color: crm.textSecondary))
          else
            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: (maxY * 1.2).ceilToDouble(),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    // whole numbers only, and not the top edge (it is just headroom)
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                        getTitlesWidget: (v, meta) => v == meta.max || v != v.roundToDouble()
                            ? const SizedBox.shrink()
                            : Text('${v.toInt()}', style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) return const SizedBox.shrink();
                          final step = (points.length / 10).ceil();
                          if (i % step != 0) return const SizedBox.shrink();
                          return Text(label(points[i].key), style: TextStyle(fontSize: 10, color: crm.textSecondary));
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(x: i, barsSpace: 1, barRods: [
                        BarChartRodData(toY: (points[i].requestsReceived ?? 0).toDouble(), color: reqColor, width: points.length > 20 ? 3 : 7),
                        BarChartRodData(toY: (points[i].chatWaits ?? 0).toDouble(), color: chatColor, width: points.length > 20 ? 3 : 7),
                      ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What is past its time limit right now.
class CrmBreachesCard extends StatelessWidget {
  const CrmBreachesCard({super.key, required this.overview, this.now});
  final CrmOverview overview;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final none = overview.breachCount == 0;
    return CrmDashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(none ? Icons.verified_outlined : Icons.alarm_rounded, size: 19, color: none ? crm.success : crm.destructive),
            const SizedBox(width: 8),
            Text(none ? 'Nothing is overdue' : 'Overdue now (${overview.breachCount})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: none ? crm.success : crm.destructive)),
          ]),
          const SizedBox(height: 10),
          CrmQueueList(items: overview.breaches, emptyText: 'Every request, chat and case is inside its time limit.', now: now),
        ],
      ),
    );
  }
}

// ── team ────────────────────────────────────────────────────────────────────

class _TeamTab extends ConsumerWidget {
  const _TeamTab({required this.query});
  final CrmOverviewQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(crmOverviewProvider(query));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmOverviewProvider(query))),
      data: (o) {
        if (o.members.isEmpty) {
          return Center(child: Text('Nobody has a CRM login yet.', style: TextStyle(color: crm.textSecondary)));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (o.partial) ...[CrmTrackingBanner(since: o.trackingSince), const SizedBox(height: 12)],
            for (final m in o.members) _MemberCard(member: m, range: query.range),
          ],
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.range});
  final CrmMemberLine member;
  final ReportRange range;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final m = member;
    Widget fig(String label, CrmKpi k) => SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k.display, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: k.value == null ? crm.textSecondary : crm.textPrimary)),
          Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        ],
      ),
    );
    return CrmPanel(
      key: Key('crmMember_${m.userId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/crm/team/${m.userId}?from=${range.fromIso}&to=${range.toIso}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 16, child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase())),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${m.name}${m.isHead ? '  ·  Head' : ''}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary))),
                  Text('${m.workload.total} open', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                  if (m.workload.overdue > 0) ...[
                    const SizedBox(width: 8),
                    Text('${m.workload.overdue} overdue', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.destructive)),
                  ],
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  fig('requests decided', m.kpi('requestsDecided')),
                  fig('time to decide', m.kpi('requestMedianHours')),
                  fig('chat waits', m.kpi('chatWaits')),
                  fig('time to answer', m.kpi('chatMedianReplyMins')),
                  fig('cases resolved', m.kpi('casesResolved')),
                  fig('cases on time', m.kpi('caseOnTimePct')),
                  fig('re-engagement calls', m.kpi('reCalls')),
                  fig('wins', m.kpi('reWins')),
                  fig('NPS', m.kpi('nps')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── queue ───────────────────────────────────────────────────────────────────

class _QueueTab extends ConsumerStatefulWidget {
  const _QueueTab({required this.canAssign, this.now});
  final bool canAssign;
  final DateTime? now;

  @override
  ConsumerState<_QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends ConsumerState<_QueueTab> {
  String _scope = 'unassigned';
  String _type = '';
  final Set<String> _selected = {};

  CrmQueueQuery get _query => CrmQueueQuery(scope: _scope, types: _type.isEmpty ? null : _type);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(crmQueueProvider(_query));
    final items = async.value?.items ?? const <CrmQueueItem>[];
    final chosen = items.where((i) => _selected.contains(CrmQueueList.keyOf(i))).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (k, l) in const [('unassigned', 'Not assigned'), ('all', 'Everyone\'s')])
                ChoiceChip(key: Key('crmQueueScope_$k'), label: Text(l), selected: _scope == k, onSelected: (_) => setState(() {
                  _scope = k;
                  _selected.clear();
                })),
              const SizedBox(width: 8),
              for (final (k, l) in const [('', 'All work'), ('booking', 'Requests'), ('conversation', 'Chats'), ('case', 'Cases'), ('trial', 'Trials')])
                ChoiceChip(label: Text(l), selected: _type == k, onSelected: (_) => setState(() {
                  _type = k;
                  _selected.clear();
                })),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmQueueProvider(_query))),
            data: (q) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(crmQueueProvider(_query)),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.canAssign && q.items.isNotEmpty)
                    Row(children: [
                      TextButton(
                        onPressed: () => setState(() {
                          if (_selected.length == q.items.length) {
                            _selected.clear();
                          } else {
                            _selected.addAll(q.items.map(CrmQueueList.keyOf));
                          }
                        }),
                        child: Text(_selected.length == q.items.length ? 'Clear the ticks' : 'Tick all ${q.items.length}'),
                      ),
                      const Spacer(),
                      Text('${q.counts['overdue'] ?? 0} overdue', style: TextStyle(fontSize: 12.5, color: crm.destructive)),
                    ]),
                  CrmQueueList(
                    items: q.items,
                    selected: widget.canAssign ? _selected : null,
                    onToggle: widget.canAssign ? (i) => setState(() => _selected.contains(CrmQueueList.keyOf(i)) ? _selected.remove(CrmQueueList.keyOf(i)) : _selected.add(CrmQueueList.keyOf(i))) : null,
                    emptyText: _scope == 'unassigned' ? 'Everything has an owner.' : 'Nothing waiting.',
                    now: widget.now,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.canAssign && chosen.isNotEmpty)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
              child: Row(
                children: [
                  Expanded(child: Text('${chosen.length} ticked', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary))),
                  FilledButton.icon(
                    key: const Key('crmAssignSelected'),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Assign to…'),
                    onPressed: () async {
                      final owner = await showCrmAssignDialog(context, count: chosen.length);
                      if (owner == null || !context.mounted) return;
                      if (await crmAssign(context, ref, chosen, owner)) setState(_selected.clear);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── reports ─────────────────────────────────────────────────────────────────

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab({required this.range, required this.me});
  final ReportRange range;
  final CrmMe me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final team = me.seesTeam ? ref.watch(crmTeamProvider) : null;
    Widget card({required Key key, required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) => CrmPanel(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(key: key, leading: Icon(icon, color: crm.primary), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        card(
          key: const Key('crmReportTeam'),
          icon: Icons.download_outlined,
          title: 'The team\'s CRM report',
          subtitle: 'Excel (every record) or PDF (the summary) — any dates up to a year',
          onTap: () => downloadCrmReport(context, ref, initial: range),
        ),
        card(
          key: const Key('crmWeeklyLink'),
          icon: Icons.summarize_outlined,
          title: 'Weekly report',
          subtitle: 'Trials, photos & reviews, support, starting messages, verification, medical, workload and outsource — week by week',
          onTap: () => context.go('/crm/weekly'),
        ),
        if (me.isHead || me.viewer == 'admin')
          card(
            key: const Key('crmMonthEnd'),
            icon: Icons.fact_check_outlined,
            title: 'CRM month-end review',
            subtitle: 'The department report — its figures fill in from the CRM records',
            onTap: () => context.go('/crm/month-end'),
          ),
        card(
          key: const Key('crmCallList'),
          icon: Icons.phone_callback_outlined,
          title: 'Clients to call again',
          subtitle: 'Past clients who have not booked for months — make call cases',
          onTap: () => context.go('/crm/re-engagement'),
        ),
        if (team != null) ...[
          const SizedBox(height: 10),
          Text('One member\'s report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(height: 8),
          team.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(friendlyErrorMessage(e)),
            data: (t) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in t.members)
                  ActionChip(
                    key: Key('crmReportFor_${m.userId}'),
                    avatar: const Icon(Icons.download, size: 16),
                    label: Text(m.name),
                    onPressed: () => downloadCrmReport(context, ref, initial: range, memberId: m.userId, who: m.name),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
