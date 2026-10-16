import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/services/geo_distance_service.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

/// Under a booking's "Map URL / Coordinates" field: works out the road
/// distance + drive time from HQ (HiLITE Business Park) for the pasted link
/// and fills the Travel Distance / Travel Time fields.
///   • Runs a second after the user pastes / types a link ([userEdits] ticks
///     only on user edits — the screen loading a saved booking never triggers
///     it, so saved distances aren't overwritten).
///   • "Calculate" re-runs it on demand.
///   • One way / Round trip decides what goes in the fields (×2 for round trip).
class MapLinkDistanceHelper extends ConsumerStatefulWidget {
  final TextEditingController mapUrlCtrl;
  final TextEditingController distanceCtrl;
  final TextEditingController timeCtrl;
  final ValueNotifier<int> userEdits;

  const MapLinkDistanceHelper({
    super.key,
    required this.mapUrlCtrl,
    required this.distanceCtrl,
    required this.timeCtrl,
    required this.userEdits,
  });

  @override
  ConsumerState<MapLinkDistanceHelper> createState() => _MapLinkDistanceHelperState();
}

class _MapLinkDistanceHelperState extends ConsumerState<MapLinkDistanceHelper> {
  Timer? _debounce;
  bool _busy = false;
  bool _roundTrip = false;
  HqDistance? _oneWay; // last result, one way
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    widget.userEdits.addListener(_onUserEdit);
  }

  @override
  void didUpdateWidget(covariant MapLinkDistanceHelper old) {
    super.didUpdateWidget(old);
    if (old.userEdits != widget.userEdits) {
      old.userEdits.removeListener(_onUserEdit);
      widget.userEdits.addListener(_onUserEdit);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.userEdits.removeListener(_onUserEdit);
    super.dispose();
  }

  void _onUserEdit() {
    _debounce?.cancel();
    if (widget.mapUrlCtrl.text.trim().isEmpty) return;
    // "The next second after paste".
    _debounce = Timer(const Duration(seconds: 1), _calculate);
  }

  Future<void> _calculate() async {
    final link = widget.mapUrlCtrl.text.trim();
    if (link.isEmpty) {
      setState(() => _error = 'Paste a Google Maps link or coordinates first.');
      return;
    }
    final mySeq = ++_seq;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(geoDistanceServiceProvider).fromMapLink(link);
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _oneWay = r;
        _busy = false;
      });
      _fill();
    } catch (e) {
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  void _fill() {
    final r = _oneWay;
    if (r == null) return;
    final mult = _roundTrip ? 2 : 1;
    final km = r.km * mult;
    final mins = r.durationMin * mult;
    widget.distanceCtrl.text = km.toStringAsFixed(km >= 100 ? 0 : 1);
    final h = mins ~/ 60, m = mins % 60;
    widget.timeCtrl.text = h == 0 ? '$m min' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = _oneWay;
    final Widget status;
    if (_busy) {
      status = Row(children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('Calculating distance from the map link…', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      ]);
    } else if (_error != null) {
      status = Text(_error!, style: TextStyle(fontSize: 12.5, color: Colors.orange.shade800));
    } else if (r != null) {
      status = Text.rich(
        TextSpan(children: [
          TextSpan(text: '${r.km.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: ' one way · ${r.driveTime} from ${r.from}'),
          TextSpan(
            text: '\nFilled Travel Distance / Time as ${_roundTrip ? 'round trip (×2)' : 'one way'} — edit if needed.',
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
          ),
        ]),
        style: TextStyle(fontSize: 13, color: crm.textPrimary),
      );
    } else {
      status = Text(
        'Paste a Google Maps link above — distance & travel time fill in automatically.',
        style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 18, color: crm.textSecondary),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: status),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('One way')),
              ButtonSegment(value: true, label: Text('Round trip')),
            ],
            selected: {_roundTrip},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (v) {
              setState(() => _roundTrip = v.first);
              _fill(); // re-fill from the last result; no new lookup needed
            },
          ),
          TextButton.icon(
            onPressed: _busy ? null : _calculate,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Calculate'),
          ),
        ],
      ),
    );
  }
}
