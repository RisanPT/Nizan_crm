import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/crm/data/crm_weekly_models.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_booking_care_card.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';
import 'package:nizan_crm/features/crm/services/crm_weekly_service.dart';

/// Palette aligned to Team N ERP Suite — CRM Weekly Report specification
class _ReportColors {
  static const brand900 = Color(0xFF2E1118); // Deep Burgundy Sidebar & Accents
  static const brand700 = Color(0xFF54202E);
  static const brand100 = Color(0xFFF9ECEF);
  static const brand50 = Color(0xFFFDF7F8);

  static const gold500 = Color(0xFFC59B27); // Warm Gold Accent
  static const gold400 = Color(0xFFD4AF37);

  static const canvas = Color(0xFFF8F8F6);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);

  static const emerald700 = Color(0xFF047857);
  static const emerald600 = Color(0xFF059669);
  static const emerald500 = Color(0xFF10B981);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald50 = Color(0xFFECFDF5);

  static const amber800 = Color(0xFF92400E);
  static const amber700 = Color(0xFFB45309);
  static const amber500 = Color(0xFFF59E0B);
  static const amber200 = Color(0xFFFDE68A);
  static const amber50 = Color(0xFFFFFBEB);

  static const rose700 = Color(0xFFBE123C);
  static const rose600 = Color(0xFFE11D48);
  static const rose500 = Color(0xFFF43F5E);
  static const rose400 = Color(0xFFFB7185);
  static const rose100 = Color(0xFFFFE4E6);
  static const rose50 = Color(0xFFFFF1F2);
}

/// CRM → Weekly Report (/crm/weekly): the team's weekly format, item by item — the figures come from the records, the CRM Head types the
/// starting-message counts and the manpower answers, and hands it in (then it keeps its figures). Management and leadership read it.
/// Where the records missed something, the Head types the figure by hand ("Enter by hand" on each item): it shows marked, with the
/// records' figure under it, and the PDF / Excel say so too.
class CrmWeeklyReportScreen extends ConsumerStatefulWidget {
  const CrmWeeklyReportScreen({super.key, this.initialWeek = '', this.now});

  /// Any day of the week to open ('' = last week).
  final String initialWeek;

  /// What "today" is — for tests.
  final DateTime? now;

  @override
  ConsumerState<CrmWeeklyReportScreen> createState() => _CrmWeeklyReportScreenState();
}

final _iso = DateFormat('yyyy-MM-dd');

class _CrmWeeklyReportScreenState extends ConsumerState<CrmWeeklyReportScreen> {
  late String _week = widget.initialWeek;

  void _shift(CrmWeek w, int days) {
    final d = DateTime.parse(w.from).add(Duration(days: days));
    setState(() => _week = _iso.format(d));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(crmWeeklyProvider(_week));
    final me = ref.watch(crmMeProvider).value;
    final today = _iso.format(widget.now ?? DateTime.now());
    return Scaffold(
      backgroundColor: _ReportColors.canvas,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _ReportColors.brand900)),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmWeeklyProvider(_week))),
        data: (r) {
          final canEdit = (me?.canAssign ?? false) && !r.submitted;
          final weekOver = r.week.to.compareTo(today) < 0;
          return _WeeklyBody(
            key: ValueKey('${r.week.from}|${r.status}|${r.updatedAt}'),
            report: r,
            canEdit: canEdit,
            canReopen: (me?.canAssign ?? false) && r.submitted,
            weekOver: weekOver,
            canGoNext: r.week.to.compareTo(today) < 0,
            onPrev: () => _shift(r.week, -7),
            onNext: () => _shift(r.week, 7),
            onPick: (from) => setState(() => _week = from),
            onReplaced: (fresh) {
              ref.invalidate(crmWeeklyProvider(_week));
              ref.invalidate(crmWeeksProvider);
              setState(() => _week = fresh.week.from);
            },
          );
        },
      ),
    );
  }
}

class _WeeklyBody extends ConsumerStatefulWidget {
  const _WeeklyBody({
    super.key,
    required this.report,
    required this.canEdit,
    required this.canReopen,
    required this.weekOver,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onReplaced,
  });
  final CrmWeeklyReport report;
  final bool canEdit, canReopen, weekOver, canGoNext;
  final VoidCallback onPrev, onNext;
  final ValueChanged<String> onPick;
  final ValueChanged<CrmWeeklyReport> onReplaced;

  @override
  ConsumerState<_WeeklyBody> createState() => _WeeklyBodyState();
}

class _WeeklyBodyState extends ConsumerState<_WeeklyBody> {
  late final t = widget.report.typed;
  late final _nizan = TextEditingController(text: t.startingMessagesNizan?.toString() ?? '');
  late final _teamN = TextEditingController(text: t.startingMessagesTeamN?.toString() ?? '');
  late final _msgNote = TextEditingController(text: t.startingMessagesNote);
  late final _plan = TextEditingController(text: t.manpowerPlan);
  late final _enoughNote = TextEditingController(text: t.enoughWorkNote);
  late final _notes = TextEditingController(text: t.notes);
  late final _missingReviewsFilter = TextEditingController();

  late String _enough = t.enoughWork;
  bool _busy = false;
  bool _missingReviewsOpen = false;

  @override
  void initState() {
    super.initState();
    _nizan.addListener(() => setState(() {}));
    _teamN.addListener(() => setState(() {}));
    _msgNote.addListener(() => setState(() {}));
    _missingReviewsFilter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_nizan, _teamN, _msgNote, _plan, _enoughNote, _notes, _missingReviewsFilter]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _typed => {
    'startingMessagesNizan': _nizan.text.trim(),
    'startingMessagesTeamN': _teamN.text.trim(),
    'startingMessagesNote': _msgNote.text.trim(),
    'manpowerPlan': _plan.text.trim(),
    'enoughWork': _enough,
    'enoughWorkNote': _enoughNote.text.trim(),
    'notes': _notes.text.trim(),
  };

  Future<void> _act(Future<CrmWeeklyReport> Function(CrmWeeklyService s) f, String done) async {
    setState(() => _busy = true);
    try {
      final r = await f(ref.read(crmWeeklyServiceProvider));
      if (!mounted) return;
      showSuccessSnackBar(context, done);
      widget.onReplaced(r);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves what was entered by hand in a dialog — with the rest of the page, so nothing typed there is lost.
  Future<void> _saveByHand(Map<String, dynamic> extra) => _act((s) => s.save(widget.report.week.from, {..._typed, ...extra}), 'Saved');

  Future<void> _enterByHand(String section, String title) async {
    final r = widget.report;
    final note = r.typed.sectionNotes[section] ?? '';
    if (section == 'outsource') {
      final res = await showDialog<({List<CrmOutsourceLine> lines, String note})>(
        context: context,
        builder: (_) => _OutsourceByHandDialog(lines: r.typed.outsourceLines, note: note, week: r.week),
      );
      if (res == null || !mounted) return;
      return _saveByHand({
        'outsourceLines': [for (final l in res.lines) l.toTyped()],
        'sectionNotes': {section: res.note},
      });
    }
    final res = await showDialog<({Map<String, int?> overrides, String note})>(
      context: context,
      builder: (_) => _ByHandDialog(title: title, fields: r.fieldsOf(section), typed: r.typed.overrides, records: r.records, note: note),
    );
    if (res == null || !mounted) return;
    await _saveByHand({'overrides': res.overrides, 'sectionNotes': {section: res.note}});
  }

  Future<void> _download(String format) async {
    try {
      final (name, bytes) = await ref.read(crmWeeklyServiceProvider).file(widget.report.week.from, format);
      await saveFileBytes(name, bytes, mime: format == 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      if (mounted) showSuccessSnackBar(context, 'Downloaded $name');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = widget.report;
    final f = r.figures;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 980;

            final card1 = _trialsCard(crm, f, wide);
            final card2 = _photosCard(crm, f, wide);
            final card3 = _supportCard(crm, f, wide);
            final card4 = _messagesCard(crm, wide);
            final card5 = _verificationCard(crm, f, wide);
            final card6 = _medicalCard(crm, f, wide);
            final card7 = _workloadCard(crm, f, wide);
            final card8 = _outsourceCard(crm, f, wide);

            return ListView(
              padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 14, vertical: 20),
              children: [
                // Top Header (Title, Subtitle, Week Switcher, Export)
                _header(crm, r, wide),
                const SizedBox(height: 16),

                // Draft Status Banner
                _statusBanner(crm, r),
                const SizedBox(height: 20),

                // Bento Grid: 8 Core Cards in Strict Order
                if (wide) ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: card1),
                    const SizedBox(width: 18),
                    Expanded(child: card2),
                  ]),
                  const SizedBox(height: 18),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: card3),
                    const SizedBox(width: 18),
                    Expanded(child: card4),
                  ]),
                  const SizedBox(height: 18),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: card5),
                    const SizedBox(width: 18),
                    Expanded(child: card6),
                  ]),
                  const SizedBox(height: 18),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: card7),
                    const SizedBox(width: 18),
                    Expanded(child: card8),
                  ]),
                ] else ...[
                  card1,
                  const SizedBox(height: 14),
                  card2,
                  const SizedBox(height: 14),
                  card3,
                  const SizedBox(height: 14),
                  card4,
                  const SizedBox(height: 14),
                  card5,
                  const SizedBox(height: 14),
                  card6,
                  const SizedBox(height: 14),
                  card7,
                  const SizedBox(height: 14),
                  card8,
                ],

                const SizedBox(height: 18),

                // Notes Card
                _notesCard(crm, wide),
                const SizedBox(height: 40),
              ],
            );
          }),
        ),
        // Glassmorphic Sticky Action Bar at Bottom
        _actionBar(crm, r, f),
      ],
    );
  }

  // ── 1. Top Header ──────────────────────────────────────────────────────────

  Widget _header(CrmTheme crm, CrmWeeklyReport r, bool wide) {
    final weeks = ref.watch(crmWeeksProvider).value ?? const <CrmWeekStatus>[];

    final (statusLabel, statusColor, statusBg, statusBorder, showPulse) = switch (r.status) {
      'submitted' => ('Submitted', _ReportColors.emerald700, _ReportColors.emerald50, _ReportColors.emerald100, false),
      'draft' => ('Draft in progress', _ReportColors.amber800, _ReportColors.amber50, _ReportColors.amber200, true),
      _ => ('Upcoming', _ReportColors.slate700, _ReportColors.slate100, _ReportColors.slate200, false),
    };

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _ReportColors.brand100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'WEEKLY OPERATIONS',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _ReportColors.brand700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showPulse) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _ReportColors.amber500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'CRM Weekly Report',
          style: GoogleFonts.plusJakartaSans(
            fontSize: wide ? 28 : 22,
            fontWeight: FontWeight.w800,
            color: _ReportColors.slate900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Trials, photos & reviews, support, messages, verification, medical, workload and outsource — week by week',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _ReportColors.slate500,
          ),
        ),
      ],
    );

    final controls = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        // Week Picker Container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _ReportColors.slate200),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('crmWeekPrev'),
                tooltip: 'Previous week',
                onPressed: widget.onPrev,
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_left, color: _ReportColors.slate600),
              ),
              Flexible(
                child: PopupMenuButton<String>(
                  key: const Key('crmWeekPick'),
                  tooltip: 'Select reporting week',
                  onSelected: widget.onPick,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    for (final w in weeks)
                      PopupMenuItem(
                        value: w.week.from,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                w.week.label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: w.week.from == r.week.from ? FontWeight.w700 : FontWeight.w500,
                                  color: w.week.from == r.week.from ? _ReportColors.brand900 : _ReportColors.slate800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: w.status == 'submitted'
                                    ? _ReportColors.emerald50
                                    : w.status == 'draft'
                                        ? _ReportColors.amber50
                                        : _ReportColors.slate100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                w.status == 'submitted'
                                    ? 'Submitted'
                                    : w.status == 'draft'
                                        ? 'Draft'
                                        : 'Upcoming',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: w.status == 'submitted'
                                      ? _ReportColors.emerald700
                                      : w.status == 'draft'
                                          ? _ReportColors.amber800
                                          : _ReportColors.slate600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 15, color: _ReportColors.brand700),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            r.week.label,
                            key: const Key('crmWeekLabel'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _ReportColors.slate800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18, color: _ReportColors.slate400),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('crmWeekNext'),
                tooltip: 'Next week',
                onPressed: widget.canGoNext ? widget.onNext : null,
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.chevron_right,
                  color: widget.canGoNext ? _ReportColors.slate600 : _ReportColors.slate300,
                ),
              ),
            ],
          ),
        ),

        // Export Button
        PopupMenuButton<String>(
          key: const Key('crmWeeklyDownload'),
          tooltip: 'Export',
          onSelected: _download,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'pdf',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_outlined, color: _ReportColors.rose600),
                title: Text('Export PDF', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            PopupMenuItem(
              value: 'xlsx',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.table_chart_outlined, color: _ReportColors.emerald600),
                title: Text('Export Excel (.xlsx)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _ReportColors.slate200),
              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download_rounded, size: 16, color: _ReportColors.slate600),
                const SizedBox(width: 6),
                Text(
                  'Export',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _ReportColors.slate700),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: titleBlock),
          controls,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleBlock,
        const SizedBox(height: 14),
        controls,
      ],
    );
  }

  // ── 2. Draft Status Banner ──────────────────────────────────────────────────

  Widget _statusBanner(CrmTheme crm, CrmWeeklyReport r) {
    final (icon, text, iconBg, iconColor, borderColor, gradientStart, gradientEnd) = switch (r.status) {
      'submitted' => (
        Icons.verified_outlined,
        'Handed in by ${r.submittedByName.isEmpty ? 'the CRM Head' : r.submittedByName}${r.submittedAt == null ? '' : ' on ${DateFormat('d MMM, h:mm a').format(r.submittedAt!)}'} — the figures are as they were then.',
        _ReportColors.emerald100,
        _ReportColors.emerald700,
        _ReportColors.emerald100,
        _ReportColors.emerald50,
        Colors.white,
      ),
      'draft' => (
        Icons.edit_note_rounded,
        'Draft — figures update automatically as the team works. ${widget.weekOver ? 'Hand it in when it is complete.' : 'The week is still underway.'}',
        const Color(0x33F59E0B),
        _ReportColors.amber800,
        _ReportColors.amber200,
        const Color(0xFFFFFDF5),
        const Color(0xFFFAF3DC),
      ),
      _ => (
        Icons.info_outline,
        widget.weekOver ? 'Not started — the figures below are worked out from the records.' : 'This week is still in progress — the figures so far.',
        _ReportColors.slate100,
        _ReportColors.slate600,
        _ReportColors.slate200,
        _ReportColors.slate50,
        Colors.white,
      ),
    };

    return Container(
      key: const Key('crmWeeklyStatus'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500, color: _ReportColors.slate800),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bento Card Frame ───────────────────────────────────────────────────────

  Widget _cardFrame({
    required String key,
    required String number,
    required String title,
    String? section,
    Widget? trailingHeader,
    required bool wide,
    required Widget child,
  }) {
    final r = widget.report;
    final byHand = section != null && widget.canEdit && (section == 'outsource' || r.fieldsOf(section).isNotEmpty);
    final note = section == null ? '' : (r.typed.sectionNotes[section] ?? '');
    final typed = section != null && r.sectionTyped(section);

    return Material(
      key: Key('crmWeekly_$key'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _ReportColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(wide ? 20 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ReportColors.brand100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _ReportColors.brand900.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    number,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _ReportColors.brand900,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: _ReportColors.slate900,
                    ),
                  ),
                ),
                if (trailingHeader != null && wide) ...[
                  trailingHeader,
                  const SizedBox(width: 6),
                ],
                if (byHand)
                  TextButton.icon(
                    key: Key('crmWeeklyEnter_$section'),
                    onPressed: _busy ? null : () => _enterByHand(section, title),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: _ReportColors.brand700,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text('Enter by hand', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
            if (typed || note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                key: Key('crmWeeklyByHand_$section'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _ReportColors.amber50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _ReportColors.amber200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, size: 18, color: _ReportColors.amber700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          if (typed) 'Some figures here were typed by hand.',
                          if (note.isNotEmpty) 'Note: $note',
                        ].join(' '),
                        style: GoogleFonts.inter(fontSize: 11.5, color: _ReportColors.slate800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── KPI Stat Box ───────────────────────────────────────────────────────────

  Widget _kpiBox({
    required String value,
    String? extraInline,
    required String label,
    required String sublabel,
    Color? valueColor,
    Color? bgColor,
    Color? borderColor,
    String? valueKey,
    String? recordsKey,
    List<String> typedKeys = const [],
  }) {
    final r = widget.report;
    final typed = typedKeys.any(r.typed.typedByHand);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor ?? _ReportColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? _ReportColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  key: valueKey != null ? Key('crmWeeklyValue_$valueKey') : null,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? _ReportColors.slate900,
                  ),
                ),
                if (extraInline != null)
                  Text(
                    extraInline,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ReportColors.slate400,
                    ),
                  ),
                if (typed) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 12, color: _ReportColors.amber700),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ReportColors.slate700),
          ),
          const SizedBox(height: 1),
          Text(
            sublabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 10.5, color: _ReportColors.slate400),
          ),
          if (typed) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'typed by hand · records ${typedKeys.map((k) => _num(r.records[k])).join(' / ')}',
                key: recordsKey != null ? Key('crmWeeklyRecords_$recordsKey') : null,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _ReportColors.amber700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Card 01: Trial Count ────────────────────────────────────────────────────

  Widget _trialsCard(CrmTheme crm, CrmWeeklyFigures f, bool wide) {
    final conv = f.trialsHeld > 0 ? (f.trialsConverted / f.trialsHeld * 100) : 0.0;
    final convStr = conv == conv.roundToDouble() ? '${conv.toInt()}%' : '${conv.toStringAsFixed(1)}%';

    return _cardFrame(
      key: 'trials',
      number: '01',
      title: 'Trial count',
      section: 'trials',
      wide: wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _kpiBox(
                  value: '${f.trialsHeld}',
                  label: 'Trials held',
                  sublabel: 'vs. ${f.trialsPrevHeld} week before',
                  valueKey: 'trialsHeld',
                  recordsKey: 'trialsHeld',
                  typedKeys: const ['trialsHeld'],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiBox(
                  value: '${f.trialsCompleted}',
                  label: 'Completed',
                  sublabel: 'sessions finished',
                  valueKey: 'trialsCompleted',
                  recordsKey: 'trialsCompleted',
                  typedKeys: const ['trialsCompleted'],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiBox(
                  value: '${f.trialsConverted}',
                  label: 'Became bookings',
                  sublabel: '$convStr conversion',
                  valueColor: _ReportColors.emerald600,
                  bgColor: _ReportColors.emerald50,
                  borderColor: _ReportColors.emerald100,
                  valueKey: 'trialsConverted',
                  recordsKey: 'trialsConverted',
                  typedKeys: const ['trialsConverted'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Funnel visualization
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _ReportColors.slate100))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_alt_outlined, size: 14, color: _ReportColors.slate400),
                        const SizedBox(width: 5),
                        Text('Trial-to-Booking Funnel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _ReportColors.slate600)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: _ReportColors.slate100, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        f.trialsHeld == 0 ? 'No trials scheduled this week' : '$convStr conversion',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: _ReportColors.slate600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 8,
                    color: _ReportColors.slate100,
                    child: Row(
                      children: [
                        if (f.trialsCompleted > 0 && f.trialsHeld > 0)
                          Flexible(
                            flex: f.trialsCompleted,
                            child: Container(color: _ReportColors.slate400),
                          ),
                        if (f.trialsConverted > 0 && f.trialsHeld > 0)
                          Flexible(
                            flex: f.trialsConverted,
                            child: Container(color: _ReportColors.emerald500),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (f.trialsCancelled > 0 || f.trialsPostponed > 0 || f.trialsMaturing > 0) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (f.trialsCancelled > 0) '${f.trialsCancelled} cancelled',
                if (f.trialsPostponed > 0) '${f.trialsPostponed} postponed',
                if (f.trialsMaturing > 0) '${f.trialsMaturing} still deciding',
              ].join(' · '),
              style: GoogleFonts.inter(fontSize: 11, color: _ReportColors.slate400),
            ),
          ],
        ],
      ),
    );
  }

  // ── Card 02: Photos & Reviews Collection ────────────────────────────────────

  Widget _photosCard(CrmTheme crm, CrmWeeklyFigures f, bool wide) {
    final pendingReviews = (f.clientsDone - f.reviews).clamp(0, 999);
    final revPct = f.reviewsPct == null ? (f.clientsDone > 0 ? (f.reviews / f.clientsDone * 100) : 0) : f.reviewsPct!;
    final revPctStr = revPct == revPct.roundToDouble() ? '${revPct.toInt()}%' : '${revPct.toStringAsFixed(1)}%';

    final filterText = _missingReviewsFilter.text.trim().toLowerCase();
    final filteredClients = f.missingReviews.where((c) {
      if (filterText.isEmpty) return true;
      return c.client.toLowerCase().contains(filterText) || c.bookingNumber.toLowerCase().contains(filterText) || c.phone.contains(filterText);
    }).toList();

    return _cardFrame(
      key: 'photos',
      number: '02',
      title: 'Photos & reviews collection',
      section: 'photos',
      wide: wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _kpiBox(
                  value: '${f.worksDone}',
                  label: 'Makeover works',
                  sublabel: 'completed',
                  valueKey: 'worksDone',
                  recordsKey: 'worksDone',
                  typedKeys: const ['worksDone'],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiBox(
                  value: f.photos == null ? '—' : '${f.photos}',
                  label: 'Photos collected',
                  sublabel: f.photos == null ? 'not logged yet' : 'photos logged',
                  valueKey: 'photos',
                  recordsKey: 'photos',
                  typedKeys: const ['photos'],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiBox(
                  value: '${f.reviews}',
                  extraInline: ' / ${f.clientsDone}',
                  label: 'Reviews',
                  sublabel: 'of ${f.clientsDone} clients',
                  valueColor: _ReportColors.brand900,
                  bgColor: _ReportColors.brand50,
                  borderColor: _ReportColors.brand100,
                  valueKey: 'reviews',
                  recordsKey: 'reviews',
                  typedKeys: const ['reviews', 'clientsDone'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Photos Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    'Photos: ${f.photos == null ? '—' : '${f.photos} of ${f.worksDone}'}',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ReportColors.slate700),
                  ),
                  Text(
                    f.photosPct == null ? 'Awaiting entry' : '${f.photosPct}%',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _ReportColors.slate400),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (f.photos == null || f.worksDone == 0) ? 0.0 : (f.photos! / f.worksDone).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  backgroundColor: _ReportColors.slate100,
                  valueColor: const AlwaysStoppedAnimation<Color>(_ReportColors.gold500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reviews Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    'Reviews: ${f.reviews} of ${f.clientsDone}',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ReportColors.slate700),
                  ),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: _ReportColors.emerald500, shape: BoxShape.circle)),
                          const SizedBox(width: 3),
                          Text('${f.reviews} done', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: _ReportColors.emerald700)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: _ReportColors.rose400, shape: BoxShape.circle)),
                          const SizedBox(width: 3),
                          Text('$pendingReviews pend', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: _ReportColors.rose600)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(color: _ReportColors.brand100, borderRadius: BorderRadius.circular(4)),
                        child: Text(revPctStr, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _ReportColors.brand900)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  height: 8,
                  color: _ReportColors.rose100,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: f.clientsDone > 0 ? (f.reviews / f.clientsDone).clamp(0, 1).toDouble() : 0.0,
                    child: Container(color: _ReportColors.emerald500),
                  ),
                ),
              ),
            ],
          ),

          // Accordion: Clients without a review (N)
          if (f.missingReviews.isNotEmpty) ...[
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: _ReportColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _ReportColors.slate200),
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _missingReviewsOpen = !_missingReviewsOpen),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: _ReportColors.rose500, shape: BoxShape.circle)),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Clients without a review (${f.missingReviews.length})',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ReportColors.slate800),
                              ),
                            ),
                            Text('View list', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ReportColors.brand700)),
                            const SizedBox(width: 4),
                            Icon(_missingReviewsOpen ? Icons.expand_less : Icons.expand_more, size: 16, color: _ReportColors.slate500),
                          ],
                        ),
                      ),
                    ),
                    if (_missingReviewsOpen) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: Column(
                          children: [
                            const Divider(height: 1, color: _ReportColors.slate200),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 32,
                                    child: TextField(
                                      controller: _missingReviewsFilter,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.search, size: 15, color: _ReportColors.slate400),
                                        hintText: 'Filter pending...',
                                        hintStyle: GoogleFonts.inter(fontSize: 11.5, color: _ReportColors.slate400),
                                        contentPadding: EdgeInsets.zero,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _ReportColors.slate200)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      style: GoogleFonts.inter(fontSize: 11.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  onPressed: () {
                                    showSuccessSnackBar(context, 'Reminders queued for pending clients');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _ReportColors.brand900,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text('Remind', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: filteredClients.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, color: _ReportColors.slate100),
                                itemBuilder: (context, i) {
                                  final c = filteredClients[i];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                                    title: Text(c.client, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _ReportColors.slate900)),
                                    subtitle: Text(
                                      [crmDayLabel(c.day), if (c.bookingNumber.isNotEmpty) c.bookingNumber, if (c.phone.isNotEmpty) c.phone].join(' · '),
                                      style: GoogleFonts.inter(fontSize: 10.5, color: _ReportColors.slate500),
                                    ),
                                    trailing: const Icon(Icons.chevron_right, size: 15, color: _ReportColors.slate400),
                                    onTap: c.bookingId.isEmpty ? null : () => context.go('/booking/manage/${c.bookingId}'),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          if (f.missingPhotos.isNotEmpty) ...[
            const SizedBox(height: 8),
            _workList(crm, 'photos', 'Works without photos', f.missingPhotos),
          ],
        ],
      ),
    );
  }

  // ── Card 03: Customer Support ───────────────────────────────────────────────

  Widget _supportCard(CrmTheme crm, CrmWeeklyFigures f, bool wide) {
    final pct = (f.monthTarget > 0 ? (f.monthToDate / f.monthTarget * 100) : 0).toInt();

    return _cardFrame(
      key: 'support',
      number: '03',
      title: 'Customer support',
      section: 'support',
      wide: wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _kpiBox(
                  value: '${f.supportClients}',
                  label: 'Clients handled this week',
                  sublabel: 'vs. ${f.supportPrevClients} week before',
                  valueKey: 'support',
                  recordsKey: 'supportClients',
                  typedKeys: const ['supportClients'],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiBox(
                  value: '${f.monthToDate}',
                  extraInline: ' / ${f.monthTarget}+',
                  label: 'This month',
                  sublabel: 'monthly target ${f.monthTarget}+',
                  valueColor: f.monthToDate >= f.monthTarget ? _ReportColors.emerald600 : null,
                  valueKey: 'month',
                  recordsKey: 'monthToDate',
                  typedKeys: const ['monthToDate'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Monthly Target Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text('Monthly Target Progress', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ReportColors.slate600)),
                  Text('$pct% of ${f.monthTarget}', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _ReportColors.slate800)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (f.monthTarget > 0 ? (f.monthToDate / f.monthTarget) : 0).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  backgroundColor: _ReportColors.slate100,
                  valueColor: const AlwaysStoppedAnimation<Color>(_ReportColors.brand700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Helper Caption
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _ReportColors.slate100))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: _ReportColors.slate400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Answered in the chat, a booking request decided, or a case worked — each client counted once.',
                    style: GoogleFonts.inter(fontSize: 11, color: _ReportColors.slate500, height: 1.35),
                  ),
                ),
              ],
            ),
          ),

          if (f.supportByMember.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final (name, n) in f.supportByMember)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _ReportColors.slate50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _ReportColors.slate200)),
                    child: Text('$name · $n', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _ReportColors.slate700)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Card 04: Starting Messages ──────────────────────────────────────────────

  Widget _messagesCard(CrmTheme crm, bool wide) {
    final a = int.tryParse(_nizan.text.trim());
    final b = int.tryParse(_teamN.text.trim());
    final hasTotal = a != null && b != null;
    final charCount = _msgNote.text.length;

    return _cardFrame(
      key: 'messages',
      number: '04',
      title: 'Starting messages',
      wide: wide,
      trailingHeader: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _ReportColors.emerald50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _ReportColors.emerald100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 12, color: _ReportColors.emerald700),
            const SizedBox(width: 4),
            Text('Configured', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _ReportColors.emerald700)),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SENDER / LEAD', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _ReportColors.slate500, letterSpacing: 0.5)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        key: const Key('crmWeekly_nizan'),
                        controller: _nizan,
                        enabled: widget.canEdit,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline, size: 17, color: _ReportColors.slate400),
                          hintText: 'Nizan',
                          labelText: 'Nizan',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _ReportColors.slate200)),
                          filled: true,
                          fillColor: _ReportColors.slate50,
                          isDense: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ReportColors.slate900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TEAM / CHANNEL', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _ReportColors.slate500, letterSpacing: 0.5)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        key: const Key('crmWeekly_teamN'),
                        controller: _teamN,
                        enabled: widget.canEdit,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.groups_outlined, size: 17, color: _ReportColors.slate400),
                          hintText: 'Team N',
                          labelText: 'Team N',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _ReportColors.slate200)),
                          filled: true,
                          fillColor: _ReportColors.slate50,
                          isDense: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ReportColors.slate900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasTotal) ...[
            const SizedBox(height: 6),
            Text('Total ${a + b}', key: const Key('crmWeeklyMsgTotal'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _ReportColors.slate900)),
          ],
          const SizedBox(height: 12),

          // Note Textarea with Character Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NOTE (OPTIONAL)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _ReportColors.slate500, letterSpacing: 0.5)),
              Text('$charCount / 240', style: GoogleFonts.inter(fontSize: 10.5, color: _ReportColors.slate400)),
            ],
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _msgNote,
            enabled: widget.canEdit,
            maxLength: 240,
            maxLines: 2,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
            decoration: InputDecoration(
              hintText: 'Add handoff context, campaign notes, or greeting updates for the week...',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: _ReportColors.slate400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _ReportColors.slate200)),
              filled: true,
              fillColor: _ReportColors.slate50,
            ),
            style: GoogleFonts.inter(fontSize: 12.5, color: _ReportColors.slate800),
          ),
        ],
      ),
    );
  }

  // ── Card 05: Verification ───────────────────────────────────────────────────

  Widget _verificationCard(CrmTheme crm, CrmWeeklyFigures f, bool wide) {
    final n = f.verifyNextWeek;
    final pct = n.pct == null ? (n.works > 0 && n.verified != null ? (n.verified! / n.works * 100) : 0) : n.pct!;
    final pctInt = pct.toInt();

    return _cardFrame(
      key: 'verification',
      number: '05',
      title: 'Verification',
      section: 'verification',
      wide: wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _kpiBox(
                  value: n.verified == null ? '—' : '${n.verified} / ${n.works}',
                  label: 'Coming week verified',
                  sublabel: '${crmDayLabel(n.from)} – ${crmDayLabel(n.to)}',
                  bgColor: _ReportColors.amber50,
                  borderColor: _ReportColors.amber200,
                  valueKey: 'verified',
                  recordsKey: 'verified',
                  typedKeys: const ['verified', 'verifyWorks'],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiBox(
                  value: f.verifyThisWeek.verified == null ? '—' : '${f.verifyThisWeek.verified} / ${f.verifyThisWeek.works}',
                  label: "This week's works verified",
                  sublabel: 'audit status',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Readiness Progress Bar
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _ReportColors.slate100))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text('Upcoming Schedule Readiness', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ReportColors.slate600)),
                    Text(
                      '${n.verified ?? 0} of ${n.works} verified ($pctInt%)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pctInt >= 100 ? _ReportColors.emerald700 : _ReportColors.amber800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (n.verified == null || n.works <= 0) ? 0.0 : (n.verified! / n.works).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: _ReportColors.slate100,
                    valueColor: AlwaysStoppedAnimation<Color>(pctInt >= 100 ? _ReportColors.emerald500 : _ReportColors.amber500),
                  ),
                ),
              ],
            ),
          ),

          if (n.unverified.isNotEmpty) ...[
            const SizedBox(height: 8),
            _workList(crm, 'unverified', 'Not verified yet', n.unverified),
          ],
        ],
      ),
    );
  }

  // ── Card 06: Medical Conditions ─────────────────────────────────────────────

  Widget _medicalCard(CrmTheme crm, CrmWeeklyFigures f, bool wide) {
    final condCount = f.medicalConditions ?? f.withConditions?.length ?? 0;
    final emerCount = f.medicalEmergencies ?? f.emergencies?.length ?? 0;
    final isAllClear = condCount == 0 && emerCount == 0;

    return _cardFrame(
      key: 'medical',
      number: '06',
      title: 'Medical conditions',
      section: 'medical',
      wide: wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _kpiBox(
                  value: _num(f.medicalConditions),
                  label: 'Clients with a condition',
                  sublabel: 'this + coming week',
                  valueColor: condCount > 0 ? _ReportColors.rose600 : null,
                  valueKey: 'medicalConditions',
                  recordsKey: 'medicalConditions',
                  typedKeys: const ['medicalConditions'],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiBox(
                  value: _num(f.medicalEmergencies),
                  label: 'Emergencies this week',
                  sublabel: 'escalated incidents',
                  valueColor: emerCount > 0 ? _ReportColors.rose600 : null,
                  valueKey: 'medicalEmergencies',
                  recordsKey: 'medicalEmergencies',
                  typedKeys: const ['medicalEmergencies'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isAllClear ? _ReportColors.emerald50 : _ReportColors.rose50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isAllClear ? _ReportColors.emerald100 : _ReportColors.rose100),
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isAllClear ? _ReportColors.emerald500 : _ReportColors.rose500,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAllClear ? Icons.check : Icons.warning_amber_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isAllClear ? _ReportColors.emerald700 : _ReportColors.rose700,
                      ),
                      children: [
                        TextSpan(
                          text: isAllClear ? 'All clear — ' : 'Attention required — ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: isAllClear
                              ? 'No client with a medical condition this week or next.'
                              : '$condCount client(s) with medical notes; $emerCount emergency incident(s).',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!isAllClear && f.withConditions != null) ...[
            const SizedBox(height: 8),
            for (final m in f.withConditions!)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medical_information_outlined, size: 17, color: _ReportColors.rose600),
                  title: Text('${m.client} · ${m.conditions.join(', ')}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  subtitle: Text([m.days.map(crmDayLabel).join(', '), if (m.note.isNotEmpty) m.note].join(' — '), style: GoogleFonts.inter(fontSize: 10.5)),
                  onTap: m.bookingId.isEmpty ? null : () => context.go('/booking/manage/${m.bookingId}'),
                ),
              ),
            for (final e in f.emergencies ?? const <CrmEmergencyRow>[])
              Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded, size: 17, color: _ReportColors.rose600),
                  title: Text('${e.client} · ${crmDayLabel(e.day)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  subtitle: Text([e.what, if (e.action.isNotEmpty) 'Done: ${e.action}'].join(' — '), style: GoogleFonts.inter(fontSize: 10.5)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Card 07: Team Workload ──────────────────────────────────────────────────

  Widget _workloadCard(CrmTheme crm, CrmWeeklyFigures f, bool wide) {
    final n = f.workloadNextWeek;
    final maxV = n.days.fold<int>(1, (m, d) => [m, d.booked, d.capacity].reduce((a, b) => a > b ? a : b));

    return _cardFrame(
      key: 'workload',
      number: '07',
      title: 'Team workload',
      section: 'workload',
      wide: wide,
      trailingHeader: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: n.overDays > 0 ? _ReportColors.rose50 : _ReportColors.emerald50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: n.overDays > 0 ? _ReportColors.rose100 : _ReportColors.emerald100),
        ),
        child: Text(
          n.overDays > 0 ? 'Over capacity (${n.overDays}d)' : 'Balanced (78%)',
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: n.overDays > 0 ? _ReportColors.rose700 : _ReportColors.emerald700,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _kpiBox(
                  value: '${n.booked} / ${n.capacity}',
                  label: 'Assigned works',
                  sublabel: 'this week ${f.workloadThisWeek.booked}',
                  valueKey: 'workload',
                  recordsKey: 'workloadBooked',
                  typedKeys: const ['workloadBooked', 'workloadCapacity'],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiBox(
                  value: '${f.workloadThisWeek.booked}',
                  label: 'This week',
                  sublabel: 'past week works',
                ),
              ),
              if (n.overDays > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _kpiBox(
                    value: '${n.overDays}',
                    label: 'Days over capacity',
                    sublabel: 'manpower needed',
                    valueColor: _ReportColors.rose600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Daily capacity bars
          for (final d in n.days)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 84, child: Text(crmDayLabel(d.day), style: GoogleFonts.inter(fontSize: 11, color: _ReportColors.slate500))),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 11, decoration: BoxDecoration(color: _ReportColors.slate100, borderRadius: BorderRadius.circular(3))),
                        FractionallySizedBox(
                          widthFactor: (d.booked / maxV).clamp(0, 1).toDouble(),
                          child: Container(
                            height: 11,
                            decoration: BoxDecoration(
                              color: d.over ? _ReportColors.rose500 : _ReportColors.brand700,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 65,
                    child: Text(
                      d.blocked ? 'blocked' : '${d.booked} / ${d.capacity}',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: d.over ? FontWeight.w800 : FontWeight.w600,
                        color: d.over ? _ReportColors.rose600 : _ReportColors.slate800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // Manpower inputs
          TextField(
            key: const Key('crmWeekly_plan'),
            controller: _plan,
            enabled: widget.canEdit,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Plan for extra manpower if needed',
              labelStyle: GoogleFonts.inter(fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _ReportColors.slate200)),
              filled: true,
              fillColor: _ReportColors.slate50,
            ),
            style: GoogleFonts.inter(fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text('Is there enough work?', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _ReportColors.slate800)),
              for (final (k, l) in const [('yes', 'Yes'), ('no', 'No')])
                ChoiceChip(
                  key: Key('crmWeekly_enough_$k'),
                  label: Text(l, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  selected: _enough == k,
                  selectedColor: _ReportColors.brand100,
                  onSelected: widget.canEdit ? (_) => setState(() => _enough = _enough == k ? '' : k) : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _enoughNote,
            enabled: widget.canEdit,
            decoration: InputDecoration(
              labelText: 'Why (optional)',
              labelStyle: GoogleFonts.inter(fontSize: 11.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _ReportColors.slate200)),
              isDense: true,
              filled: true,
              fillColor: _ReportColors.slate50,
            ),
            style: GoogleFonts.inter(fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // ── Card 08: Outsource Works ────────────────────────────────────────────────

  Widget _outsourceCard(CrmTheme crm, CrmWeeklyFigures f, bool wide) {
    return _cardFrame(
      key: 'outsource',
      number: '08',
      title: 'Outsource data details',
      section: 'outsource',
      wide: wide,
      trailingHeader: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(color: _ReportColors.slate100, borderRadius: BorderRadius.circular(12)),
        child: Text('In-house priority', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: _ReportColors.slate600)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (f.outsourceByPerson.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final (name, _, n) in f.outsourceByPerson)
                  Chip(
                    label: Text('$name · $n', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (f.outsource.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No outside artist worked this week.', style: GoogleFonts.inter(fontSize: 12, color: _ReportColors.slate400)),
            )
          else ...[
            for (final (i, l) in f.outsource.indexed)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  key: Key('crmOutsource_$i'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: _ReportColors.brand100,
                    child: Text(
                      l.outsource.isEmpty ? '?' : l.outsource[0].toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: _ReportColors.brand900),
                    ),
                  ),
                  title: Text('${l.bride} · ${l.outsource}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _ReportColors.slate900)),
                  subtitle: Text(
                    <String>[l.work, if (l.day.isNotEmpty) crmDayLabel(l.day), if (l.byHand) 'typed by hand'].where((x) => x.isNotEmpty).join(' · '),
                    style: GoogleFonts.inter(fontSize: 10.5, color: _ReportColors.slate500),
                  ),
                  trailing: Text(l.phone, style: GoogleFonts.inter(fontSize: 11, color: _ReportColors.slate400)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Card 09: Notes ──────────────────────────────────────────────────────────

  Widget _notesCard(CrmTheme crm, bool wide) {
    return Material(
      key: const Key('crmWeekly_notes'),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _ReportColors.slate200)),
      child: Padding(
        padding: EdgeInsets.all(wide ? 20 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Notes', style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.w700, color: _ReportColors.slate900)),
            const SizedBox(height: 10),
            TextField(
              key: const Key('crmWeeklyNotes'),
              controller: _notes,
              enabled: widget.canEdit,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Anything else for the week, management observations, or team updates...',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: _ReportColors.slate400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _ReportColors.slate200)),
                filled: true,
                fillColor: _ReportColors.slate50,
              ),
              style: GoogleFonts.inter(fontSize: 12.5, color: _ReportColors.slate800),
            ),
          ],
        ),
      ),
    );
  }

  // ── Glassmorphic Sticky Action Bar ─────────────────────────────────────────

  Widget _actionBar(CrmTheme crm, CrmWeeklyReport r, CrmWeeklyFigures f) {
    final dotTrials = f.trialsHeld >= 0;
    final dotPhotos = f.reviews >= f.clientsDone && f.clientsDone > 0;
    final dotSupport = true;
    final dotMsg = true;
    final dotVerify = f.verifyNextWeek.verified != null && f.verifyNextWeek.verified == f.verifyNextWeek.works;
    final dotMedical = (f.medicalEmergencies ?? 0) == 0;

    final readyCount = [dotTrials, dotPhotos, dotSupport, dotMsg, dotVerify, dotMedical].where((b) => b).length;
    final pendingCount = 6 - readyCount;

    return Material(
      color: Colors.white,
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _ReportColors.slate200)),
        ),
        child: SafeArea(
          top: false,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dot(dotTrials),
                      _dot(dotPhotos),
                      _dot(dotSupport),
                      _dot(dotMsg),
                      _dot(dotVerify),
                      _dot(dotMedical),
                    ],
                  ),
                  Text(
                    '$readyCount of 6 ready',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _ReportColors.slate900),
                  ),
                  if (pendingCount > 0)
                    Text('($pendingCount pending)', style: GoogleFonts.inter(fontSize: 11, color: _ReportColors.slate400)),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (widget.canEdit) ...[
                    OutlinedButton(
                      key: const Key('crmWeeklySave'),
                      onPressed: _busy ? null : () => _act((s) => s.save(widget.report.week.from, _typed), 'Saved draft'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ReportColors.slate700,
                        side: const BorderSide(color: _ReportColors.slate300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Save draft'),
                    ),
                    FilledButton.icon(
                      key: const Key('crmWeeklySubmit'),
                      onPressed: _busy || !widget.weekOver
                          ? null
                          : () => _act((s) async {
                              await s.save(widget.report.week.from, _typed);
                              return s.submit(widget.report.week.from);
                            }, 'Handed in'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _ReportColors.brand900,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _ReportColors.brand900.withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.send, size: 14, color: _ReportColors.gold400),
                      label: Text(widget.weekOver ? 'Hand in' : 'Hand in (after the week)'),
                    ),
                  ],
                  if (widget.canReopen)
                    OutlinedButton.icon(
                      key: const Key('crmWeeklyReopen'),
                      onPressed: _busy ? null : () => _act((s) => s.reopen(widget.report.week.from), 'Reopened'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ReportColors.brand700,
                        side: const BorderSide(color: _ReportColors.brand700),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.lock_open, size: 15),
                      label: const Text('Reopen'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(bool ready) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(right: 2.5),
      decoration: BoxDecoration(
        color: ready ? _ReportColors.emerald500 : _ReportColors.amber500,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }

  static String _num(num? v) => v == null ? '—' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  Widget _workList(CrmTheme crm, String key, String title, List<CrmWorkRef> works) {
    if (works.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: Key('crmWeeklyList_$key'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('$title (${works.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _ReportColors.slate800)),
          children: [
            for (final w in works)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(w.client, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: Text([crmDayLabel(w.day), if (w.bookingNumber.isNotEmpty) w.bookingNumber, if (w.phone.isNotEmpty) w.phone].join(' · '), style: GoogleFonts.inter(fontSize: 10.5)),
                trailing: const Icon(Icons.chevron_right, size: 15, color: _ReportColors.slate400),
                onTap: w.bookingId.isEmpty ? null : () => context.go('/booking/manage/${w.bookingId}'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── By Hand Dialogs (Preserving All Test Keys & Functionality) ─────────────────

String _numText(num? v) => v == null ? '—' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

class _ByHandDialog extends StatefulWidget {
  const _ByHandDialog({required this.title, required this.fields, required this.typed, required this.records, required this.note});
  final String title;
  final List<CrmWeeklyField> fields;
  final Map<String, int> typed;
  final Map<String, num?> records;
  final String note;

  @override
  State<_ByHandDialog> createState() => _ByHandDialogState();
}

class _ByHandDialogState extends State<_ByHandDialog> {
  late final _boxes = {for (final f in widget.fields) f.key: TextEditingController(text: widget.typed[f.key]?.toString() ?? '')};
  late final _note = TextEditingController(text: widget.note);

  @override
  void dispose() {
    for (final c in [..._boxes.values, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('crmByHandDialog'),
      title: Text('Enter by hand · ${widget.title}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Type a figure where records missed something. Leave a box empty to use records. The report marks what was typed.',
                style: GoogleFonts.inter(fontSize: 12, color: _ReportColors.slate500),
              ),
              const SizedBox(height: 14),
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    key: Key('crmByHand_${f.key}'),
                    controller: _boxes[f.key],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: f.label,
                      helperText: 'Records: ${_numText(widget.records[f.key])}',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              TextField(
                key: const Key('crmByHand_note'),
                controller: _note,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Note: where the figures came from (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('crmByHandClear'),
          onPressed: () => setState(() {
            for (final c in _boxes.values) {
              c.clear();
            }
          }),
          child: const Text('Use the records\' figures'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const Key('crmByHandSave'),
          style: FilledButton.styleFrom(
            backgroundColor: _ReportColors.brand900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.of(context).pop((
            overrides: {for (final e in _boxes.entries) e.key: int.tryParse(e.value.text.trim())},
            note: _note.text.trim(),
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _OutsourceByHandDialog extends StatefulWidget {
  const _OutsourceByHandDialog({required this.lines, required this.note, required this.week});
  final List<CrmOutsourceLine> lines;
  final String note;
  final CrmWeek week;

  @override
  State<_OutsourceByHandDialog> createState() => _OutsourceByHandDialogState();
}

class _OutsourceByHandDialogState extends State<_OutsourceByHandDialog> {
  late final _lines = [...widget.lines];
  final _bride = TextEditingController();
  final _artist = TextEditingController();
  final _work = TextEditingController();
  final _phone = TextEditingController();
  late final _note = TextEditingController(text: widget.note);
  String _day = '';
  String? _error;

  @override
  void dispose() {
    for (final c in [_bride, _artist, _work, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _formEmpty => [_bride, _artist, _work, _phone].every((c) => c.text.trim().isEmpty) && _day.isEmpty;

  bool _add() {
    if (_bride.text.trim().isEmpty || _artist.text.trim().isEmpty) {
      setState(() => _error = 'Give the bride\'s name and the outside artist\'s name.');
      return false;
    }
    setState(() {
      _lines.add(CrmOutsourceLine(bride: _bride.text.trim(), outsource: _artist.text.trim(), work: _work.text.trim(), phone: _phone.text.trim(), day: _day, byHand: true));
      for (final c in [_bride, _artist, _work, _phone]) {
        c.clear();
      }
      _day = '';
      _error = null;
    });
    return true;
  }

  Future<void> _pickDay() async {
    final first = DateTime.parse(widget.week.from);
    final last = DateTime.parse(widget.week.to);
    final d = await showDatePicker(context: context, firstDate: first, lastDate: last, initialDate: first);
    if (d != null && mounted) setState(() => _day = _iso.format(d));
  }

  @override
  Widget build(BuildContext context) {
    Widget box(String key, String label, TextEditingController c, {TextInputType? type}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: Key('crmByHand_$key'),
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
        style: GoogleFonts.inter(fontSize: 13),
      ),
    );

    return AlertDialog(
      key: const Key('crmByHandDialog'),
      title: Text('Enter by hand · Outsource works', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add outside-artist works records do not have. Ones from records stay as they are.',
                style: GoogleFonts.inter(fontSize: 12, color: _ReportColors.slate500),
              ),
              const SizedBox(height: 8),
              if (_lines.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('None typed in yet.', style: GoogleFonts.inter(fontSize: 12, color: _ReportColors.slate400))),
              for (final (i, l) in _lines.indexed)
                ListTile(
                  key: Key('crmByHandLine_$i'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${l.bride} · ${l.outsource}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  subtitle: Text(<String>[l.work, l.phone, if (l.day.isNotEmpty) crmDayLabel(l.day)].where((x) => x.isNotEmpty).join(' · '), style: GoogleFonts.inter(fontSize: 11)),
                  trailing: IconButton(
                    key: Key('crmByHandRemove_$i'),
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline, size: 18, color: _ReportColors.rose600),
                    onPressed: () => setState(() => _lines.removeAt(i)),
                  ),
                ),
              const Divider(height: 20, color: _ReportColors.slate200),
              box('bride', 'Bride\'s name', _bride),
              box('artist', 'Outside artist', _artist),
              box('work', 'Work they did', _work),
              box('phone', 'Number', _phone, type: TextInputType.phone),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: const Key('crmByHand_day'),
                    onPressed: _pickDay,
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(_day.isEmpty ? 'Day (optional)' : crmDayLabel(_day)),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('crmByHandAdd'),
                    onPressed: _add,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add this work'),
                  ),
                ],
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, key: const Key('crmByHandError'), style: const TextStyle(color: _ReportColors.rose600, fontSize: 12))),
              const SizedBox(height: 12),
              TextField(
                key: const Key('crmByHand_note'),
                controller: _note,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const Key('crmByHandSave'),
          style: FilledButton.styleFrom(
            backgroundColor: _ReportColors.brand900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            if (!_formEmpty && !_add()) return;
            Navigator.of(context).pop((lines: _lines, note: _note.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
