import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

import '../../controllers/consultation_provider.dart';
import '../../data/consultation.dart';
import '../../data/stylist_client.dart' show dayKey, kClientCompanies;
import '../../services/consultation_service.dart';
import '../widgets/consultation_ui.dart';
import '../widgets/stylist_client_ui.dart';

enum _CalendarView { month, week, list }

/// The Calendar page (FR-06, FR-12): one screen with Month, Week and List
/// views sharing one header and one set of filters.
/// - Month: a grid with each day's calls (names on wide screens, dots on
///   phones) beside the chosen day's agenda.
/// - Week: seven columns on wide screens, a day-by-day list on phones.
/// - List: the month's calls grouped by day, with search and a status filter.
/// Calls are coloured by company (Team N / Nizan) and show their number in the
/// client's series. A stylist sees their own calls; a stylist lead sees
/// everyone's and can filter by stylist. On a phone the filters sit behind one
/// Filters button.
class ConsultationsCalendarScreen extends ConsumerStatefulWidget {
  const ConsultationsCalendarScreen({super.key, this.initialView = 'month'});

  /// 'month', 'week' or 'list' (from `?view=` or the `/consultations/list` route).
  final String initialView;

  @override
  ConsumerState<ConsultationsCalendarScreen> createState() => _ConsultationsCalendarScreenState();
}

class _ConsultationsCalendarScreenState extends ConsumerState<ConsultationsCalendarScreen> {
  late _CalendarView _view = switch (widget.initialView) {
    'week' => _CalendarView.week,
    'list' => _CalendarView.list,
    _ => _CalendarView.month,
  };
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  String? _stylistId;
  String _company = ''; // '' = both
  bool _showCancelled = false;
  String? _status; // List view only; null = any
  String _search = '';

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _wide = 900.0;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _weekStart(DateTime d) => _dateOnly(d).subtract(Duration(days: d.weekday - 1));

  bool get _isWeek => _view == _CalendarView.week;
  bool get _isList => _view == _CalendarView.list;

  /// First and last day fetched for the current view. The month grid pads to
  /// whole weeks; the list keeps to the month itself.
  (DateTime, DateTime) get _range {
    if (_isWeek) {
      final start = _weekStart(_focused);
      return (start, start.add(const Duration(days: 6)));
    }
    final first = DateTime(_focused.year, _focused.month, 1);
    final last = DateTime(_focused.year, _focused.month + 1, 0);
    if (_isList) return (first, last);
    return (_weekStart(first), _weekStart(last).add(const Duration(days: 6)));
  }

  void _shift(int direction) {
    setState(() {
      if (_isWeek) {
        _focused = _focused.add(Duration(days: 7 * direction));
      } else {
        _focused = DateTime(_focused.year, _focused.month + direction, 1);
      }
      _selected = _focused;
    });
  }

  void _today() => setState(() {
        _focused = DateTime.now();
        _selected = DateTime.now();
      });

  void _schedule(DateTime? day) {
    final today = _dateOnly(DateTime.now());
    final d = day == null || _dateOnly(day).isBefore(today) ? null : _dateOnly(day);
    context.push(d == null ? '/consultations/new' : '/consultations/new?date=${dayKey(d)}');
  }

  /// How many filters differ from the defaults (for the phone's Filters badge).
  int get _activeFilters =>
      (_company.isNotEmpty ? 1 : 0) + (_stylistId != null ? 1 : 0) + (_showCancelled ? 1 : 0) + (_isList && _status != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isLead = ref.watch(effectiveAccessProvider).canSeeConsultationReports;
    final (from, to) = _range;
    final query = (
      from: ConsultationService.day(from),
      to: ConsultationService.day(to),
      status: _isList ? _status : null,
      stylistId: isLead ? _stylistId : null,
    );
    final async = ref.watch(consultationsProvider(query));
    final stylists = isLead ? ref.watch(consultationStylistsProvider).value : null;

    return Scaffold(
      backgroundColor: crm.background,
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= _wide;
          final visible = (async.value ?? const <Consultation>[]).where((c) {
            // Asking for cancelled calls in the list shows them without the toggle.
            if (!_showCancelled && c.status == 'Cancelled' && _status != 'Cancelled') return false;
            if (_company.isNotEmpty && c.client.company != _company) return false;
            if (_isList && _search.isNotEmpty) {
              final q = _search.toLowerCase();
              final phone = q.replaceAll(' ', '');
              if (!c.clientName.toLowerCase().contains(q) &&
                  !(phone.isNotEmpty && c.clientPhone.replaceAll(' ', '').contains(phone))) {
                return false;
              }
            }
            return true;
          }).toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          return Column(
            children: [
              _header(crm, isLead, stylists, wide, async.hasValue ? visible.length : null),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      AppErrorView(error: e, onRetry: () => ref.invalidate(consultationsProvider(query))),
                  data: (_) => RefreshIndicator(
                    onRefresh: () async => ref.invalidate(consultationsProvider(query)),
                    child: switch (_view) {
                      _CalendarView.month => _monthBody(crm, visible, wide, isLead),
                      _CalendarView.week => _weekBody(crm, visible, wide, isLead),
                      _CalendarView.list => _listBody(crm, visible, wide, isLead),
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  String get _periodTitle {
    if (!_isWeek) return DateFormat('MMMM yyyy').format(_focused);
    final s = _weekStart(_focused);
    final e = s.add(const Duration(days: 6));
    return '${fmtShortDay(s)} – ${fmtShortDay(e)} ${e.year}';
  }

  Widget _header(CrmTheme crm, bool isLead, List<ConsultationStylist>? stylists, bool wide, int? count) {
    final showStylists = isLead && stylists != null && stylists.length > 1;
    final unit = _isWeek ? 'week' : 'month';

    final viewSwitch = CallsViewSwitch(
      selected: _view.name,
      onChanged: (v) => setState(() {
        _view = _CalendarView.values.byName(v);
        _selected = _focused;
      }),
    );
    Widget arrow(int dir) => IconButton(
          tooltip: dir < 0 ? 'Previous $unit' : 'Next $unit',
          visualDensity: VisualDensity.compact,
          onPressed: () => _shift(dir),
          icon: Icon(dir < 0 ? Icons.chevron_left : Icons.chevron_right),
        );
    final period = Text(_periodTitle,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: crm.textPrimary));
    final todayButton = OutlinedButton(
      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
      onPressed: _today,
      child: const Text('Today'),
    );
    final searchField = TextField(
      onChanged: (v) => setState(() => _search = v.trim()),
      decoration: InputDecoration(
        hintText: 'Client name or phone',
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        filled: true,
        fillColor: crm.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    final scheduleButton = FilledButton.icon(
      onPressed: () => _schedule(null),
      icon: const Icon(Icons.add, size: 18),
      label: Text(wide ? 'Schedule call' : 'Schedule'),
    );
    final countText = count == null
        ? null
        : Text('$count ${count == 1 ? 'call' : 'calls'} this $unit',
            style: TextStyle(fontSize: 12, color: crm.textSecondary));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
      child: wide
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: crm.textPrimary)),
                    const SizedBox(width: 16),
                    viewSwitch,
                    const SizedBox(width: 12),
                    arrow(-1),
                    ConstrainedBox(constraints: const BoxConstraints(minWidth: 140), child: period),
                    arrow(1),
                    const SizedBox(width: 4),
                    todayButton,
                    const Spacer(),
                    scheduleButton,
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_isList) ...[
                      SizedBox(width: 240, child: searchField),
                      _statusMenu(crm),
                    ],
                    _companySwitch(),
                    if (showStylists) _stylistMenu(crm, stylists),
                    FilterChip(
                      label: const Text('Show cancelled'),
                      selected: _showCancelled,
                      onSelected: (v) => setState(() => _showCancelled = v),
                    ),
                    ?countText,
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Calendar',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: crm.textPrimary)),
                    ),
                    scheduleButton,
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: viewSwitch),
                const SizedBox(height: 6),
                Row(
                  children: [
                    arrow(-1),
                    Expanded(child: period),
                    arrow(1),
                    todayButton,
                    const SizedBox(width: 6),
                    Badge(
                      isLabelVisible: _activeFilters > 0,
                      label: Text('$_activeFilters'),
                      child: IconButton.outlined(
                        tooltip: 'Filters',
                        style: IconButton.styleFrom(side: BorderSide(color: crm.border)),
                        onPressed: () => _openFilters(crm, showStylists ? stylists : null),
                        icon: const Icon(Icons.tune, size: 20),
                      ),
                    ),
                  ],
                ),
                if (_isList) ...[const SizedBox(height: 8), searchField],
              ],
            ),
    );
  }

  Widget _companySwitch() => SegmentedButton<String>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          const ButtonSegment(value: '', label: Text('Both')),
          for (final c in kClientCompanies) ButtonSegment(value: c, label: Text(c)),
        ],
        selected: {_company},
        onSelectionChanged: (s) => setState(() => _company = s.first),
      );

  Widget _pillMenu<T>(CrmTheme crm,
      {required String tooltip, required String label, required T? value, required Map<T?, String> items,
      required ValueChanged<T?> onSelected}) {
    return PopupMenuButton<T?>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final e in items.entries) CheckedPopupMenuItem<T?>(value: e.key, checked: e.key == value, child: Text(e.value)),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: crm.border), borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: crm.textPrimary, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _statusMenu(CrmTheme crm) => _pillMenu<String>(
        crm,
        tooltip: 'Status',
        label: 'Status: ${_status ?? 'Any'}',
        value: _status,
        items: {null: 'Any status', for (final s in kConsultationStatuses) s: s},
        onSelected: (v) => setState(() => _status = v),
      );

  Widget _stylistMenu(CrmTheme crm, List<ConsultationStylist> stylists) => _pillMenu<String>(
        crm,
        tooltip: 'Stylist',
        label: 'Stylist: ${stylists.where((s) => s.id == _stylistId).firstOrNull?.name ?? 'All'}',
        value: _stylistId,
        items: {null: 'All stylists', for (final s in stylists) s.id: s.name},
        onSelected: (v) => setState(() => _stylistId = v),
      );

  /// Phone: company, stylist, cancelled and (in List) status in a bottom sheet.
  Future<void> _openFilters(CrmTheme crm, List<ConsultationStylist>? stylists) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) {
            void update(VoidCallback f) {
              setState(f);
              setSheet(() {});
            }

            Widget heading(String t) => Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: crm.textPrimary)),
                );
            Widget chips<T>(Map<T, String> items, T selected, ValueChanged<T> onPick) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in items.entries)
                      ChoiceChip(label: Text(e.value), selected: selected == e.key, onSelected: (_) => update(() => onPick(e.key))),
                  ],
                );

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading('Company'),
                    chips<String>({'': 'Both', for (final c in kClientCompanies) c: c}, _company, (v) => _company = v),
                    if (stylists != null) ...[
                      heading('Stylist'),
                      chips<String?>({null: 'All', for (final s in stylists) s.id: s.name}, _stylistId,
                          (v) => _stylistId = v),
                    ],
                    if (_isList) ...[
                      heading('Status'),
                      chips<String?>({null: 'Any', for (final s in kConsultationStatuses) s: s}, _status, (v) => _status = v),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show cancelled'),
                      value: _showCancelled,
                      onChanged: (v) => update(() => _showCancelled = v),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  // ── List ─────────────────────────────────────────────────────────────────
  Widget _listBody(CrmTheme crm, List<Consultation> items, bool wide, bool isLead) {
    if (items.isEmpty) {
      final filtered = _search.isNotEmpty || _status != null || _company.isNotEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.event_busy_outlined, size: 44, color: crm.textSecondary),
          const SizedBox(height: 10),
          Center(
            child: Text(
              filtered ? 'No calls match these filters.' : 'No calls in ${DateFormat('MMMM').format(_focused)}.',
              style: TextStyle(color: crm.textSecondary),
            ),
          ),
        ],
      );
    }
    final byDay = <DateTime, List<Consultation>>{};
    for (final c in items) {
      byDay.putIfAbsent(_dateOnly(c.scheduledAt), () => []).add(c);
    }
    final today = _dateOnly(DateTime.now());
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final e in byDay.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Text(
                  [
                    DateFormat('EEE d MMM').format(e.key),
                    if (e.key == today) 'Today',
                  ].join('  ·  '),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: e.key == today ? crm.primary : crm.textPrimary,
                  ),
                ),
              ),
              for (final c in e.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CallCard(call: c, showStylist: isLead),
                ),
            ],
          ],
        ),
      ),
    );
  }


  Map<String, List<Consultation>> _byDay(List<Consultation> items) {
    final map = <String, List<Consultation>>{};
    for (final c in items) {
      map.putIfAbsent(ConsultationService.day(c.scheduledAt), () => []).add(c);
    }
    return map;
  }

  // ── Month ────────────────────────────────────────────────────────────────
  Widget _monthBody(CrmTheme crm, List<Consultation> items, bool wide, bool isLead) {
    final (start, end) = _range;
    final byDay = _byDay(items);
    final weeks = end.difference(start).inDays ~/ 7 + 1;
    final today = DateTime.now();
    final dayItems = byDay[ConsultationService.day(_selected)] ?? const <Consultation>[];

    final grid = Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(d, style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                    ),
                  ),
                ),
            ],
          ),
          for (var w = 0; w < weeks; w++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _dayCell(crm, start.add(Duration(days: w * 7 + d)), byDay, today, detailed: wide),
                  ),
              ],
            ),
        ],
      ),
    );

    final agenda = _DayAgenda(
      day: _selected,
      calls: dayItems,
      showStylist: isLead,
      onSchedule: () => _schedule(_selected),
    );

    if (wide) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: grid)),
            const SizedBox(width: 16),
            SizedBox(width: 340, child: SingleChildScrollView(child: agenda)),
          ],
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [grid, const SizedBox(height: 16), agenda],
    );
  }

  Widget _dayCell(
    CrmTheme crm,
    DateTime day,
    Map<String, List<Consultation>> byDay,
    DateTime today, {
    required bool detailed,
  }) {
    final inMonth = day.month == _focused.month;
    final selected = sameDay(day, _selected);
    final isToday = sameDay(day, today);
    final list = byDay[ConsultationService.day(day)] ?? const <Consultation>[];
    final shown = detailed ? 3 : 4;

    return InkWell(
      onTap: () => setState(() => _selected = day),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: detailed ? 104 : 58,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? crm.primary.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isToday ? crm.primary : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: detailed ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: isToday
                  ? BoxDecoration(color: crm.primary, borderRadius: BorderRadius.circular(999))
                  : null,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected || isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday
                      ? Colors.white
                      : inMonth
                          ? crm.textPrimary
                          : crm.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 3),
            if (list.isNotEmpty && detailed)
              for (final c in list.take(shown))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _MiniCall(call: c),
                ),
            if (list.isNotEmpty && !detailed)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final c in list.take(shown))
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: c.status == 'Cancelled' ? crm.textSecondary : companyColor(c.client.company),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            if (list.length > shown)
              Text('+${list.length - shown} more', style: TextStyle(fontSize: 10, color: crm.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Week ─────────────────────────────────────────────────────────────────
  Widget _weekBody(CrmTheme crm, List<Consultation> items, bool wide, bool isLead) {
    final start = _weekStart(_focused);
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    final byDay = _byDay(items);
    final now = DateTime.now();

    Widget dayHeader(DateTime day, int count) {
      final isToday = sameDay(day, now);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Narrow week columns put the Today tag under the date.
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(DateFormat('EEE d').format(day),
                    style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? crm.primary : crm.textPrimary)),
                if (isToday) ConsultationStatusChip('Today', color: crm.primary),
              ],
            ),
          ),
          if (count > 0) Text('$count', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ],
      );
    }

    if (wide) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final day in days)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minHeight: 260),
                  decoration: BoxDecoration(
                    color: sameDay(day, now) ? crm.primary.withValues(alpha: 0.05) : crm.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: crm.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      dayHeader(day, (byDay[ConsultationService.day(day)] ?? const []).length),
                      const SizedBox(height: 8),
                      if ((byDay[ConsultationService.day(day)] ?? const []).isEmpty)
                        Text('Free', style: TextStyle(color: crm.textSecondary, fontSize: 12))
                      else
                        for (final c in byDay[ConsultationService.day(day)]!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _CallCard(call: c, showStylist: isLead, compact: true),
                          ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: dayHeader(day, (byDay[ConsultationService.day(day)] ?? const []).length),
          ),
          if ((byDay[ConsultationService.day(day)] ?? const []).isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Free', style: TextStyle(color: crm.textSecondary, fontSize: 12)),
            )
          else
            for (final c in byDay[ConsultationService.day(day)]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CallCard(call: c, showStylist: isLead),
              ),
        ],
      ],
    );
  }
}

/// One call inside a month cell: time and first name on a company-coloured strip.
class _MiniCall extends StatelessWidget {
  const _MiniCall({required this.call});

  final Consultation call;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = call;
    final cancelled = c.status == 'Cancelled';
    final color = cancelled ? crm.textSecondary : companyColor(c.client.company);
    final first = c.clientName.trim().split(RegExp(r'\s+')).first;
    return Tooltip(
      message: '${fmtTime(c.scheduledAt)} · ${c.clientName}${c.callLabel.isEmpty ? '' : ' · ${c.callLabel}'}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${DateFormat('h:mm').format(c.scheduledAt)} ${first.isEmpty ? 'Client' : first}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            color: color,
            fontWeight: FontWeight.w600,
            decoration: cancelled ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

/// A call as a card: time, client, company, call number, mode and status.
class _CallCard extends StatelessWidget {
  const _CallCard({required this.call, this.showStylist = false, this.compact = false});

  final Consultation call;
  final bool showStylist;

  /// Narrow week columns: stacked, no status chip.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = call;
    final cancelled = c.status == 'Cancelled';
    final color = cancelled ? crm.textSecondary : companyColor(c.client.company);
    final sub = [
      if (c.callLabel.isNotEmpty) c.callLabel,
      c.isVideo ? 'Video' : 'In-person',
      if (showStylist && c.stylistName.isNotEmpty) c.stylistName,
    ].join('  ·  ');

    final name = Text(
      c.clientName.isEmpty ? 'Client' : c.clientName,
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: cancelled ? crm.textSecondary : crm.textPrimary,
        decoration: cancelled ? TextDecoration.lineThrough : null,
        fontSize: compact ? 12.5 : 14,
      ),
    );

    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/consultations/${c.id}'),
        child: Container(
          padding: EdgeInsets.all(compact ? 8 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: crm.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
                SizedBox(width: compact ? 8 : 12),
                Expanded(
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fmtTime(c.scheduledAt),
                                style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                            name,
                            if (c.callLabel.isNotEmpty)
                              Text(c.callLabel, style: TextStyle(fontSize: 11, color: color)),
                            if (c.status != 'Scheduled')
                              Text(c.status, style: TextStyle(fontSize: 11, color: consultationStatusColor(c.status))),
                          ],
                        )
                      : Row(
                          children: [
                            SizedBox(
                              width: 68,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(fmtTime(c.scheduledAt),
                                      style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary, fontSize: 13)),
                                  Text('${c.durationMins} min',
                                      style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // The tag drops under the name when the card is narrow.
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 2,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [name, CompanyTag(c.client.company)],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            ConsultationStatusChip(c.status),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The chosen day's calls, with a button to book on that day.
class _DayAgenda extends StatelessWidget {
  const _DayAgenda({required this.day, required this.calls, required this.showStylist, required this.onSchedule});

  final DateTime day;
  final List<Consultation> calls;
  final bool showStylist;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final now = DateTime.now();
    final past = DateTime(day.year, day.month, day.day).isBefore(DateTime(now.year, now.month, now.day));
    final booked = calls.where((c) => c.status != 'Cancelled').length;

    return Container(
      padding: const EdgeInsets.all(14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, d MMMM').format(day),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary)),
                    Text(booked == 0 ? 'No calls' : '$booked ${booked == 1 ? 'call' : 'calls'}',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ],
                ),
              ),
              if (!past)
                IconButton.filledTonal(
                  tooltip: 'Schedule on this day',
                  onPressed: onSchedule,
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (calls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(past ? 'No calls this day.' : 'Free — nothing booked yet.',
                  style: TextStyle(color: crm.textSecondary)),
            )
          else
            for (final c in calls)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CallCard(call: c, showStylist: showStylist),
              ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              for (final c in kClientCompanies)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: companyColor(c)),
                    const SizedBox(width: 4),
                    Text(c, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

