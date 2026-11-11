import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_availability_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_availability.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fleet_availability_widgets.dart';

String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String _clock(DateTime? t) => t == null ? '' : DateFormat('h:mm a').format(t);

/// Opens the fleet board: a dialog on wide screens, a bottom sheet on a phone.
Future<void> showFleetBoard(BuildContext context, {DateTime? day}) {
  if (ResponsiveBuilder.isMobile(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: FleetBoardView(initialDay: day),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
        child: FleetBoardView(initialDay: day),
      ),
    ),
  );
}

/// WHO IS FREE: one day, every vehicle and driver with the works they have, anything already
/// double-booked, and the works that still need a driver or a vehicle.
class FleetBoardView extends ConsumerStatefulWidget {
  final DateTime? initialDay;
  const FleetBoardView({super.key, this.initialDay});

  @override
  ConsumerState<FleetBoardView> createState() => _FleetBoardViewState();
}

class _FleetBoardViewState extends ConsumerState<FleetBoardView> {
  late DateTime _day = widget.initialDay ?? DateTime.now();

  void _move(int days) => setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(fleetBoardProvider(_key(_day)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Who is free',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              IconButton(
                key: const Key('boardPrev'),
                tooltip: 'Previous day',
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('boardDay'),
                  onPressed: _pick,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(DateFormat('EEE, d MMM yyyy').format(_day)),
                ),
              ),
              IconButton(
                key: const Key('boardNext'),
                tooltip: 'Next day',
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(
                key: const Key('boardToday'),
                onPressed: () => setState(() => _day = DateTime.now()),
                child: const Text('Today'),
              ),
            ],
          ),
        ),
        Flexible(
          child: async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: AppErrorView(
                error: e,
                onRetry: () => ref.invalidate(fleetBoardProvider(_key(_day))),
              ),
            ),
            data: (board) => _body(context, crm, board),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, CrmTheme crm, FleetBoard board) {
    final free = board.vehicles.where((v) => v.status == 'free').length;
    final freeDrivers = board.drivers.where((d) => d.status == 'free').length;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Text(
          '$free of ${board.vehicles.length} vehicles and $freeDrivers of ${board.drivers.length} drivers free'
          '${board.needing.isEmpty ? '' : ' · ${board.needing.length} ${board.needing.length == 1 ? 'work needs' : 'works need'} a driver or vehicle'}',
          key: const Key('boardSummary'),
          style: TextStyle(
            fontSize: 12.5,
            color: crm.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (board.needing.isNotEmpty) ...[
          _heading('STILL NEED A DRIVER OR VEHICLE', crm),
          for (final n in board.needing) _needRow(crm, n),
        ],
        _heading('VEHICLES', crm),
        if (board.vehicles.isEmpty)
          _empty('No vehicles yet.', crm)
        else
          for (final v in board.vehicles)
            _resourceCard(crm, v, isVehicle: true),
        _heading('DRIVERS', crm),
        if (board.drivers.isEmpty)
          _empty('No drivers yet.', crm)
        else
          for (final d in board.drivers)
            _resourceCard(crm, d, isVehicle: false),
      ],
    );
  }

  Widget _heading(String t, CrmTheme crm) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: crm.textSecondary,
      ),
    ),
  );

  Widget _empty(String t, CrmTheme crm) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: TextStyle(color: crm.textSecondary)),
  );

  Widget _needRow(CrmTheme crm, NeedingWork n) {
    final what = n.needsDriver && n.needsVehicle
        ? 'driver and vehicle'
        : (n.needsDriver ? 'driver' : 'vehicle');
    return Container(
      key: Key('need_${n.work.bookingNumber}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: crm.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment_late_outlined, size: 18, color: crm.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${n.work.bookingNumber}  ${n.work.customerName}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text:
                        '  ·  ${_clock(n.work.start)}–${_clock(n.work.end)}  ·  needs a $what',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resourceCard(
    CrmTheme crm,
    BoardResource r, {
    required bool isVehicle,
  }) {
    final color = availabilityColor(crm, r.status);
    return Container(
      key: Key('${isVehicle ? 'vehicle' : 'driver'}_${r.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: r.isFreeAllDay ? crm.border : color.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVehicle
                    ? Icons.directions_car_outlined
                    : Icons.person_outline,
                size: 18,
                color: crm.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    r.name,
                    if (r.registrationNumber.isNotEmpty) r.registrationNumber,
                    if (r.seats > 0) '${r.seats} seats',
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              AvailabilityPill(status: r.status),
            ],
          ),
          for (final p in r.conflicts) _line(crm, Icons.block, p.text, color),
          for (final c in r.clashes)
            _line(
              crm,
              Icons.warning_amber_rounded,
              c.$1 == 'overlap'
                  ? '${c.$2.join(' and ')} are at the same time'
                  : '${c.$2.join(' and ')} are too close together to drive between',
              color,
            ),
          for (final w in r.warnings)
            _line(crm, Icons.info_outline_rounded, w.text, crm.textSecondary),
          if (r.works.isEmpty && r.conflicts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Free all day',
                style: TextStyle(
                  fontSize: 12,
                  color: crm.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            for (final w in r.works)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_clock(w.start)}–${_clock(w.end)}   ${w.bookingNumber}  ${w.customerName}',
                  style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                ),
              ),
        ],
      ),
    );
  }

  Widget _line(CrmTheme crm, IconData icon, String text, Color color) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
