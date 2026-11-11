import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/bookings/data/next_work_hint.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/map_link.dart';

/// On an artist's work card, when they have more than one work that day: where this
/// one falls in the day and — except for the last — the next work, and how far it is.
///
///   WORK 1 OF 3 TODAY
///   Next: Beena · 1:00 PM – 4:00 PM
///   🚗 20 km · about 40 min            [Map]
class NextWorkStrip extends StatelessWidget {
  final NextWorkHint hint;

  /// False when the server has no distance service: the next work is named, no distance.
  final bool distanceReady;

  /// "Today" / "On 30 Oct" — what the position is counted within.
  final String dayLabel;

  /// Opens a link in the maps app; null hides the Map button.
  final ValueChanged<String>? onOpenMap;

  const NextWorkStrip({
    super.key,
    required this.hint,
    required this.distanceReady,
    required this.dayLabel,
    this.onOpenMap,
  });

  /// A link to the next work's venue: its saved map link, else a map search for its address.
  static String? mapLinkFor(NextWork next) {
    final saved = mapLaunchUri(next.mapUrl);
    if (saved != null) return saved.toString();
    final place = next.place.trim();
    if (place.isEmpty) return null;
    return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': place}).toString();
  }

  static String distanceText(double km, {required bool approximate}) {
    final text = km == km.roundToDouble() ? '${km.toStringAsFixed(0)} km' : '${km.toStringAsFixed(1)} km';
    return approximate ? 'About $text' : text;
  }

  static String durationText(int minutes) {
    if (minutes <= 0) return '';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String _time(DateTime? t) => t == null ? '' : DateFormat('h:mm a').format(t);

  @override
  Widget build(BuildContext context) {
    if (!hint.isMultiWorkDay) return const SizedBox.shrink();
    final crm = context.crmColors;
    final next = hint.next;

    final title = Text(
      'WORK ${hint.position} OF ${hint.total} ${dayLabel.toUpperCase()}',
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary),
    );

    if (next == null) {
      return Container(
        key: const Key('nextWorkStrip'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
        child: Row(children: [
          Expanded(child: title),
          Text('Last work of the day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.textSecondary)),
        ]),
      );
    }

    final when = [_time(next.serviceStart), _time(next.serviceEnd)].where((t) => t.isNotEmpty).join(' – ');
    final km = next.km;
    final dur = durationText(next.durationMin);
    final link = onOpenMap == null ? null : mapLinkFor(next);

    final String? distanceLine;
    if (km != null) {
      distanceLine = [distanceText(km, approximate: next.approximate), if (dur.isNotEmpty) '${next.approximate ? 'about ' : ''}$dur'].join(' · ');
    } else if (!distanceReady) {
      distanceLine = null; // the server can't measure roads yet — say nothing rather than confuse
    } else {
      distanceLine = 'Distance not available — the venue location is missing';
    }

    return Container(
      key: const Key('nextWorkStrip'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Next: ', style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w600)),
                    TextSpan(text: next.customerName.isEmpty ? 'Next work' : next.customerName, style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w800)),
                    if (when.isNotEmpty) TextSpan(text: '  ·  $when', style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w500)),
                  ]),
                  style: const TextStyle(fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (distanceLine != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(km != null ? Icons.directions_car_filled_rounded : Icons.info_outline_rounded, size: 14, color: km != null ? crm.primary : crm.textSecondary),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        distanceLine,
                        key: const Key('nextWorkDistance'),
                        style: TextStyle(fontSize: 12.5, fontWeight: km != null ? FontWeight.w800 : FontWeight.w500, color: km != null ? crm.primary : crm.textSecondary),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          if (link != null)
            TextButton.icon(
              key: const Key('nextWorkMap'),
              onPressed: () => onOpenMap!(link),
              icon: const Icon(Icons.location_on_rounded, size: 16),
              label: const Text('Map'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: const Color(0xFF34A853)),
            ),
        ],
      ),
    );
  }
}
