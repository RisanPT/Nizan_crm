import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/reviews/data/review.dart';
import 'package:nizan_crm/features/reviews/services/review_service.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime? d) => d == null ? '' : '${d.day} ${_mon[d.month]} ${d.year}';

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

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(
          title: const Text('Client Reviews'),
          backgroundColor: crm.surface,
          foregroundColor: crm.textPrimary,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: crm.primary,
            labelColor: crm.primary,
            unselectedLabelColor: crm.textSecondary,
            tabs: const [Tab(text: 'Reviews'), Tab(text: 'Insights')],
          ),
        ),
        body: TabBarView(
          children: [
            _reviewsTab(context, ref, crm),
            const _InsightsTab(),
          ],
        ),
      ),
    );
  }

  Widget _reviewsTab(BuildContext context, WidgetRef ref, CrmTheme crm) {
    final filter = ref.watch(reviewFilterProvider);
    final async = ref.watch(reviewsProvider);
    return Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _chip(ref, crm, 'Submitted', filter.status == 'submitted' && !filter.complaint,
                    () => ref.read(reviewFilterProvider.notifier).state =
                        const ReviewFilter(status: 'submitted')),
                8.0.gap,
                _chip(ref, crm, 'All', filter.status == 'all' && !filter.complaint,
                    () => ref.read(reviewFilterProvider.notifier).state =
                        const ReviewFilter(status: 'all')),
                8.0.gap,
                _chip(ref, crm, 'Needs follow-up', filter.complaint,
                    () => ref.read(reviewFilterProvider.notifier).state =
                        const ReviewFilter(status: 'submitted', complaint: true)),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  AppErrorView(error: e, onRetry: () => ref.invalidate(reviewsProvider)),
              data: (reviews) {
                if (reviews.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reviews_outlined, size: 52, color: crm.textSecondary),
                        const SizedBox(height: 10),
                        Text('No reviews yet.', style: TextStyle(color: crm.textSecondary)),
                        const SizedBox(height: 2),
                        Text('Reviews appear here once brides submit the form.',
                            style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(reviewsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: reviews.length,
                    itemBuilder: (_, i) => _reviewCard(context, crm, reviews[i]),
                  ),
                );
              },
            ),
          ),
        ],
      );
  }

  Widget _chip(WidgetRef ref, CrmTheme crm, String label, bool sel, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => onTap(),
      selectedColor: crm.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: sel ? crm.primary : crm.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _reviewCard(BuildContext context, CrmTheme crm, Review r) {
    final pending = !r.isSubmitted;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.complaint ? crm.warning : crm.border),
      ),
      child: ListTile(
        onTap: pending
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReviewDetailScreen(reviewId: r.id)),
                ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                r.brideName.isEmpty ? 'Bride' : r.brideName,
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (pending)
              _badge(crm, 'Awaiting', crm.textSecondary)
            else ...[
              _scorePill(crm, '${r.brideScore}★'),
              if (r.nps != null) ...[6.0.gap, _badge(crm, 'NPS ${r.nps}', crm.accent)],
            ],
          ],
        ),
        subtitle: Text(
          [
            if (r.artistName.isNotEmpty) r.artistName,
            if (r.bookingNumber.isNotEmpty) '#${r.bookingNumber}',
            _date(r.submittedAt ?? r.createdAt),
            if (r.complaint) '⚠ needs follow-up',
          ].where((s) => s.isNotEmpty).join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: pending ? null : const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _scorePill(CrmTheme crm, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: crm.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(text,
            style: TextStyle(color: crm.primary, fontWeight: FontWeight.w800, fontSize: 12)),
      );

  Widget _badge(CrmTheme crm, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      );
}

// ── Insights ─────────────────────────────────────────────────────────────────

class _InsightsTab extends ConsumerWidget {
  const _InsightsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(reviewAnalyticsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
          error: e, onRetry: () => ref.invalidate(reviewAnalyticsProvider)),
      data: (a) {
        if (a.totalSubmitted == 0) {
          return Center(
            child: Text('No submitted reviews yet.',
                style: TextStyle(color: crm.textSecondary)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(reviewAnalyticsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
            children: [
              Row(children: [
                Expanded(child: _stat(crm, '${a.totalSubmitted}', 'Reviews', crm.primary)),
                8.0.gap,
                Expanded(child: _stat(crm, _n(a.avgBrideScore), 'Bride avg /5', crm.accent)),
                8.0.gap,
                Expanded(child: _stat(crm, _n(a.avgTeamScore), 'Team avg /5', crm.accent)),
              ]),
              8.0.vgap,
              Row(children: [
                Expanded(child: _stat(crm, '${a.nps}', 'NPS', _npsColor(crm, a.nps))),
                8.0.gap,
                Expanded(child: _stat(crm, '${a.pending}', 'Awaiting', crm.textSecondary)),
                8.0.gap,
                Expanded(child: _stat(crm, '${a.testimonialsAvailable}', 'Testimonials', crm.success)),
              ]),
              14.0.vgap,
              _npsCard(crm, a),
              12.0.vgap,
              Row(children: [
                Expanded(child: _countCard(crm, Icons.report_problem_outlined,
                    '${a.complaints}', 'Complaints', crm.warning)),
                10.0.gap,
                Expanded(child: _countCard(crm, Icons.event_repeat_outlined,
                    '${a.followUps}', 'Follow-ups', crm.warning)),
              ]),
              18.0.vgap,
              Text('Artist leaderboard',
                  style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
              8.0.vgap,
              if (a.perArtist.isEmpty)
                Text('No per-artist data yet.',
                    style: TextStyle(color: crm.textSecondary, fontSize: 13))
              else
                ...a.perArtist.asMap().entries.map((e) => _artistRow(crm, e.key + 1, e.value)),
            ],
          ),
        );
      },
    );
  }

  String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Color _npsColor(CrmTheme crm, int nps) =>
      nps >= 50 ? crm.success : (nps >= 0 ? crm.accent : crm.warning);

  Widget _stat(CrmTheme crm, String value, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _countCard(CrmTheme crm, IconData icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          10.0.gap,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ]),
        ]),
      );

  Widget _npsCard(CrmTheme crm, ReviewAnalytics a) {
    final total = a.npsResponses == 0 ? 1 : a.npsResponses;
    Widget seg(int count, Color color) => Expanded(
          flex: count == 0 ? 0 : count,
          child: Container(height: 12, color: color),
        );
    Widget legend(String label, int count, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            6.0.gap,
            Text('$label  $count', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Net Promoter Score',
              style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const Spacer(),
          Text('${a.nps}',
              style: TextStyle(fontWeight: FontWeight.w900, color: _npsColor(crm, a.nps))),
        ]),
        10.0.vgap,
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            seg(a.promoters, crm.success),
            seg(a.passives, crm.textSecondary.withValues(alpha: 0.4)),
            seg(a.detractors, crm.warning),
            if (a.npsResponses == 0) seg(1, crm.border),
          ]),
        ),
        10.0.vgap,
        Wrap(spacing: 14, runSpacing: 6, children: [
          legend('Promoters', a.promoters, crm.success),
          legend('Passives', a.passives, crm.textSecondary.withValues(alpha: 0.6)),
          legend('Detractors', a.detractors, crm.warning),
        ]),
        6.0.vgap,
        Text('$total response${total == 1 ? '' : 's'} · 9–10 promote, 0–6 detract',
            style: TextStyle(fontSize: 11, color: crm.textSecondary)),
      ]),
    );
  }

  Widget _artistRow(CrmTheme crm, int rank, ArtistStat s) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: crm.primary.withValues(alpha: 0.1),
            child: Text('$rank',
                style: TextStyle(color: crm.primary, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          10.0.gap,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.artistName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${s.count} review${s.count == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              Icon(Icons.star_rounded, size: 15, color: crm.primary),
              2.0.gap,
              Text(_n(s.avgTeamScore),
                  style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
            ]),
            Text('bride ${_n(s.avgBrideScore)}',
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ]),
        ]),
      );
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
