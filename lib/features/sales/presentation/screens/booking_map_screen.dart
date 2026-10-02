import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/sales/data/booking_map.dart';
import 'package:nizan_crm/features/sales/services/booking_map_service.dart';

/// Booking Map — where bookings come from, by place (pincode), with a package
/// split. Bubble size and colour show volume (green → amber → red).
class BookingMapScreen extends ConsumerStatefulWidget {
  const BookingMapScreen({super.key});

  @override
  ConsumerState<BookingMapScreen> createState() => _BookingMapScreenState();
}

enum _Period { thisFy, lastFy, last12, allTime }

enum _Metric { bookings, sales, avg }

const _periodLabels = {
  _Period.thisFy: 'This FY',
  _Period.lastFy: 'Last FY',
  _Period.last12: 'Last 12 months',
  _Period.allTime: 'All time',
};

const _metricLabels = {
  _Metric.bookings: 'Bookings',
  _Metric.sales: 'Sales',
  _Metric.avg: 'Avg value',
};

class _BookingMapScreenState extends ConsumerState<BookingMapScreen> {
  final _map = MapController();
  final _searchCtrl = TextEditingController();
  _Period _period = _Period.thisFy;
  String _basis = 'event';
  _Metric _metric = _Metric.bookings;
  String? _type; // null = all packages
  String _search = '';
  String? _selectedKey;

  // While pincodes are still being located on the server, refresh now and then.
  Timer? _refreshTimer;
  int _refreshes = 0;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  BookingMapQuery get _query {
    final now = DateTime.now();
    final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
    switch (_period) {
      case _Period.thisFy:
        return (
          from: DateTime(fyStartYear, 4, 1),
          to: DateTime(fyStartYear + 1, 3, 31),
          basis: _basis,
        );
      case _Period.lastFy:
        return (
          from: DateTime(fyStartYear - 1, 4, 1),
          to: DateTime(fyStartYear, 3, 31),
          basis: _basis,
        );
      case _Period.last12:
        return (
          from: DateTime(now.year - 1, now.month, now.day),
          to: DateTime(now.year, now.month, now.day),
          basis: _basis,
        );
      case _Period.allTime:
        return (from: null, to: null, basis: _basis);
    }
  }

  String get _periodSubtitle {
    final q = _query;
    final basis = _basis == 'event' ? 'event date' : 'date added';
    if (q.from == null) return 'All time · by $basis';
    String d(DateTime x) => '${x.day} ${_months[x.month - 1]} ${x.year}';
    return '${d(q.from!)} – ${d(q.to!)} · by $basis';
  }

  void _scheduleRefreshIfPending(BookingMapData data) {
    if (data.pendingGeocodes <= 0 || _refreshes >= 30) return;
    if (_refreshTimer?.isActive ?? false) return;
    final q = _query;
    _refreshTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      _refreshes++;
      ref.invalidate(bookingMapProvider(q));
    });
  }

  // ── Metric helpers ───────────────────────────────────────────────────────
  double _valueOf(BookingMapPlace p) {
    final s = p.statFor(_type);
    switch (_metric) {
      case _Metric.bookings:
        return s.bookings.toDouble();
      case _Metric.sales:
        return s.sales;
      case _Metric.avg:
        return s.bookings > 0 ? s.sales / s.bookings : 0;
    }
  }

  String _fmtValue(double v) =>
      _metric == _Metric.bookings ? _int(v.round()) : _inr(v);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(bookingMapProvider(_query));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        onRetry: () => ref.invalidate(bookingMapProvider(_query)),
      ),
      data: (data) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scheduleRefreshIfPending(data));
        // A package filter can make the selected type disappear (period change).
        final typeNames = data.types.map((t) => t.name).toList();
        final type = typeNames.contains(_type) ? _type : null;

        final places = data.places
            .where((p) => p.statFor(type).bookings > 0)
            .toList()
          ..sort((a, b) => _valueOf(b).compareTo(_valueOf(a)));

        final selectedType =
            type == null ? null : data.types.firstWhere((t) => t.name == type);
        final totalBookings = selectedType?.bookings ?? data.totalBookings;
        final totalSales = selectedType?.sales ?? data.totalSales;

        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 1000;
          final header = _header(crm, data, totalBookings, totalSales,
              places.length, wide);
          final controls = _controls(crm, data, type, wide);
          final notices = _notices(crm, data);
          final map = _mapView(crm, places, totalBookings, totalSales, data);
          final panel =
              _panel(crm, places, totalBookings, totalSales, wide: wide);

          if (wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 14),
                controls,
                ...notices,
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: map),
                      const SizedBox(width: 14),
                      SizedBox(width: 320, child: panel),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              header,
              const SizedBox(height: 12),
              controls,
              ...notices,
              const SizedBox(height: 12),
              SizedBox(height: 440, child: map),
              const SizedBox(height: 14),
              panel,
            ],
          );
        });
      },
    );
  }

  // ── Header: title + totals ───────────────────────────────────────────────
  Widget _header(CrmTheme crm, BookingMapData data, int bookings, double sales,
      int placeCount, bool wide) {
    final avg = bookings > 0 ? sales / bookings : 0.0;
    Widget stat(String value, String label, Color color) => Container(
          constraints: const BoxConstraints(minWidth: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: crm.textSecondary)),
            ],
          ),
        );

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_rounded, color: crm.primary),
            const SizedBox(width: 8),
            Text('Booking Map',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary)),
          ],
        ),
        const SizedBox(height: 2),
        Text('Where our bookings come from · $_periodSubtitle',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      ],
    );

    final stats = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        stat(_int(bookings), 'Bookings', crm.primary),
        stat(_inr(sales), 'Sales', const Color(0xFF1A9C6F)),
        stat(_int(placeCount), 'Places', const Color(0xFF5A3DB5)),
        stat(_inr(avg), 'Avg booking value', const Color(0xFFB45309)),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [Expanded(child: title), stats],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const SizedBox(height: 12), stats],
    );
  }

  // ── Controls: package, metric, period, basis, search ─────────────────────
  Widget _controls(
      CrmTheme crm, BookingMapData data, String? type, bool wide) {
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(t.toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: crm.textSecondary)),
        );

    Widget chip(String text, bool on, VoidCallback onTap, {Color? color}) {
      final c = color ?? crm.primary;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? c.withValues(alpha: 0.10) : crm.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: on ? c : crm.border, width: on ? 1.5 : 1),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? c : crm.textPrimary)),
        ),
      );
    }

    // Up to 6 packages as chips; the rest are rare one-offs.
    final topTypes = data.types.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          label('Package'),
          chip('All', type == null, () => setState(() => _type = null)),
          for (final t in topTypes)
            Tooltip(
              message: t.topServices.join(', '),
              child: chip('${t.name} (${t.bookings})', type == t.name,
                  () => setState(() => _type = t.name)),
            ),
          const SizedBox(width: 10),
          label('View'),
          for (final m in _Metric.values)
            chip(_metricLabels[m]!, _metric == m,
                () => setState(() => _metric = m),
                color: const Color(0xFF334155)),
          const SizedBox(width: 10),
          label('Period'),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: crm.border),
              ),
              child: DropdownButton<_Period>(
                value: _period,
                isDense: true,
                items: [
                  for (final p in _Period.values)
                    DropdownMenuItem(value: p, child: Text(_periodLabels[p]!)),
                ],
                onChanged: (p) => setState(() {
                  _period = p ?? _period;
                  _selectedKey = null;
                  _refreshes = 0;
                }),
              ),
            ),
          ),
          chip(_basis == 'event' ? 'By event date' : 'By date added', true,
              () => setState(() {
                    _basis = _basis == 'event' ? 'added' : 'event';
                    _selectedKey = null;
                    _refreshes = 0;
                  }),
              color: const Color(0xFF5A3DB5)),
          SizedBox(
            width: wide ? 220 : double.infinity,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search place / pincode…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _search = '';
                        }),
                      ),
              ),
            ),
          ),
          // Legend
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Low',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              const SizedBox(width: 6),
              Container(
                width: 80,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(colors: [
                    Color(0xFF4EC994),
                    Color(0xFFF5A623),
                    Color(0xFFE74C3C),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              Text('High',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _notices(CrmTheme crm, BookingMapData data) {
    Widget note(IconData icon, String text, Color color) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(text,
                        style: TextStyle(fontSize: 12.5, color: color))),
              ],
            ),
          ),
        );
    return [
      if (data.pendingGeocodes > 0)
        note(
          Icons.my_location_rounded,
          'Locating ${data.pendingGeocodes} pincode${data.pendingGeocodes == 1 ? '' : 's'} on the map… '
          'until then they sit at their district centre. This refreshes automatically.',
          const Color(0xFF1A6FC4),
        ),
      if (data.unmappedBookings > 0)
        note(
          Icons.info_outline_rounded,
          '${data.unmappedBookings} booking${data.unmappedBookings == 1 ? '' : 's'} '
          '(${_inr(data.unmappedSales)}) have no pincode or district, so they can\'t be placed on the map.',
          crm.textSecondary,
        ),
    ];
  }

  // ── Map ──────────────────────────────────────────────────────────────────
  Widget _mapView(CrmTheme crm, List<BookingMapPlace> places, int totalBookings,
      double totalSales, BookingMapData data) {
    final values = places.map(_valueOf).toList();
    final minV = values.isEmpty ? 0.0 : values.reduce(math.min);
    final maxV = values.isEmpty ? 1.0 : values.reduce(math.max);
    double norm(double v) =>
        math.pow(((v - minV) / ((maxV - minV) == 0 ? 1 : (maxV - minV))), 0.55)
            .toDouble();

    // Big bubbles first so small ones stay clickable on top.
    final drawOrder = [...places]
      ..sort((a, b) => _valueOf(b).compareTo(_valueOf(a)));

    BookingMapPlace? selected;
    for (final p in places) {
      if (p.key == _selectedKey) selected = p;
    }

    bool matches(BookingMapPlace p) =>
        _search.isEmpty ||
        p.name.toLowerCase().contains(_search) ||
        p.district.toLowerCase().contains(_search);

    final markers = <Marker>[
      for (final p in drawOrder)
        () {
          final t = norm(_valueOf(p));
          final size = 14 + 40 * math.sqrt(t);
          final isSel = p.key == _selectedKey;
          final faded = !matches(p);
          return Marker(
            point: LatLng(p.lat, p.lng),
            width: size,
            height: size,
            child: GestureDetector(
              onTap: () => setState(() => _selectedKey = p.key),
              child: Tooltip(
                message: '${p.name}\n${_fmtValue(_valueOf(p))}',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _heat(t).withValues(
                        alpha: faded ? 0.10 : (p.approximate ? 0.55 : 0.82)),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF1A2A3A)
                          : (p.approximate
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white),
                      width: isSel ? 3 : 1.5,
                    ),
                    boxShadow: [
                      if (!faded)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }(),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: crm.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: const LatLng(10.8, 76.2), // Kerala
                initialZoom: 7.2,
                // Open zoomed to fit the bookings (falls back to Kerala).
                initialCameraFit: places.length >= 2
                    ? CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(
                            [for (final p in places) LatLng(p.lat, p.lng)]),
                        padding: const EdgeInsets.all(48),
                        maxZoom: 11,
                      )
                    : null,
                minZoom: 5,
                maxZoom: 17,
                onTap: (_, _) => setState(() => _selectedKey = null),
              ),
              children: [
                // OpenStreetMap standard tiles: free, no API key (CARTO's
                // basemaps now require a key and show a watermark without one).
                // Same tiles as the Marketing "Kerala bookings" map.
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nizan.crm',
                ),
                MarkerLayer(markers: markers),
                // Compact attribution (flutter_map's SimpleAttributionWidget
                // overflows on narrow phones).
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.white.withValues(alpha: 0.8),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (places.isEmpty)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: crm.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: crm.border),
                  ),
                  child: Text('No bookings in this period.',
                      style: TextStyle(color: crm.textSecondary)),
                ),
              ),
            if (selected != null)
              Positioned(
                top: 12,
                left: 12,
                child: _placeCard(crm, selected, places, totalBookings,
                    totalSales, data),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeCard(CrmTheme crm, BookingMapPlace p,
      List<BookingMapPlace> ranked, int totalBookings, double totalSales,
      BookingMapData data) {
    final s = p.statFor(_type);
    final rank = ranked.indexWhere((x) => x.key == p.key) + 1;
    final share = totalBookings > 0 ? s.bookings / totalBookings * 100 : 0.0;
    final avg = s.bookings > 0 ? s.sales / s.bookings : 0.0;

    Widget metric(String v, String l) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: crm.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
              Text(l.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.5,
                      color: crm.textSecondary)),
            ],
          ),
        );

    // Package split (only meaningful when viewing all packages).
    final split = _type != null
        ? const <MapEntry<String, BookingMapTypeStat>>[]
        : (p.types.entries.toList()
          ..sort((a, b) => b.value.bookings.compareTo(a.value.bookings)));
    final maxSplit = split.isEmpty ? 1 : split.first.value.bookings;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: crm.surface,
      child: Container(
        width: 270,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: crm.textPrimary)),
                        Text(
                            'Rank #$rank · ${share.toStringAsFixed(1)}% of bookings · ${p.subtitle}',
                            style: TextStyle(
                                fontSize: 11, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedKey = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Two rows of two content-sized tiles (a fixed-ratio grid
            // clipped the labels at larger text sizes).
            Row(
              children: [
                Expanded(child: metric(_int(s.bookings), 'Bookings')),
                const SizedBox(width: 6),
                Expanded(child: metric(_inr(s.sales), 'Sales')),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: metric(_inr(avg), 'Avg value')),
                const SizedBox(width: 6),
                Expanded(
                    child: metric(
                        '${share.toStringAsFixed(1)}%', '% of bookings')),
              ],
            ),
            if (split.length > 1) ...[
              const SizedBox(height: 10),
              Text('By package',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: crm.textSecondary)),
              const SizedBox(height: 4),
              for (final e in split.take(5))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: crm.textPrimary)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: e.value.bookings / maxSplit,
                            minHeight: 6,
                            backgroundColor: crm.border,
                            valueColor:
                                AlwaysStoppedAnimation(crm.primary),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text('${e.value.bookings}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: crm.textPrimary)),
                      ),
                    ],
                  ),
                ),
            ],
            if (p.approximate) ...[
              const SizedBox(height: 8),
              Text(
                p.pincode.isEmpty
                    ? 'No pincode on these bookings — shown at the district centre.'
                    : 'Still locating this pincode — shown at the district centre for now.',
                style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Side panel: top places ───────────────────────────────────────────────
  Widget _panel(CrmTheme crm, List<BookingMapPlace> places, int totalBookings,
      double totalSales,
      {required bool wide}) {
    final shown = places
        .where((p) =>
            _search.isEmpty ||
            p.name.toLowerCase().contains(_search) ||
            p.district.toLowerCase().contains(_search))
        .take(wide ? 60 : 25)
        .toList();
    final denom = _metric == _Metric.sales ? totalSales : totalBookings.toDouble();
    final values = places.map(_valueOf).toList();
    final minV = values.isEmpty ? 0.0 : values.reduce(math.min);
    final maxV = values.isEmpty ? 1.0 : values.reduce(math.max);

    final rows = [
      for (var i = 0; i < shown.length; i++)
        () {
          final p = shown[i];
          final v = _valueOf(p);
          final t = math
              .pow((v - minV) / ((maxV - minV) == 0 ? 1 : (maxV - minV)), 0.55)
              .toDouble();
          final pct = _metric == _Metric.avg || denom <= 0
              ? ''
              : '${(v / denom * 100).toStringAsFixed(1)}%';
          final sel = p.key == _selectedKey;
          return InkWell(
            onTap: () {
              setState(() => _selectedKey = p.key);
              _map.move(LatLng(p.lat, p.lng), p.pincode.isEmpty ? 10 : 13);
            },
            child: Container(
              color: sel ? crm.primary.withValues(alpha: 0.07) : null,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${places.indexOf(p) + 1}',
                        textAlign: TextAlign.right,
                        style:
                            TextStyle(fontSize: 11, color: crm.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(color: _heat(t), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: crm.textPrimary)),
                        Text(p.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmtValue(v),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      if (pct.isNotEmpty)
                        Text(pct,
                            style: TextStyle(
                                fontSize: 10.5, color: crm.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }(),
    ];

    final header = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top places by ${_metricLabels[_metric]!.toLowerCase()}',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary)),
          Text(_type == null ? 'All packages' : '$_type only',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ],
      ),
    );

    final body = shown.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                  _search.isEmpty ? 'No places yet.' : 'No place matches “$_search”.',
                  style: TextStyle(color: crm.textSecondary)),
            ),
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: wide
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(
                  child: body ??
                      ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: crm.border),
                        itemBuilder: (_, i) => rows[i],
                      ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                if (body != null)
                  body
                else
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: crm.border),
                    rows[i],
                  ],
              ],
            ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Green → amber → red, t in 0..1 (same scale as the reference map).
Color _heat(double t) {
  const a = Color(0xFF4EC994), b = Color(0xFFF5A623), c = Color(0xFFE74C3C);
  final x = t.clamp(0.0, 1.0);
  return x < 0.5 ? Color.lerp(a, b, x * 2)! : Color.lerp(b, c, (x - 0.5) * 2)!;
}

String _int(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// Compact Indian rupees: ₹950 · ₹12.5K · ₹4.6L · ₹2.53Cr
String _inr(double v) {
  if (v >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)}Cr';
  if (v >= 1e5) return '₹${(v / 1e5).toStringAsFixed(1)}L';
  if (v >= 1e3) return '₹${(v / 1e3).toStringAsFixed(1)}K';
  return '₹${v.round()}';
}
