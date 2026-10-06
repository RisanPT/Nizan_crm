import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/marketing/presentation/widgets/kerala_bookings_map.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';

/// Every lead the signed-in user can see (salespeople are scoped to their own
/// server-side). The calendar buckets them client-side by the chosen date.
final calendarLeadsProvider = FutureProvider.autoDispose<List<Lead>>((ref) async {
  final res = await ref.watch(leadServiceProvider).getLeads(LeadFilter(limit: 10000));
  return res.items;
});

/// Which date a lead is placed on in the calendar.
enum _Basis {
  event('Event date'),
  received('Received'),
  followUp('Follow-up');

  final String label;
  const _Basis(this.label);

  DateTime? dateOf(Lead l) => switch (this) {
    // Unconverted leads keep the requested event date in enquiryDate.
    _Basis.event => l.eventDate ?? l.enquiryDate,
    _Basis.received => l.leadDate,
    _Basis.followUp => l.followUpDate,
  };
}

/// Extra spellings seen in lead locations, on top of the district table.
const Map<String, LatLng> _extraPlaces = {
  'thiruvananthapuram': LatLng(8.5241, 76.9366),
  'trivandrum': LatLng(8.5241, 76.9366),
  'alleppey': LatLng(9.4981, 76.3388),
  'palghat': LatLng(10.7867, 76.6548),
  'trichur': LatLng(10.5276, 76.2144),
  'quilon': LatLng(8.8932, 76.6141),
  'cochin': LatLng(9.9816, 76.2999),
  'kakkanad': LatLng(10.0159, 76.3419),
  'aluva': LatLng(10.1076, 76.3516),
  'angamaly': LatLng(10.1960, 76.3860),
  'perumbavoor': LatLng(10.1155, 76.4730),
  'muvattupuzha': LatLng(9.9894, 76.5790),
  'kasargod': LatLng(12.5102, 74.9852),
  'thalassery': LatLng(11.7491, 75.4890),
  'tirur': LatLng(10.9147, 75.9220),
  'manjeri': LatLng(11.1203, 76.1200),
  'thodupuzha': LatLng(9.8959, 76.7184),
  'changanassery': LatLng(9.4440, 76.5410),
  'thiruvalla': LatLng(9.3835, 76.5741),
  'kayamkulam': LatLng(9.1748, 76.5013),
  'attingal': LatLng(8.6964, 76.8156),
  'neyyattinkara': LatLng(8.4004, 77.0858),
  'guruvayur': LatLng(10.5946, 76.0410),
  'kodungallur': LatLng(10.2250, 76.1960),
  'chalakudy': LatLng(10.3070, 76.3330),
  'ottapalam': LatLng(10.7700, 76.3770),
  'mananthavady': LatLng(11.8014, 76.0044),
  'kalpetta': LatLng(11.6085, 76.0834),
};

/// One display name per point, so spellings of the same place (Kochi /
/// Ernakulam, Calicut / Kozhikode) share a single pin. The district table's
/// first spelling wins.
final Map<LatLng, String> _canonicalNames = () {
  final out = <LatLng, String>{};
  for (final table in [kBookingDistrictCoordinates, _extraPlaces]) {
    for (final e in table.entries) {
      out.putIfAbsent(e.value, () => e.key[0].toUpperCase() + e.key.substring(1));
    }
  }
  return out;
}();

/// Resolves a lead to a map point: district first, then free-text location,
/// then region. Returns the place's display name with it.
(String, LatLng)? _placeOf(Lead l) {
  for (final raw in [l.district, l.location, l.region]) {
    final text = raw.toLowerCase().trim();
    if (text.isEmpty) continue;
    for (final table in [_extraPlaces, kBookingDistrictCoordinates]) {
      for (final e in table.entries) {
        if (text.contains(e.key)) return (_canonicalNames[e.value]!, e.value);
      }
    }
  }
  return null;
}

const _statusColors = {
  'new': Color(0xFF6366F1),
  'contacted': Color(0xFF3B82F6),
  'follow-up': Color(0xFFF97316),
  'qualified': Color(0xFF14B8A6),
  'converted': Color(0xFF22C55E),
  'pending lost approval': Color(0xFFB45309),
  'lost': Color(0xFFEF4444),
};
Color _statusColor(String s) => _statusColors[s.toLowerCase()] ?? const Color(0xFF94A3B8);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

Map<String, int> _statusCounts(Iterable<Lead> leads) {
  final out = <String, int>{};
  for (final l in leads) {
    out[l.status] = (out[l.status] ?? 0) + 1;
  }
  return out;
}

/// Responsive size class shared by every block on this tab.
enum _Size {
  compact, // phones
  medium, // tablets / narrow windows
  wide; // desktops

  static _Size of(double width) =>
      width >= 960 ? _Size.wide : width >= 620 ? _Size.medium : _Size.compact;
}

// ─────────────────────────────────────────────────────────────────────────
//  Tab
// ─────────────────────────────────────────────────────────────────────────
class LeadCalendarTab extends ConsumerStatefulWidget {
  const LeadCalendarTab({super.key});

  @override
  ConsumerState<LeadCalendarTab> createState() => _LeadCalendarTabState();
}

class _LeadCalendarTabState extends ConsumerState<LeadCalendarTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _Basis _basis = _Basis.event;
  String _status = 'All';
  DateTime? _selectedDay;
  String? _selectedPlace;

  /// Custom From–To filter (whole days, inclusive). Null = the visible month.
  DateTimeRange? _range;

  void _shiftMonth(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        _selectedDay = null;
        _selectedPlace = null;
      });

  void _setRange(DateTimeRange? r) => setState(() {
        _range = r == null ? null : DateTimeRange(start: _day(r.start), end: _day(r.end));
        if (r != null) _month = DateTime(r.start.year, r.start.month);
        _selectedDay = null;
        _selectedPlace = null;
      });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: _range ??
          DateTimeRange(start: _month, end: DateTime(_month.year, _month.month + 1, 0)),
      helpText: 'Show leads from – to',
      saveText: 'Apply',
    );
    if (picked != null) _setRange(picked);
  }

  /// Quick ranges offered next to "Custom range…".
  List<(String, DateTimeRange)> get _presets {
    final t = _day(DateTime.now());
    final weekStart = t.subtract(Duration(days: t.weekday % 7)); // Sunday
    return [
      ('This week', DateTimeRange(start: weekStart, end: weekStart.add(const Duration(days: 6)))),
      ('Next 7 days', DateTimeRange(start: t, end: t.add(const Duration(days: 6)))),
      ('Next 30 days', DateTimeRange(start: t, end: t.add(const Duration(days: 29)))),
      ('Last 30 days', DateTimeRange(start: t.subtract(const Duration(days: 29)), end: t)),
      ('Next 3 months', DateTimeRange(start: t, end: DateTime(t.year, t.month + 3, t.day))),
    ];
  }

  String _rangeLabel(DateTimeRange r) {
    final sameYear = r.start.year == r.end.year;
    final a = DateFormat(sameYear ? 'd MMM' : 'd MMM yyyy').format(r.start);
    final b = DateFormat('d MMM yyyy').format(r.end);
    return r.start == r.end ? b : '$a – $b';
  }

  void _goToday() => setState(() {
        final now = DateTime.now();
        _month = DateTime(now.year, now.month);
        _selectedDay = _day(now);
        _selectedPlace = null;
      });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(calendarLeadsProvider);

    return ColoredBox(
      color: crm.background,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(calendarLeadsProvider)),
        data: (all) {
          // Leads in scope — the custom From–To range, else the visible
          // month — on the chosen date basis + status.
          final range = _range;
          final monthLeads = <Lead>[];
          for (final l in all) {
            final raw = _basis.dateOf(l);
            if (raw == null) continue;
            final d = _day(raw.toLocal());
            final inScope = range != null
                ? !d.isBefore(range.start) && !d.isAfter(range.end)
                : d.year == _month.year && d.month == _month.month;
            if (!inScope) continue;
            if (_status != 'All' && l.status.toLowerCase() != _status.toLowerCase()) continue;
            monthLeads.add(l);
          }
          final byDay = <DateTime, List<Lead>>{};
          for (final l in monthLeads) {
            byDay.putIfAbsent(_day(_basis.dateOf(l)!.toLocal()), () => []).add(l);
          }
          for (final list in byDay.values) {
            list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          }
          // Day → place narrowing for the map and the list.
          final dayLeads = _selectedDay == null ? monthLeads : (byDay[_selectedDay] ?? const <Lead>[]);
          final listed = _selectedPlace == null
              ? [...dayLeads]
              : dayLeads.where((l) => _placeOf(l)?.$1 == _selectedPlace).toList();
          listed.sort((a, b) => _basis.dateOf(a)!.compareTo(_basis.dateOf(b)!));

          final statuses = {for (final l in all) l.status}.where((s) => s.isNotEmpty).toList()..sort();
          final scope = _selectedDay != null
              ? DateFormat('EEE, d MMM yyyy').format(_selectedDay!)
              : range != null
                  ? _rangeLabel(range)
                  : DateFormat('MMMM yyyy').format(_month);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(calendarLeadsProvider),
            child: LayoutBuilder(builder: (context, c) {
              final size = _Size.of(c.maxWidth);
              final pad = size == _Size.compact ? 12.0 : 24.0;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(pad, 16, pad, 40),
                    children: [
                      _toolbar(crm, statuses, size),
                      const SizedBox(height: 14),
                      _SummaryStrip(leads: monthLeads),
                      const SizedBox(height: 16),
                      _CalendarBlock(
                        size: size,
                        month: _month,
                        basis: _basis,
                        byDay: byDay,
                        range: range,
                        selected: _selectedDay,
                        onSelect: (d) => setState(() {
                          _selectedDay = _selectedDay == d ? null : d;
                          _selectedPlace = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      _MapBlock(
                        size: size,
                        leads: dayLeads,
                        scope: scope,
                        selectedPlace: _selectedPlace,
                        onPlace: (p) => setState(() => _selectedPlace = _selectedPlace == p ? null : p),
                      ),
                      const SizedBox(height: 16),
                      _DetailsBlock(
                        leads: listed,
                        basis: _basis,
                        title: [
                          _selectedDay != null
                              ? DateFormat('EEEE, d MMMM').format(_selectedDay!)
                              : range != null
                                  ? 'All leads ${_rangeLabel(range)}'
                                  : 'All leads in ${DateFormat('MMMM').format(_month)}',
                          ?_selectedPlace,
                        ].join(' · '),
                        clearLabel: range != null ? 'Show whole range' : 'Show whole month',
                        onClear: _selectedDay == null && _selectedPlace == null
                            ? null
                            : () => setState(() {
                                  _selectedDay = null;
                                  _selectedPlace = null;
                                }),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _toolbar(CrmTheme crm, List<String> statuses, _Size size) {
    final monthNav = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton.filledTonal(
        tooltip: 'Previous month',
        onPressed: () => _shiftMonth(-1),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      SizedBox(
        width: size == _Size.compact ? 130 : 160,
        child: Text(
          DateFormat('MMMM yyyy').format(_month),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: size == _Size.compact ? 16 : 19, fontWeight: FontWeight.w800, color: crm.textPrimary),
        ),
      ),
      IconButton.filledTonal(
        tooltip: 'Next month',
        onPressed: () => _shiftMonth(1),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: _goToday,
        icon: const Icon(Icons.today_rounded, size: 18),
        label: const Text('Today'),
      ),
    ]);
    final basis = SegmentedButton<_Basis>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [for (final b in _Basis.values) ButtonSegment(value: b, label: Text(b.label))],
      selected: {_basis},
      onSelectionChanged: (s) => setState(() {
        _basis = s.first;
        _selectedDay = null;
        _selectedPlace = null;
      }),
    );
    final status = SizedBox(
      width: size == _Size.compact ? double.infinity : 200,
      child: DropdownButtonFormField<String>(
        initialValue: statuses.contains(_status) ? _status : 'All',
        isExpanded: true,
        isDense: true,
        decoration: const InputDecoration(
          labelText: 'Status',
          prefixIcon: Icon(Icons.filter_list_rounded, size: 18),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          const DropdownMenuItem(value: 'All', child: Text('All statuses')),
          for (final s in statuses) DropdownMenuItem(value: s, child: Text(s)),
        ],
        onChanged: (v) => setState(() {
          _status = v ?? 'All';
          _selectedPlace = null;
        }),
      ),
    );

    final active = _range != null;
    final dates = SizedBox(
      width: size == _Size.compact ? double.infinity : null,
      child: Material(
        color: active ? crm.primary.withValues(alpha: 0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: active ? crm.primary : crm.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            fit: size == _Size.compact ? FlexFit.tight : FlexFit.loose,
            child: PopupMenuButton<Object>(
              tooltip: 'Filter by date range',
              position: PopupMenuPosition.under,
              onSelected: (v) {
                if (v == 'custom') {
                  _pickRange();
                } else if (v == 'clear') {
                  _setRange(null);
                } else if (v is DateTimeRange) {
                  _setRange(v);
                }
              },
              itemBuilder: (_) => [
                for (final (label, r) in _presets)
                  PopupMenuItem(
                    value: r,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.date_range_outlined, size: 18),
                      title: Text(label),
                      subtitle: Text(_rangeLabel(r)),
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'custom',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_calendar_outlined, size: 18),
                    title: Text('Custom range… (From – To)'),
                  ),
                ),
                if (active)
                  const PopupMenuItem(
                    value: 'clear',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.clear_rounded, size: 18),
                      title: Text('Clear — show the month'),
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.date_range_rounded, size: 18, color: active ? crm.primary : crm.textSecondary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      active ? _rangeLabel(_range!) : 'Date range: whole month',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? crm.primary : crm.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down_rounded, color: crm.textSecondary),
                ]),
              ),
            ),
          ),
          if (active)
            IconButton(
              tooltip: 'Clear date range',
              visualDensity: VisualDensity.compact,
              onPressed: () => _setRange(null),
              icon: Icon(Icons.close_rounded, size: 18, color: crm.primary),
            ),
        ]),
      ),
    );

    if (size == _Size.compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FittedBox(fit: BoxFit.scaleDown, child: monthNav),
        const SizedBox(height: 10),
        dates,
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: basis),
        const SizedBox(height: 10),
        status,
      ]);
    }
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        monthNav,
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [dates, basis, status],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Shared pieces
// ─────────────────────────────────────────────────────────────────────────
/// A full-width titled block — every section of the tab sits in one.
class _Block extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  const _Block({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crm.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: crm.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: crm.primary),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                        if (subtitle != null)
                          Text(subtitle!, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                ]),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Proportional strip of status colours.
class _StatusBar extends StatelessWidget {
  final Map<String, int> counts;
  final double height;
  const _StatusBar(this.counts, {this.height = 6});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return SizedBox(height: height);
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Row(children: [
        for (final e in entries)
          Expanded(flex: e.value, child: Container(height: height, color: _statusColor(e.key))),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Iterable<String> statuses;
  const _Legend(this.statuses);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Wrap(spacing: 12, runSpacing: 6, children: [
      for (final s in statuses)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: _statusColor(s), shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(s, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ]),
    ]);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

// ─────────────────────────────────────────────────────────────────────────
//  Summary
// ─────────────────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final List<Lead> leads;
  const _SummaryStrip({required this.leads});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    int count(bool Function(Lead) f) => leads.where(f).length;
    final converted = count((l) => l.status == 'Converted');
    final items = [
      ('Total leads', '${leads.length}', Icons.groups_rounded, crm.primary),
      ('New', '${count((l) => l.status == 'New')}', Icons.fiber_new_rounded, _statusColor('new')),
      ('Follow-up', '${count((l) => l.status == 'Follow-up')}', Icons.alarm_rounded, _statusColor('follow-up')),
      ('Converted', '$converted', Icons.verified_rounded, _statusColor('converted')),
      ('Conversion', leads.isEmpty ? '—' : '${(converted * 100 / leads.length).toStringAsFixed(0)}%',
          Icons.trending_up_rounded, const Color(0xFF0D9488)),
      ('Hot', '${count((l) => l.priority == 'Hot')}', Icons.local_fire_department_rounded, const Color(0xFFDC2626)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth >= 960 ? 6 : c.maxWidth >= 560 ? 3 : 2;
      final w = (c.maxWidth - 10 * (perRow - 1)) / perRow;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (label, value, icon, color) in items)
          Container(
            width: w,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: crm.border),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                ]),
              ),
            ]),
          ),
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Calendar block
// ─────────────────────────────────────────────────────────────────────────
class _CalendarBlock extends StatelessWidget {
  final _Size size;
  final DateTime month;
  final _Basis basis;
  final Map<DateTime, List<Lead>> byDay;

  /// Active From–To filter; days outside it are greyed out.
  final DateTimeRange? range;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  const _CalendarBlock({
    required this.size,
    required this.month,
    required this.basis,
    required this.byDay,
    required this.range,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7; // Sunday-first grid
    final rows = ((offset + daysInMonth) / 7).ceil();
    // A From–To range can span months; the grid only counts this month.
    final shown = {
      for (final e in byDay.entries)
        if (e.key.year == month.year && e.key.month == month.month) e.key: e.value,
    };
    final maxCount = shown.values.fold<int>(0, (m, l) => max(m, l.length));
    final today = _day(DateTime.now());
    final total = shown.values.fold<int>(0, (s, l) => s + l.length);
    final busiest = shown.entries.isEmpty
        ? null
        : shown.entries.reduce((a, b) => a.value.length >= b.value.length ? a : b);
    final allStatuses = {for (final l in shown.values.expand((x) => x)) l.status}.toList()..sort();
    bool outside(DateTime d) => range != null && (d.isBefore(range!.start) || d.isAfter(range!.end));

    // How much each cell shows, by screen size.
    final (baseH, names) = switch (size) {
      _Size.wide => (132.0, 3),
      _Size.medium => (98.0, 1),
      _Size.compact => (60.0, 0),
    };
    // Grow with the device's text size so the day number and count always fit.
    final cellH = baseH * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final showWeekTotals = size != _Size.compact;
    final weekdays = size == _Size.compact
        ? const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return _Block(
      icon: Icons.calendar_month_rounded,
      title: 'Lead calendar',
      subtitle: [
        '$total leads by ${basis.label.toLowerCase()}${range != null ? ' in ${DateFormat('MMMM').format(month)} within the range' : ''}',
        if (busiest != null) 'busiest ${DateFormat('d MMM').format(busiest.key)} (${busiest.value.length})',
      ].join(' · '),
      trailing: allStatuses.isEmpty ? null : _Legend(allStatuses),
      padding: EdgeInsets.fromLTRB(size == _Size.compact ? 10 : 16, 14, size == _Size.compact ? 10 : 16, 16),
      child: Column(
        children: [
          Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(weekdays[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? crm.destructive.withValues(alpha: 0.8) : crm.textSecondary,
                      )),
                ),
              ),
            if (showWeekTotals) const SizedBox(width: 84, child: Center(child: Text('Week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))),
          ]),
          const SizedBox(height: 8),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                height: cellH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: () {
                            final dayNum = r * 7 + col - offset + 1;
                            if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
                            final date = DateTime(month.year, month.month, dayNum);
                            return _DayCell(
                              date: date,
                              leads: byDay[date] ?? const [],
                              maxCount: maxCount,
                              names: names,
                              compact: size == _Size.compact,
                              isToday: date == today,
                              isSelected: date == selected,
                              outOfRange: outside(date),
                              onTap: () => onSelect(date),
                            );
                          }(),
                        ),
                      ),
                    if (showWeekTotals)
                      SizedBox(
                        width: 84,
                        child: _WeekTotal(
                          leads: [
                            for (var col = 0; col < 7; col++)
                              ...?byDay[DateTime(month.year, month.month, r * 7 + col - offset + 1)],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (size == _Size.compact)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Tap a day to see its leads on the map and in the list below.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _WeekTotal extends StatelessWidget {
  final List<Lead> leads;
  const _WeekTotal({required this.leads});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final converted = leads.where((l) => l.status == 'Converted').length;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: crm.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${leads.length}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          Text('leads', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          if (converted > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('$converted won',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor('converted'))),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final List<Lead> leads;
  final int maxCount, names;
  final bool compact, isToday, isSelected, outOfRange;
  final VoidCallback onTap;
  const _DayCell({
    required this.date,
    required this.leads,
    required this.maxCount,
    required this.names,
    required this.compact,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    this.outOfRange = false,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final n = leads.length;
    final heat = n == 0 || maxCount == 0 ? 0.0 : 0.05 + 0.20 * (n / maxCount);
    final counts = _statusCounts(leads);
    final hot = leads.where((l) => l.priority == 'Hot').length;
    final weekend = date.weekday == DateTime.sunday;

    final tooltip = n == 0
        ? DateFormat('EEE, d MMM').format(date)
        : '${DateFormat('EEE, d MMM').format(date)} — $n lead${n == 1 ? '' : 's'}\n'
            '${counts.entries.map((e) => '${e.key}: ${e.value}').join(' · ')}\n'
            '${leads.take(6).map((l) => '• ${l.name}').join('\n')}${n > 6 ? '\n…and ${n - 6} more' : ''}';

    final dayLabel = Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: isToday ? crm.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isToday ? Colors.white : weekend ? crm.destructive.withValues(alpha: 0.8) : crm.textSecondary,
            )),
      ),
      const Spacer(),
      if (!compact && hot > 0)
        Tooltip(
          message: '$hot hot',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_fire_department_rounded, size: 13, color: Color(0xFFDC2626)),
            Text('$hot', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
          ]),
        ),
    ]);

    // Outside the From–To range: shown faded, not selectable.
    if (outOfRange) {
      return Opacity(
        opacity: 0.35,
        child: Container(
          padding: EdgeInsets.fromLTRB(compact ? 3 : 6, 5, compact ? 3 : 6, 5),
          decoration: BoxDecoration(
            color: crm.input.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: crm.border.withValues(alpha: 0.4)),
          ),
          child: Align(alignment: Alignment.topLeft, child: dayLabel),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: n == 0 ? crm.input.withValues(alpha: 0.45) : Color.alphaBlend(crm.primary.withValues(alpha: heat), crm.surface),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.fromLTRB(compact ? 3 : 6, 5, compact ? 3 : 6, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? crm.primary : crm.border.withValues(alpha: n == 0 ? 0.4 : 0.8),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: compact
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    dayLabel,
                    const Spacer(),
                    if (n > 0)
                      Center(
                        child: Text('$n',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary, height: 1)),
                      ),
                    const SizedBox(height: 3),
                    if (n > 0) _StatusBar(counts, height: 3),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dayLabel,
                      const SizedBox(height: 2),
                      if (n > 0) ...[
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('$n',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary, height: 1.1)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(n == 1 ? 'lead' : 'leads',
                                overflow: TextOverflow.clip,
                                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        // Names fill whatever height is left: as many as fit
                        // at the device's text size, then "+N more" — so the
                        // cell can never overflow.
                        Expanded(
                          child: LayoutBuilder(builder: (context, box) {
                            final nameStyle = TextStyle(fontSize: 11.5, color: crm.textPrimary);
                            final moreStyle =
                                TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.primary);
                            final scaler = MediaQuery.textScalerOf(context);
                            double lineHeight(TextStyle s) => (TextPainter(
                                  text: TextSpan(text: 'Ag', style: s),
                                  textDirection: Directionality.of(context),
                                  textScaler: scaler,
                                  maxLines: 1,
                                )..layout())
                                    .height;
                            final rowH = lineHeight(nameStyle) + 2; // + bottom padding
                            final moreH = lineHeight(moreStyle);
                            var fit = min(names, min(n, (box.maxHeight / rowH).floor()));
                            if (fit < n) {
                              // Leave room for the "+N more" line.
                              fit = min(fit, ((box.maxHeight - moreH) / rowH).floor());
                            }
                            fit = max(0, fit);
                            final hidden = n - fit;
                            return ClipRect(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final l in leads.take(fit))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                              color: _statusColor(l.status), shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(l.name,
                                              maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
                                        ),
                                      ]),
                                    ),
                                  // Only once some names are listed; otherwise
                                  // the count above already says it all.
                                  if (hidden > 0 && fit > 0)
                                    Text('+$hidden more',
                                        maxLines: 1, overflow: TextOverflow.clip, style: moreStyle),
                                ],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 2),
                        _StatusBar(counts, height: 4),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Map block
// ─────────────────────────────────────────────────────────────────────────
class _Place {
  final String name;
  final LatLng point;
  final List<Lead> leads = [];
  _Place(this.name, this.point);

  int get hot => leads.where((l) => l.priority == 'Hot').length;
  int get converted => leads.where((l) => l.status == 'Converted').length;
}

class _MapBlock extends StatefulWidget {
  final _Size size;
  final List<Lead> leads;
  final String scope;
  final String? selectedPlace;
  final ValueChanged<String> onPlace;
  const _MapBlock({
    required this.size,
    required this.leads,
    required this.scope,
    required this.selectedPlace,
    required this.onPlace,
  });

  @override
  State<_MapBlock> createState() => _MapBlockState();
}

class _MapBlockState extends State<_MapBlock> {
  static const _home = LatLng(10.4, 76.4);
  // Fits all of Kerala in each size's map height.
  double get _homeZoom => switch (widget.size) {
        _Size.wide => 7.4,
        _Size.medium => 7.0,
        _Size.compact => 6.6,
      };
  final _map = MapController();

  void _zoom(double delta) => _map.move(_map.camera.center, (_map.camera.zoom + delta).clamp(5, 16));

  void _select(_Place p) {
    final selecting = widget.selectedPlace != p.name;
    widget.onPlace(p.name);
    if (selecting) _map.move(p.point, max(_map.camera.zoom, 8.5));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final placeMap = <String, _Place>{};
    var unmapped = 0;
    for (final l in widget.leads) {
      final p = _placeOf(l);
      if (p == null) {
        unmapped++;
        continue;
      }
      placeMap.putIfAbsent(p.$1, () => _Place(p.$1, p.$2)).leads.add(l);
    }
    final places = placeMap.values.toList()..sort((a, b) => b.leads.length.compareTo(a.leads.length));
    final maxCount = places.isEmpty ? 0 : places.first.leads.length;
    final selected = placeMap[widget.selectedPlace];

    final markers = [
      for (final p in places.reversed) // biggest drawn last = on top
        () {
          final n = p.leads.length;
          final dia = 28.0 + 30.0 * (maxCount == 0 ? 0 : n / maxCount);
          final isSel = p.name == widget.selectedPlace;
          final convShare = n == 0 ? 0.0 : p.converted / n;
          return Marker(
            point: p.point,
            width: dia + 80,
            height: dia + 22,
            child: GestureDetector(
              onTap: () => _select(p),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: dia,
                  height: dia,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isSel ? crm.primary : const Color(0xFFE11D48)).withValues(alpha: 0.88),
                    border: Border.all(color: Colors.white, width: isSel ? 3 : 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: isSel ? 12 : 6),
                    ],
                  ),
                  // A green ring shows what share of the place's leads converted.
                  foregroundDecoration: convShare == 0
                      ? null
                      : BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _statusColor('converted'), width: 2 + 3 * convShare),
                        ),
                  child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 3)],
                  ),
                  child: Text(p.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                ),
              ]),
            ),
          );
        }(),
    ];

    final mapHeight = switch (widget.size) {
      _Size.wide => 540.0,
      _Size.medium => 440.0,
      _Size.compact => 340.0,
    };

    final map = SizedBox(
      height: mapHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _home,
              initialZoom: _homeZoom,
              minZoom: 5,
              maxZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.nizan.crm',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          // Zoom controls
          Positioned(
            right: 10,
            top: 10,
            child: _MapControls(
              onZoomIn: () => _zoom(1),
              onZoomOut: () => _zoom(-1),
              onReset: () => _map.move(_home, _homeZoom),
            ),
          ),
          // Legend — hidden on phones, where it would cover the southern pins.
          if (widget.size != _Size.compact)
            Positioned(
              left: 10,
              bottom: 10,
              child: _MapLegend(unmapped: unmapped),
            ),
          if (selected != null)
            Positioned(
              left: 10,
              top: 10,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.size == _Size.compact ? 240 : 300),
                child: _PlacePopup(place: selected, onClose: () => widget.onPlace(selected.name)),
              ),
            ),
          if (places.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: crm.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: crm.border),
                ),
                child: Text('No leads with a known place for ${widget.scope}.',
                    style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
              ),
            ),
        ]),
      ),
    );

    final panel = _PlacesPanel(
      places: places,
      total: widget.leads.length,
      selected: widget.selectedPlace,
      onTap: _select,
      scrollable: widget.size == _Size.wide,
    );

    return _Block(
      icon: Icons.map_rounded,
      title: 'Leads by place',
      subtitle: '${widget.scope} · ${places.length} place${places.length == 1 ? '' : 's'}'
          '${unmapped > 0 ? ' · $unmapped without a known place' : ''}',
      child: widget.size == _Size.wide
          ? SizedBox(
              height: mapHeight,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: map),
                const SizedBox(width: 14),
                SizedBox(width: 330, child: panel),
              ]),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              map,
              const SizedBox(height: 14),
              panel,
            ]),
    );
  }
}

class _MapControls extends StatelessWidget {
  final VoidCallback onZoomIn, onZoomOut, onReset;
  const _MapControls({required this.onZoomIn, required this.onZoomOut, required this.onReset});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback onTap) => Tooltip(
          message: tip,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: const Color(0xFF1F2937))),
          ),
        );
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.add_rounded, 'Zoom in', onZoomIn),
        const SizedBox(width: 36, child: Divider(height: 1)),
        btn(Icons.remove_rounded, 'Zoom out', onZoomOut),
        const SizedBox(width: 36, child: Divider(height: 1)),
        btn(Icons.center_focus_strong_rounded, 'Show all of Kerala', onReset),
      ]),
    );
  }
}

class _MapLegend extends StatelessWidget {
  final int unmapped;
  const _MapLegend({required this.unmapped});

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(fontSize: 11, color: Color(0xFF374151));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('Bigger circle = more leads', style: text),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _statusColor('converted'), width: 3),
            ),
          ),
          const SizedBox(width: 6),
          const Text('Green ring = share converted', style: text),
        ]),
      ]),
    );
  }
}

class _PlacePopup extends StatelessWidget {
  final _Place place;
  final VoidCallback onClose;
  const _PlacePopup({required this.place, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final counts = _statusCounts(place.leads);
    final n = place.leads.length;
    return Material(
      color: crm.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.location_on_rounded, size: 18, color: crm.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(place.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Clear place',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                '$n lead${n == 1 ? '' : 's'} · ${place.converted} converted'
                '${place.hot > 0 ? ' · ${place.hot} hot' : ''}',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
              ),
              const SizedBox(height: 8),
              _StatusBar(counts, height: 6),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in counts.entries) _Pill('${e.key} ${e.value}', _statusColor(e.key)),
              ]),
              const SizedBox(height: 8),
              for (final l in place.leads.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: _statusColor(l.status), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(l.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
                    ),
                    Text(DateFormat('d MMM').format((l.eventDate ?? l.enquiryDate).toLocal()),
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ]),
                ),
              if (n > 5)
                Text('+${n - 5} more in the list below',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.primary)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PlacesPanel extends StatelessWidget {
  final List<_Place> places;
  final int total;
  final String? selected;
  final ValueChanged<_Place> onTap;
  final bool scrollable;
  const _PlacesPanel({
    required this.places,
    required this.total,
    required this.selected,
    required this.onTap,
    required this.scrollable,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final rows = [
      for (final p in places)
        () {
          final n = p.leads.length;
          final isSel = p.name == selected;
          final share = total == 0 ? 0.0 : n / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: isSel ? crm.primary.withValues(alpha: 0.08) : crm.input.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(p),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? crm.primary : Colors.transparent, width: 1.5),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(
                        child: Text(p.name,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: crm.textPrimary)),
                      ),
                      Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: crm.textPrimary)),
                      Text('  ${(share * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                    ]),
                    const SizedBox(height: 6),
                    _StatusBar(_statusCounts(p.leads), height: 5),
                    const SizedBox(height: 5),
                    Text(
                      [
                        '${p.converted} converted',
                        if (p.hot > 0) '${p.hot} hot',
                        '${_statusCounts(p.leads)['Follow-up'] ?? 0} follow-up',
                      ].join(' · '),
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }(),
    ];

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text('PLACES', style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: crm.textSecondary)),
        const Spacer(),
        Text('tap to filter', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
      ]),
    );

    if (places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No places to show.', style: TextStyle(color: crm.textSecondary)),
        ),
      );
    }
    if (scrollable) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Expanded(child: ListView(children: rows)),
      ]);
    }
    // Below the map on smaller screens: two columns when there is room.
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 2 : 1;
      final w = (c.maxWidth - 8 * (cols - 1)) / cols;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Wrap(spacing: 8, children: [for (final r in rows) SizedBox(width: w, child: r)]),
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Details list
// ─────────────────────────────────────────────────────────────────────────
class _DetailsBlock extends StatelessWidget {
  final List<Lead> leads;
  final _Basis basis;
  final String title;
  final VoidCallback? onClear;
  final String clearLabel;
  const _DetailsBlock({
    required this.leads,
    required this.basis,
    required this.title,
    required this.onClear,
    this.clearLabel = 'Show whole month',
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return _Block(
      icon: Icons.list_alt_rounded,
      title: title,
      subtitle: '${leads.length} lead${leads.length == 1 ? '' : 's'} · sorted by ${basis.label.toLowerCase()}',
      trailing: onClear == null
          ? null
          : TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: Text(clearLabel),
            ),
      child: leads.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No leads here. Pick another day or place.',
                  textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
            )
          : Column(children: [
              for (var i = 0; i < leads.length; i++) ...[
                if (i > 0) Divider(height: 1, color: crm.border),
                _LeadRow(lead: leads[i]),
              ],
            ]),
    );
  }
}

class _LeadRow extends StatelessWidget {
  final Lead lead;
  const _LeadRow({required this.lead});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final l = lead;
    final fmt = DateFormat('d MMM yyyy');
    final place = [l.location, l.district].where((s) => s.trim().isNotEmpty).toSet().join(', ');
    final eventDate = l.eventDate ?? l.enquiryDate;
    final facts = <(IconData, String)>[
      (Icons.celebration_outlined, l.eventType.isNotEmpty ? l.eventType : l.leadType),
      (Icons.event_outlined, 'Event ${fmt.format(eventDate.toLocal())}'),
      if (place.isNotEmpty) (Icons.location_on_outlined, place),
      if (l.source.isNotEmpty) (Icons.campaign_outlined, l.source),
      (Icons.inbox_outlined, 'Received ${fmt.format(l.leadDate.toLocal())}'),
      if (l.followUpDate != null)
        (Icons.alarm_rounded, 'Follow-up ${DateFormat('d MMM, h:mm a').format(l.followUpDate!.toLocal())}'),
      if (l.createdByName.isNotEmpty) (Icons.person_add_alt_outlined, l.createdByName),
    ];

    return InkWell(
      onTap: () => context.go('/sales/leads/${l.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _statusColor(l.status).withValues(alpha: 0.15),
              child: Text(l.name.isEmpty ? '?' : l.name[0].toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w800, color: _statusColor(l.status))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(l.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: crm.textPrimary)),
                    _Pill(l.status, _statusColor(l.status)),
                    if (l.priority.isNotEmpty)
                      _Pill(l.priority, switch (l.priority) {
                        'Hot' => const Color(0xFFDC2626),
                        'Warm' => const Color(0xFFD97706),
                        _ => const Color(0xFF0EA5E9),
                      }),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    for (final (icon, text) in facts)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 13, color: crm.textSecondary),
                        const SizedBox(width: 4),
                        Text(text, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                      ]),
                  ]),
                  if (l.remarks.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l.remarks.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: crm.textSecondary)),
                    ),
                ],
              ),
            ),
            if (l.phone.isNotEmpty)
              IconButton(
                tooltip: 'Call ${l.phone}',
                onPressed: () => launchUrl(Uri.parse('tel:${l.phone.replaceAll(RegExp(r'[\s\-]'), '')}')),
                icon: const Icon(Icons.call_rounded, color: Color(0xFF16A34A)),
              ),
          ],
        ),
      ),
    );
  }
}
