import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/services/geo_distance_service.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

/// "📍 166.6 km · 2h 57m drive from HiLITE Business Park" under a booking's
/// address / pincode. Recalculates by itself once a 6-digit pincode is in
/// (after a short pause, so typing doesn't fire lookups); "Calculate" covers
/// address-only entries. A per-km rate typed here shows a round-trip travel
/// estimate. Display only — nothing is added to the bill or saved.
class HqDistanceLine extends ConsumerStatefulWidget {
  final TextEditingController addressCtrl;
  final TextEditingController pincodeCtrl;

  const HqDistanceLine({
    super.key,
    required this.addressCtrl,
    required this.pincodeCtrl,
  });

  @override
  ConsumerState<HqDistanceLine> createState() => _HqDistanceLineState();
}

class _HqDistanceLineState extends ConsumerState<HqDistanceLine> {
  Timer? _debounce;
  bool _busy = false;
  HqDistance? _result;
  String? _error;
  String _lastQuery = '';
  int _seq = 0;
  // Per-km rate for the travel estimate (typed per booking, not saved).
  final _rateCtrl = TextEditingController();

  static final _pin = RegExp(r'^[1-9]\d{5}$');

  String get _pincode => widget.pincodeCtrl.text.replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();
    widget.pincodeCtrl.addListener(_onPincodeChanged);
    // Opened pre-filled (e.g. converting a lead) — work it out straight away.
    if (_pin.hasMatch(_pincode)) _schedule(const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.pincodeCtrl.removeListener(_onPincodeChanged);
    _rateCtrl.dispose();
    super.dispose();
  }

  void _onPincodeChanged() {
    if (_pin.hasMatch(_pincode)) _schedule(const Duration(milliseconds: 800));
  }

  void _schedule(Duration delay) {
    _debounce?.cancel();
    _debounce = Timer(delay, () => _calculate());
  }

  Future<void> _calculate({bool force = false}) async {
    final pin = _pin.hasMatch(_pincode) ? _pincode : '';
    final address = widget.addressCtrl.text.trim();
    if (pin.isEmpty && address.length < 4) {
      setState(() {
        _result = null;
        _error = 'Enter the pincode or address first.';
      });
      return;
    }
    final query = '$pin|$address';
    if (!force && query == _lastQuery && (_result != null || _busy)) return;
    _lastQuery = query;
    final mySeq = ++_seq;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(geoDistanceServiceProvider).fromHq(pincode: pin, address: address);
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _result = r;
        _busy = false;
      });
    } catch (e) {
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _result = null;
        _error = e.toString();
        _busy = false;
      });
    }
  }

  // ₹1,23,456 style grouping, no paise for whole rupees.
  static String _inr(double v) {
    final rounded = v.roundToDouble();
    final whole = rounded.toStringAsFixed(0);
    final digits = whole.replaceAll('-', '');
    String grouped;
    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final last3 = digits.substring(digits.length - 3);
      var rest = digits.substring(0, digits.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      grouped = '${parts.join(',')},$last3';
    }
    return v < 0 ? '-$grouped' : grouped;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = _result;
    final Widget body;
    if (_busy) {
      body = Row(children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('Calculating distance…', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      ]);
    } else if (r != null) {
      body = Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '${r.km.toStringAsFixed(1)} km',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' · ${r.driveTime} drive from ${r.from}'),
          TextSpan(
            text: '\nto ${r.to}${r.method == 'pincode' ? ' (pincode area)' : ''}',
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
          ),
        ]),
        style: TextStyle(fontSize: 13, color: crm.textPrimary),
      );
    } else {
      body = Text(
        _error ?? 'Distance from HQ appears here once the pincode is entered.',
        style: TextStyle(
          fontSize: 12.5,
          color: _error != null ? Colors.orange.shade800 : crm.textSecondary,
        ),
      );
    }
    // Round trip: HQ → venue → back to HQ.
    final rate = double.tryParse(_rateCtrl.text.trim());
    final roundTripKm = r == null ? null : r.km * 2;
    final estimate = (roundTripKm != null && rate != null && rate > 0)
        ? roundTripKm * rate
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.route_outlined, size: 18, color: crm.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: body),
              TextButton.icon(
                onPressed: _busy ? null : () => _calculate(force: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Calculate'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Per km charge (₹)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  roundTripKm == null
                      ? TextSpan(
                          text: 'Travel estimate shows once the distance is calculated.',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary),
                        )
                      : estimate == null
                          ? TextSpan(
                              text: 'Round trip ${roundTripKm.toStringAsFixed(1)} km — enter the per km charge.',
                              style: TextStyle(fontSize: 12, color: crm.textSecondary),
                            )
                          : TextSpan(children: [
                              TextSpan(
                                text: 'Travel estimate ₹${_inr(estimate)}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: '\n${roundTripKm.toStringAsFixed(1)} km round trip × ₹${rate! % 1 == 0 ? _inr(rate) : rate.toStringAsFixed(2)} · not added to the bill',
                                style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                              ),
                            ]),
                  style: TextStyle(fontSize: 13, color: crm.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
