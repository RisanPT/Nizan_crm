import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';

/// Kerala district/region coordinates for plotting booking volume. Copied from
/// the dashboard's enquiry map (`dashboard_screen.dart`) so this analytics
/// widget stays self-contained and the working dashboard is untouched.
const Map<String, LatLng> kBookingDistrictCoordinates = {
  'kasaragod': LatLng(12.5102, 74.9852),
  'kannur': LatLng(11.8745, 75.3704),
  'kozhikode': LatLng(11.2588, 75.7804),
  'calicut': LatLng(11.2588, 75.7804),
  'wayanad': LatLng(11.6854, 76.1320),
  'malappuram': LatLng(11.0722, 76.0740),
  'palakkad': LatLng(10.7867, 76.6548),
  'thrissur': LatLng(10.5276, 76.2144),
  'ernakulam': LatLng(9.9816, 76.2999),
  'kochi': LatLng(9.9816, 76.2999),
  'idukki': LatLng(9.8500, 76.9700),
  'kottayam': LatLng(9.5916, 76.5224),
  'alappuzha': LatLng(9.4981, 76.3388),
  'pathanamthitta': LatLng(9.2648, 76.7870),
  'kollam': LatLng(8.8932, 76.6141),
  'trivandrum': LatLng(8.5241, 76.9366),
  'tvm': LatLng(8.5241, 76.9366),
};

LatLng? _coordFor(String location) {
  final normalized = location.toLowerCase().trim();
  for (final entry in kBookingDistrictCoordinates.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  return null;
}

/// An interactive Kerala map that plots booking volume from segment rows
/// (region or district). Rows whose name doesn't resolve to a known Kerala
/// district are skipped; `unmappedCount` reports how many bookings that was.
class KeralaBookingsMap extends StatelessWidget {
  final List<SegmentRow> rows;
  final double height;
  const KeralaBookingsMap({super.key, required this.rows, this.height = 320});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;

    // Sum bookings per resolved coordinate (several names can map to one point).
    final Map<LatLng, int> counts = {};
    final Map<LatLng, String> labels = {};
    for (final r in rows) {
      final c = _coordFor(r.name);
      if (c == null || r.bookings <= 0) continue;
      counts[c] = (counts[c] ?? 0) + r.bookings;
      labels.putIfAbsent(c, () => _canonical(r.name));
    }

    final markers = <Marker>[
      for (final entry in counts.entries)
        Marker(
          point: entry.key,
          width: 52,
          height: 52,
          child: _BookingMapDot(
            label: labels[entry.key] ?? '',
            count: entry.value,
            color: crm.primary,
          ),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(10.5, 76.2), // Center of Kerala
                initialZoom: 6.9,
                minZoom: 5.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nizan.crm',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            if (markers.isEmpty)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: crm.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: crm.border),
                  ),
                  child: Text('No mappable location data yet.',
                      style:
                          TextStyle(color: crm.textSecondary, fontSize: 12.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _canonical(String name) {
    final norm = name.toLowerCase();
    for (final key in kBookingDistrictCoordinates.keys) {
      if (norm.contains(key)) {
        var label = key[0].toUpperCase() + key.substring(1);
        if (label == 'Tvm') label = 'Trivandrum';
        if (label == 'Kochi') label = 'Ernakulam';
        if (label == 'Calicut') label = 'Kozhikode';
        return label;
      }
    }
    return name;
  }
}

/// Pulsing count pin with a tap-to-detail dialog. Adapted from the dashboard's
/// `_MapPulsingDot`, themed via CrmTheme and worded for bookings.
class _BookingMapDot extends StatefulWidget {
  final String label;
  final int count;
  final Color color;
  const _BookingMapDot(
      {required this.label, required this.count, required this.color});

  @override
  State<_BookingMapDot> createState() => _BookingMapDotState();
}

class _BookingMapDotState extends State<_BookingMapDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.location_on, color: color),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              '${widget.count} booking${widget.count == 1 ? '' : 's'} from ${widget.label}.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close', style: TextStyle(color: color))),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 2.2).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            ),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.6, end: 0.0).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOut),
              ),
              child: Container(
                width: 28,
                height: 28,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 2),
              ],
            ),
            alignment: Alignment.center,
            child: Text('${widget.count}',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
