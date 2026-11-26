import 'dart:async';
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/core/utils/whatsapp_service.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
import 'package:nizan_crm/features/reviews/data/review.dart';
import 'package:nizan_crm/features/reviews/services/review_service.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/crm/presentation/screens/crm_cases_screen.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_widgets.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';

const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime? d) => d == null ? '' : '${d.day} ${_mon[d.month]} ${d.year}';
String _short(DateTime? d) => d == null ? '' : '${d.day} ${_mon[d.month]}';

const _lookMatch = {
  'much_better': 'Much better than expected',
  'exactly': 'Exactly what I expected',
  'mostly': 'Mostly what I expected',
  'not': 'Not what I expected',
};
const _comfortable = {
  'definitely_yes': 'Definitely yes',
  'yes': 'Yes',
  'not_completely': 'Not completely',
  'no': 'No',
};
const _yesMaybe = {
  'definitely_yes': 'Definitely yes',
  'yes': 'Yes',
  'maybe': 'Maybe',
  'no': 'No',
};

String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

Color _scoreColor(CrmTheme crm, double s) =>
    s >= 4.5 ? crm.success : (s >= 3.5 ? crm.accent : crm.warning);

Color _npsColor(CrmTheme crm, int nps) =>
    nps >= 50 ? crm.success : (nps >= 0 ? crm.accent : crm.warning);

BoxDecoration _cardBox(CrmTheme crm, {Color? border}) => BoxDecoration(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border ?? crm.border),
    );

// ── Screen ───────────────────────────────────────────────────────────────────

/// Client reviews: a summary strip on top, then Submitted · Not submitted ·
/// Insights. "Not submitted" = clients who were sent the review link but
/// haven't filled it in, with how far they got (not opened / opened /
/// stopped midway), resend on WhatsApp, copy link and export.
class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        title: const Text('Client Reviews'),
        backgroundColor: crm.surface,
        foregroundColor: crm.textPrimary,
        elevation: 0,
        actions: [
          const _PeriodMenu(),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refreshData.reviews(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _SummaryStrip(onNotSubmittedTap: () => _tabs.animateTo(1)),
          Container(
            color: crm.surface,
            child: TabBar(
              controller: _tabs,
              indicatorColor: crm.primary,
              labelColor: crm.primary,
              unselectedLabelColor: crm.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Submitted'),
                Tab(text: 'Not submitted'),
                Tab(text: 'Insights'),
              ],
            ),
          ),
          Divider(height: 1, color: crm.border),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _SubmittedTab(),
                _NotSubmittedTab(),
                _InsightsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// All time / last 30 / last 90 days for the summary + insights.
class _PeriodMenu extends ConsumerWidget {
  const _PeriodMenu();

  static const _options = <int?, String>{null: 'All time', 30: 'Last 30 days', 90: 'Last 90 days', 365: 'Last 12 months'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final days = ref.watch(reviewPeriodDaysProvider);
    return PopupMenuButton<int?>(
      tooltip: 'Summary period',
      initialValue: days,
      onSelected: (v) => ref.read(reviewPeriodDaysProvider.notifier).state = v,
      itemBuilder: (_) => _options.entries
          .map((e) => PopupMenuItem<int?>(value: e.key, child: Text(e.value)))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_month_outlined, size: 18, color: crm.textSecondary),
          const SizedBox(width: 6),
          Text(_options[days] ?? 'All time',
              style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          Icon(Icons.arrow_drop_down, color: crm.textSecondary),
        ]),
      ),
    );
  }
}

// ── Summary strip ────────────────────────────────────────────────────────────

class _SummaryStrip extends ConsumerWidget {
  final VoidCallback onNotSubmittedTap;
  const _SummaryStrip({required this.onNotSubmittedTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final a = ref.watch(reviewInsightsProvider).value;
    final allTime = ref.watch(reviewPeriodDaysProvider) == null;
    final tiles = [
      _Kpi(
        icon: Icons.star_rounded,
        label: 'Avg rating',
        value: a == null ? '—' : (a.totalSubmitted == 0 ? '—' : '${_n(a.avgBrideScore)}/5'),
        sub: a == null ? '' : '${a.totalSubmitted} review${a.totalSubmitted == 1 ? '' : 's'}',
        color: a == null ? crm.primary : _scoreColor(crm, a.avgBrideScore),
      ),
      _Kpi(
        icon: Icons.thumb_up_alt_outlined,
        label: 'NPS',
        value: a == null || a.npsResponses == 0 ? '—' : '${a.nps}',
        sub: a == null ? '' : '${a.promoters} promoters · ${a.detractors} detractors',
        color: a == null ? crm.primary : _npsColor(crm, a.nps),
      ),
      _Kpi(
        icon: Icons.mark_email_read_outlined,
        label: 'Response rate',
        value: a == null ? '—' : '${a.responseRate}%',
        sub: allTime ? 'of links sent' : 'of links sent · all time',
        color: crm.accent,
      ),
      _Kpi(
        icon: Icons.hourglass_top_rounded,
        label: 'Not submitted',
        value: a == null ? '—' : '${a.notSubmitted}',
        sub: a == null ? '' : '${a.notOpened} never opened',
        color: crm.warning,
        onTap: onNotSubmittedTap,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: LayoutBuilder(builder: (context, c) {
        final perRow = c.maxWidth >= 760 ? 4 : 2;
        const gap = 10.0;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      }),
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  final VoidCallback? onTap;
  const _Kpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: _cardBox(crm),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(value,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (onTap != null) Icon(Icons.chevron_right, size: 18, color: crm.textSecondary),
          ]),
        ),
      ),
    );
  }
}

// ── Shared filter bar ────────────────────────────────────────────────────────

class _FilterBar extends ConsumerStatefulWidget {
  final StateProvider<ReviewFilter> provider;
  final List<String> artists;
  final String dateHelp; // what the date range filters on
  final List<Widget> trailing;
  const _FilterBar({
    required this.provider,
    required this.artists,
    required this.dateHelp,
    this.trailing = const [],
  });

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  late final TextEditingController _search =
      TextEditingController(text: ref.read(widget.provider).search);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final n = ref.read(widget.provider.notifier);
      n.state = n.state.copyWith(search: v.trim());
    });
  }

  Future<void> _pickDates(ReviewFilter f) async {
    final range = await showBrandedDateRangePicker(
      context,
      helpText: widget.dateHelp,
      initialDateRange:
          f.from != null && f.to != null ? DateTimeRange(start: f.from!, end: f.to!) : null,
    );
    if (range == null) return;
    final n = ref.read(widget.provider.notifier);
    n.state = n.state.copyWith(from: range.start, to: range.end);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final f = ref.watch(widget.provider);
    final hasDates = f.from != null && f.to != null;
    final artists = {...widget.artists, if (f.artist.isNotEmpty) f.artist}.toList()..sort();

    final searchField = SizedBox(
      height: 40,
      child: TextField(
        controller: _search,
        onChanged: _onSearch,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search client, booking #, phone…',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: crm.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: crm.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: crm.border),
          ),
        ),
      ),
    );

    final artistMenu = PopupMenuButton<String>(
      tooltip: 'Filter by artist',
      onSelected: (v) {
        final n = ref.read(widget.provider.notifier);
        n.state = n.state.copyWith(artist: v);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('All artists')),
        for (final a in artists) PopupMenuItem(value: a, child: Text(a)),
      ],
      child: _pill(crm, Icons.brush_outlined, f.artist.isEmpty ? 'All artists' : f.artist,
          active: f.artist.isNotEmpty),
    );

    final dateBtn = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _pickDates(f),
      child: _pill(
        crm,
        Icons.date_range_outlined,
        hasDates ? '${_short(f.from)} – ${_short(f.to)}' : 'Any date',
        active: hasDates,
        onClear: hasDates
            ? () {
                final n = ref.read(widget.provider.notifier);
                n.state = n.state.copyWith(clearDates: true);
              }
            : null,
      ),
    );

    return Container(
      color: crm.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 720;
        final controls = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [artistMenu, dateBtn, ...widget.trailing],
        );
        if (wide) {
          return Row(children: [
            SizedBox(width: 300, child: searchField),
            const SizedBox(width: 10),
            Expanded(child: controls),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          searchField,
          const SizedBox(height: 8),
          controls,
        ]);
      }),
    );
  }

  Widget _pill(CrmTheme crm, IconData icon, String text, {bool active = false, VoidCallback? onClear}) {
    final color = active ? crm.primary : crm.textSecondary;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? crm.primary.withValues(alpha: 0.08) : crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? crm.primary.withValues(alpha: 0.4) : crm.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ),
        if (onClear != null) ...[
          const SizedBox(width: 4),
          InkWell(onTap: onClear, child: Icon(Icons.close, size: 15, color: color)),
        ] else
          Icon(Icons.arrow_drop_down, size: 18, color: color),
      ]),
    );
  }
}

Widget _toggleChip(CrmTheme crm, String label, bool selected, VoidCallback onTap, {Color? color}) {
  final c = color ?? crm.primary;
  return InkWell(
    borderRadius: BorderRadius.circular(100),
    onTap: onTap,
    child: Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: selected ? c.withValues(alpha: 0.5) : crm.border),
      ),
      // widthFactor 1 = hug the text (a plain alignment would fill the row).
      child: Center(
        widthFactor: 1,
        child: Text(label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? c : crm.textSecondary,
            )),
      ),
    ),
  );
}

Widget _badge(String text, Color color, {IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      ]),
    );

Widget _emptyState(CrmTheme crm, IconData icon, String title, String sub) => ListView(
      // ListView so pull-to-refresh still works on an empty list.
      children: [
        const SizedBox(height: 70),
        Icon(icon, size: 52, color: crm.textSecondary.withValues(alpha: 0.6)),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(sub,
            textAlign: TextAlign.center,
            style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
      ],
    );

Widget _avatar(CrmTheme crm, String name, Color color) {
  final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
  return CircleAvatar(
    radius: 19,
    backgroundColor: color.withValues(alpha: 0.12),
    child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
  );
}

// ── Submitted tab ────────────────────────────────────────────────────────────

class _SubmittedTab extends ConsumerWidget {
  const _SubmittedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final f = ref.watch(reviewFilterProvider);
    final async = ref.watch(reviewsProvider);
    final all = async.value ?? const <Review>[];

    return Column(children: [
      _FilterBar(
        provider: reviewFilterProvider,
        artists: artistsIn(all),
        dateHelp: 'Submitted between',
        trailing: [
          _toggleChip(crm, '⚠ Needs follow-up', f.followUpOnly, () {
            final n = ref.read(reviewFilterProvider.notifier);
            n.state = n.state.copyWith(followUpOnly: !f.followUpOnly);
          }, color: crm.warning),
        ],
      ),
      Divider(height: 1, color: crm.border),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(reviewsProvider)),
          data: (list) {
            final rows = filterByArtist(list, f.artist);
            return RefreshIndicator(
              onRefresh: () async => ref.refreshData.reviews(),
              child: rows.isEmpty
                  ? _emptyState(crm, Icons.reviews_outlined, 'No reviews here',
                      'Submitted reviews appear here once clients fill in the form.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
                      itemCount: rows.length + 1,
                      itemBuilder: (_, i) => i == 0
                          ? _countLine(crm, '${rows.length} review${rows.length == 1 ? '' : 's'}')
                          : _SubmittedCard(review: rows[i - 1]),
                    ),
            );
          },
        ),
      ),
    ]);
  }
}

Widget _countLine(CrmTheme crm, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600)),
    );

class _SubmittedCard extends StatelessWidget {
  final Review review;
  const _SubmittedCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = review;
    final score = r.brideScore;
    final sc = _scoreColor(crm, score);
    final quote = [r.testimonial, r.likedMost, r.couldBeBetter]
        .firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
    final meta = [
      if (r.artistName.isNotEmpty) r.artistName,
      if (r.bookingNumber.isNotEmpty) '#${r.bookingNumber}',
      if (r.submittedAt != null) 'Submitted ${_date(r.submittedAt!.toLocal())}',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardBox(crm, border: r.complaint ? crm.warning.withValues(alpha: 0.6) : null),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ReviewDetailScreen(reviewId: r.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _avatar(crm, r.brideName, crm.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.brideName.isEmpty ? 'Client' : r.brideName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    if (meta.isNotEmpty)
                      Text(meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, size: 16, color: sc),
                    const SizedBox(width: 2),
                    Text(score > 0 ? _n(score) : '—',
                        style: TextStyle(fontWeight: FontWeight.w900, color: sc, fontSize: 15)),
                  ]),
                ),
              ]),
              if (quote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('“${quote.trim()}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, fontStyle: FontStyle.italic, color: crm.textPrimary.withValues(alpha: 0.85))),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (r.nps != null)
                  _badge('NPS ${r.nps}',
                      r.nps! >= 9 ? crm.success : (r.nps! >= 7 ? crm.accent : crm.warning)),
                if (r.complaint) _badge('Complaint', crm.warning, icon: Icons.report_problem_outlined),
                if (r.followUpRequired) _badge('Follow-up', crm.warning, icon: Icons.event_repeat_outlined),
                if (r.marketingConsent && r.testimonial.trim().isNotEmpty)
                  _badge('Testimonial OK', crm.success, icon: Icons.campaign_outlined),
                if (r.reviewPosted) _badge('Posted', crm.accent, icon: Icons.check_circle_outline),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Not submitted tab ────────────────────────────────────────────────────────

String _reviewMessage(String name, String url) => '''
Hi *${name.trim().isEmpty ? 'there' : name.trim()}*,

Thank you for choosing *Team N Makeovers*! 🌸

We would love to hear about your experience. Please take 2 minutes to share your review:
$url

Your feedback means the world to us 💖
''';

class _NotSubmittedTab extends ConsumerWidget {
  const _NotSubmittedTab();

  static const _stages = {
    '': 'All',
    'notOpened': 'Not opened',
    'opened': 'Opened',
    'started': 'Stopped midway',
  };

  Future<void> _export(BuildContext context, List<Review> rows) async {
    String d(DateTime? x) => x == null ? '' : _date(x.toLocal());
    final data = <List<dynamic>>[
      [
        'Client', 'Phone', 'Booking #', 'Wedding date', 'Artist', 'Link sent on', 'Sent by',
        'Times sent by staff', 'Form status', 'Last opened', 'Review link',
      ],
      for (final r in rows)
        [
          r.brideName,
          r.customerPhone,
          r.bookingNumber,
          d(r.weddingDate),
          r.artistName,
          d(r.lastSentAt),
          r.manualSentAt != null ? 'Staff' : 'Automatic WhatsApp',
          r.manualSendCount,
          r.engagementLabel,
          d(r.lastOpenedAt),
          r.reviewUrl,
        ],
    ];
    try {
      // BOM so Excel reads names in Malayalam / other scripts correctly.
      final csv = '﻿${const CsvEncoder().convert(data)}';
      final now = DateTime.now();
      final stamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await saveFileBytes('reviews-not-submitted-$stamp.csv', utf8.encode(csv), mime: 'text/csv');
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final f = ref.watch(notSubmittedFilterProvider);
    final async = ref.watch(notSubmittedReviewsProvider);
    final all = async.value ?? const <Review>[];
    final byArtist = filterByArtist(all, f.artist);
    final counts = <String, int>{
      '': byArtist.length,
      for (final k in ['notOpened', 'opened', 'started'])
        k: byArtist.where((r) => r.engagement == k).length,
    };
    final rows = f.engagement.isEmpty
        ? byArtist
        : byArtist.where((r) => r.engagement == f.engagement).toList();

    return Column(children: [
      _FilterBar(
        provider: notSubmittedFilterProvider,
        artists: artistsIn(all),
        dateHelp: 'Wedding date between',
        trailing: [
          OutlinedButton.icon(
            onPressed: rows.isEmpty ? null : () => _export(context, rows),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: crm.primary,
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
      Container(
        width: double.infinity,
        color: crm.surface,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _stages.entries)
            _toggleChip(crm, '${e.value} · ${counts[e.key] ?? 0}', f.engagement == e.key, () {
              final n = ref.read(notSubmittedFilterProvider.notifier);
              n.state = n.state.copyWith(engagement: e.key);
            }),
        ]),
      ),
      Divider(height: 1, color: crm.border),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              AppErrorView(error: e, onRetry: () => ref.invalidate(notSubmittedReviewsProvider)),
          data: (_) => RefreshIndicator(
            onRefresh: () async => ref.refreshData.reviews(),
            child: rows.isEmpty
                ? _emptyState(crm, Icons.mark_email_read_outlined, 'Nobody waiting',
                    'Every client who was sent a review link has submitted it.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
                    itemCount: rows.length + 1,
                    itemBuilder: (_, i) => i == 0
                        ? _countLine(crm,
                            '${rows.length} client${rows.length == 1 ? '' : 's'} sent a link but no review yet')
                        : _NotSubmittedCard(review: rows[i - 1]),
                  ),
          ),
        ),
      ),
    ]);
  }
}

class _NotSubmittedCard extends ConsumerStatefulWidget {
  final Review review;
  const _NotSubmittedCard({required this.review});

  @override
  ConsumerState<_NotSubmittedCard> createState() => _NotSubmittedCardState();
}

class _NotSubmittedCardState extends ConsumerState<_NotSubmittedCard> {
  bool _sending = false;

  Future<void> _resend() async {
    final r = widget.review;
    setState(() => _sending = true);
    try {
      var link = r.reviewUrl;
      if (r.bookingId.isNotEmpty) {
        // Records the hand send (so the auto-send skips it) and returns the link.
        link = await ref.read(reviewServiceProvider).getReviewLink(r.bookingId, markSent: true);
      }
      if (link.isEmpty) throw 'No review link available.';
      await WhatsAppService.openChat(r.customerPhone, _reviewMessage(r.brideName, link));
      ref.refreshData.reviews();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copy() async {
    final url = widget.review.reviewUrl;
    if (url.isEmpty) {
      showErrorSnackBar(context, 'No review link available.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) showSuccessSnackBar(context, 'Review link copied');
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = widget.review;
    final stageColor = switch (r.engagement) {
      'started' => crm.accent,
      'opened' => crm.primary,
      _ => crm.textSecondary,
    };
    final stageIcon = switch (r.engagement) {
      'started' => Icons.pending_actions_outlined,
      'opened' => Icons.visibility_outlined,
      _ => Icons.visibility_off_outlined,
    };
    final sent = r.lastSentAt;
    final waitingDays = sent == null ? null : DateTime.now().difference(sent).inDays;
    final sentLine = [
      if (sent != null)
        'Sent ${_short(sent.toLocal())} ${r.manualSentAt != null ? 'by staff' : 'automatically'}',
      if (r.manualSendCount > 1) 'sent ${r.manualSendCount}×',
      if (r.lastOpenedAt != null) 'last opened ${_short(r.lastOpenedAt!.toLocal())}',
    ].join(' · ');
    final meta = [
      if (r.weddingDate != null) _date(r.weddingDate!.toLocal()),
      if (r.artistName.isNotEmpty) r.artistName,
      if (r.bookingNumber.isNotEmpty) '#${r.bookingNumber}',
    ].join(' · ');

    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: 'Copy review link',
        onPressed: _copy,
        icon: Icon(Icons.link_rounded, color: crm.textSecondary),
      ),
      FilledButton.icon(
        onPressed: _sending ? null : _resend,
        icon: _sending
            ? const SizedBox(
                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_rounded, size: 16),
        label: const Text('Resend'),
        style: FilledButton.styleFrom(
          backgroundColor: crm.success,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _cardBox(crm),
      child: LayoutBuilder(builder: (context, c) {
        final info = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(crm, r.brideName, stageColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(r.brideName.isEmpty ? 'Client' : r.brideName,
                      style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
                  _badge(r.engagementLabel, stageColor, icon: stageIcon),
                  if (waitingDays != null && waitingDays >= 3)
                    _badge('Waiting $waitingDays days', crm.warning),
                ],
              ),
              if (meta.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(meta, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ),
              if (sentLine.isNotEmpty)
                Text(sentLine, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              if (r.answeredCount > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: r.answeredCount / (r.totalQuestions > 0 ? r.totalQuestions : 12),
                    minHeight: 5,
                    backgroundColor: crm.border,
                    color: crm.accent,
                  ),
                ),
              ],
            ]),
          ),
        ]);
        if (c.maxWidth >= 560) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: info),
            const SizedBox(width: 8),
            actions,
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          info,
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: actions),
        ]);
      }),
    );
  }
}

// ── Insights ─────────────────────────────────────────────────────────────────

class _InsightsTab extends ConsumerWidget {
  const _InsightsTab();

  static const _bride = {
    'overall': 'Overall experience',
    'makeup': 'Makeup',
    'hair': 'Hair styling',
    'saree': 'Saree draping',
  };
  static const _team = {
    'punctuality': 'Punctuality',
    'professionalism': 'Professionalism',
    'communication': 'Communication',
    'politeness': 'Politeness & attitude',
    'handlingRequests': 'Handling requests',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(reviewInsightsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(reviewInsightsProvider)),
      data: (a) => RefreshIndicator(
        onRefresh: () async => ref.refreshData.reviews(),
        child: a.totalSubmitted == 0
            ? _emptyState(crm, Icons.insights_outlined, 'No submitted reviews in this period',
                'Pick a longer period from the top bar.')
            : LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final left = [
                  _npsCard(crm, a),
                  const SizedBox(height: 12),
                  _barsCard(crm, 'Service ratings', _bride, a.categoryAverages),
                  const SizedBox(height: 12),
                  _barsCard(crm, 'Team behaviour', _team, a.categoryAverages),
                ];
                final right = [
                  Row(children: [
                    Expanded(child: _countCard(crm, Icons.report_problem_outlined, '${a.complaints}', 'Complaints', crm.warning)),
                    const SizedBox(width: 10),
                    Expanded(child: _countCard(crm, Icons.event_repeat_outlined, '${a.followUps}', 'Follow-ups', crm.warning)),
                    const SizedBox(width: 10),
                    Expanded(child: _countCard(crm, Icons.campaign_outlined, '${a.testimonialsAvailable}', 'Testimonials', crm.success)),
                  ]),
                  const SizedBox(height: 12),
                  _leaderboard(crm, a.perArtist),
                ];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  children: wide
                      ? [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: Column(children: left)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(children: right)),
                          ]),
                        ]
                      : [...left, const SizedBox(height: 12), ...right],
                );
              }),
      ),
    );
  }

  Widget _section(CrmTheme crm, String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _cardBox(crm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _barsCard(CrmTheme crm, String title, Map<String, String> labels, Map<String, double> avgs) =>
      _section(crm, title, [
        for (final e in labels.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(
                width: 150,
                child: Text(e.value, style: TextStyle(fontSize: 13, color: crm.textSecondary)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ((avgs[e.key] ?? 0) / 5).clamp(0, 1).toDouble(),
                    minHeight: 8,
                    backgroundColor: crm.border,
                    color: _scoreColor(crm, avgs[e.key] ?? 0),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 30,
                child: Text((avgs[e.key] ?? 0) > 0 ? _n(avgs[e.key]!) : '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
              ),
            ]),
          ),
      ]);

  Widget _countCard(CrmTheme crm, IconData icon, String value, String label, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardBox(crm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary)),
          Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        ]),
      );

  Widget _npsCard(CrmTheme crm, ReviewAnalytics a) {
    Widget seg(int count, Color color) =>
        Expanded(flex: count == 0 ? 0 : count, child: Container(height: 12, color: color));
    Widget legend(String label, int count, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label  $count', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ]);
    return _section(crm, 'Net Promoter Score', [
      Row(children: [
        Text(a.npsResponses == 0 ? '—' : '${a.nps}',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _npsColor(crm, a.nps))),
        const SizedBox(width: 8),
        Text('${a.npsResponses} response${a.npsResponses == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: crm.textSecondary)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(children: [
          seg(a.promoters, crm.success),
          seg(a.passives, crm.textSecondary.withValues(alpha: 0.4)),
          seg(a.detractors, crm.warning),
          if (a.npsResponses == 0) seg(1, crm.border),
        ]),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        legend('Promoters (9–10)', a.promoters, crm.success),
        legend('Passives (7–8)', a.passives, crm.textSecondary.withValues(alpha: 0.6)),
        legend('Detractors (0–6)', a.detractors, crm.warning),
      ]),
    ]);
  }

  Widget _leaderboard(CrmTheme crm, List<ArtistStat> list) => _section(crm, 'Artist leaderboard', [
        if (list.isEmpty)
          Text('No per-artist data yet.', style: TextStyle(color: crm.textSecondary, fontSize: 13))
        else
          for (final e in list.asMap().entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: crm.primary.withValues(alpha: e.key < 3 ? 0.18 : 0.08),
                  child: Text('${e.key + 1}',
                      style: TextStyle(color: crm.primary, fontWeight: FontWeight.w800, fontSize: 11.5)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.value.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    Text('${e.value.count} review${e.value.count == 1 ? '' : 's'} · bride ${_n(e.value.avgBrideScore)}',
                        style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                  ]),
                ),
                Icon(Icons.star_rounded, size: 16, color: _scoreColor(crm, e.value.avgTeamScore)),
                const SizedBox(width: 2),
                Text(_n(e.value.avgTeamScore),
                    style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
              ]),
            ),
      ]);
}

// ── Detail ───────────────────────────────────────────────────────────────────

class ReviewDetailScreen extends ConsumerStatefulWidget {
  final String reviewId;
  const ReviewDetailScreen({super.key, required this.reviewId});

  @override
  ConsumerState<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends ConsumerState<ReviewDetailScreen> {
  Review? _r;
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  // editable internal state
  late bool _complaint, _compliment, _followUp, _reviewPosted, _referral;
  final _commentsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(reviewServiceProvider).getById(widget.reviewId);
      _complaint = r.complaint;
      _compliment = r.compliment;
      _followUp = r.followUpRequired;
      _reviewPosted = r.reviewPosted;
      _referral = r.referralOpportunity;
      _commentsCtrl.text = r.managerComments;
      if (mounted) setState(() { _r = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reviewServiceProvider).updateInternal(
            widget.reviewId,
            complaint: _complaint,
            compliment: _compliment,
            followUpRequired: _followUp,
            reviewPosted: _reviewPosted,
            referralOpportunity: _referral,
            managerComments: _commentsCtrl.text.trim(),
          );
      // List, analytics and artist performance all derive from these flags.
      ref.refreshData.reviews();
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        title: Text(_r?.brideName.isNotEmpty == true ? _r!.brideName : 'Review'),
        backgroundColor: crm.surface,
        foregroundColor: crm.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppErrorView(error: _error!, onRetry: () {
                  setState(() { _loading = true; _error = null; });
                  _load();
                })
              : _body(crm, _r!),
    );
  }

  Widget _body(CrmTheme crm, Review r) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        // Header scores
        Row(
          children: [
            Expanded(child: _bigStat(crm, '${r.brideScore}', 'Bride score /5')),
            8.0.gap,
            Expanded(child: _bigStat(crm, '${r.teamMemberScore}', 'Team score /5')),
            8.0.gap,
            Expanded(child: _bigStat(crm, r.nps == null ? '—' : '${r.nps}', 'NPS /10')),
          ],
        ),
        12.0.vgap,
        _card(crm, 'Booking', [
          _kv(crm, 'Booking #', r.bookingNumber),
          _kv(crm, 'Wedding date', _date(r.weddingDate)),
          _kv(crm, 'Venue', r.venue),
          _kv(
            crm,
            'Team',
            r.teamMembers.isNotEmpty
                ? r.teamMembers
                    .map((m) => m.role.isNotEmpty ? '${m.name} (${m.role})' : m.name)
                    .join(', ')
                : r.artistName,
          ),
          _kv(crm, 'Submitted', _date(r.submittedAt)),
        ]),
        _card(crm, 'Ratings', [
          _rating(crm, 'Overall experience', r.overall),
          _rating(crm, 'Makeup quality', r.makeup),
          _rating(crm, 'Hair styling', r.hair),
          _rating(crm, 'Saree draping / styling', r.saree),
        ]),
        _card(crm, 'Team behaviour', [
          _rating(crm, 'Punctuality', r.teamBehaviour['punctuality'] ?? 0),
          _rating(crm, 'Professionalism', r.teamBehaviour['professionalism'] ?? 0),
          _rating(crm, 'Communication', r.teamBehaviour['communication'] ?? 0),
          _rating(crm, 'Politeness & attitude', r.teamBehaviour['politeness'] ?? 0),
          _rating(crm, 'Handling requests', r.teamBehaviour['handlingRequests'] ?? 0),
        ]),
        _card(crm, 'Experience', [
          _kv(crm, 'Look vs expectation', _lookMatch[r.lookMatch] ?? '—'),
          _kv(crm, 'Comfortable & confident', _comfortable[r.comfortable] ?? '—'),
          _kv(crm, 'Would recommend', _yesMaybe[r.recommend] ?? '—'),
          _kv(crm, 'Would book again', _yesMaybe[r.bookAgain] ?? '—'),
          if (r.likedMost.isNotEmpty) _para(crm, 'Liked most', r.likedMost),
          if (r.couldBeBetter.isNotEmpty) _para(crm, 'Could be better', r.couldBeBetter),
        ]),
        _card(crm, 'Team member — ${r.artistName.isEmpty ? "review" : r.artistName}', [
          _rating(crm, 'Skill', r.teamMember['skill'] ?? 0),
          _rating(crm, 'Attention to detail', r.teamMember['attention'] ?? 0),
          _rating(crm, 'Time management', r.teamMember['timeManagement'] ?? 0),
          _rating(crm, 'Professionalism', r.teamMember['professionalism'] ?? 0),
          _rating(crm, 'Communication', r.teamMember['communication'] ?? 0),
          _rating(crm, 'Overall performance', r.teamMember['overall'] ?? 0),
          if (r.teamMemberDidWell.isNotEmpty) _para(crm, 'Did well', r.teamMemberDidWell),
          if (r.teamMemberImprove.isNotEmpty) _para(crm, 'Can improve', r.teamMemberImprove),
        ]),
        if (r.testimonial.isNotEmpty ||
            r.marketingConsent ||
            r.instagram.isNotEmpty)
          _card(crm, 'Testimonial & marketing', [
            if (r.testimonial.isNotEmpty) _para(crm, 'Testimonial', r.testimonial),
            _kv(crm, 'Marketing consent', r.marketingConsent ? 'Yes ✅' : 'No'),
            _kv(crm, 'Tag consent', r.tagConsent ? 'Yes' : 'No'),
            if (r.instagram.isNotEmpty) _kv(crm, 'Instagram', r.instagram),
          ]),

        // Internal — management (editable)
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: crm.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.lock_outline, size: 16, color: crm.primary),
                6.0.gap,
                Text('Internal — management only',
                    style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary)),
              ]),
              4.0.vgap,
              _sw(crm, 'Complaint', _complaint, (v) => setState(() => _complaint = v)),
              _sw(crm, 'Compliment', _compliment, (v) => setState(() => _compliment = v)),
              _sw(crm, 'Follow-up required', _followUp, (v) => setState(() => _followUp = v)),
              _sw(crm, 'Review posted', _reviewPosted, (v) => setState(() => _reviewPosted = v)),
              _sw(crm, 'Referral opportunity', _referral, (v) => setState(() => _referral = v)),
              8.0.vgap,
              TextField(
                controller: _commentsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Manager comments',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              12.0.vgap,
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: crm.primary),
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
            ],
          ),
        ),
        if (Access.of(ref.watch(authSessionProvider)).canSeeCrmWork) _ReviewCrmCases(review: r),
      ],
    );
  }

  Widget _bigStat(CrmTheme crm, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: crm.primary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: crm.textSecondary), textAlign: TextAlign.center),
        ]),
      );

  Widget _card(CrmTheme crm, String title, List<Widget> children) {
    final visible = children.whereType<Widget>().toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
          8.0.vgap,
          ...visible,
        ],
      ),
    );
  }

  Widget _rating(CrmTheme crm, String label, int value) {
    if (value <= 0) {
      return _row(crm, label, 'N/A');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: crm.textSecondary, fontSize: 13))),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 16,
                color: i < value ? crm.primary : crm.border,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(CrmTheme crm, String k, String v) {
    if (v.trim().isEmpty) return const SizedBox.shrink();
    return _row(crm, k, v);
  }

  Widget _row(CrmTheme crm, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(k, style: TextStyle(color: crm.textSecondary, fontSize: 13)),
            ),
            Expanded(
              child: Text(v,
                  style: TextStyle(color: crm.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _para(CrmTheme crm, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: TextStyle(color: crm.textSecondary, fontSize: 12)),
            2.0.vgap,
            Text(v, style: TextStyle(color: crm.textPrimary, fontSize: 13)),
          ],
        ),
      );

  Widget _sw(CrmTheme crm, String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: TextStyle(color: crm.textPrimary, fontSize: 14)),
        value: value,
        activeThumbColor: crm.primary,
        onChanged: onChanged,
      );
}

// Small spacing helpers local to this screen.
extension _Gap on double {
  Widget get gap => SizedBox(width: this);
  Widget get vgap => SizedBox(height: this);
}


/// The CRM case(s) this review opened (an unhappy client or a follow-up opens one by itself): view it — or, for a flagged review with
/// none, open one by hand.
class _ReviewCrmCases extends ConsumerWidget {
  const _ReviewCrmCases({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final cases = ref.watch(crmCasesForReviewProvider(review.id));
    final me = ref.watch(crmMeProvider).value;
    final flagged = review.complaint || review.followUpRequired;
    return CrmPanel(
      key: const Key('reviewCrmCases'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: cases.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary)),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CRM case', style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
            const SizedBox(height: 6),
            for (final c in list)
              ListTile(
                key: Key('reviewCase_${c.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(c.isOpen ? Icons.report_problem_outlined : Icons.check_circle_outline, color: c.isOpen ? crm.warning : crm.success),
                title: Text('${c.caseNumber} · ${c.kindLabel}'),
                subtitle: Text('${c.statusLabel}${c.ownerName.isEmpty ? ' · not assigned' : ' · ${c.ownerName}'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/crm/cases/${c.id}'),
              ),
            if (list.isEmpty)
              Text(flagged ? 'No case yet.' : 'No case — none is needed for a happy client.', style: TextStyle(color: crm.textSecondary)),
            if (list.isEmpty && flagged && me != null && me.canWrite) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('reviewOpenCase'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Open a case'),
                onPressed: () async {
                  final c = await showCrmNewCaseDialog(context, ref, me: me, initial: {
                    'kind': review.complaint ? 'complaint' : 'follow_up',
                    'reviewId': review.id,
                    'customerName': review.brideName,
                  });
                  if (c != null && context.mounted) context.go('/crm/cases/${c.id}');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
