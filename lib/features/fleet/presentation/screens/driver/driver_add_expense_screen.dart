import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_expense_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_price_controller.dart';
import 'package:nizan_crm/features/fleet/data/fuel_price.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fuel_rate_widgets.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/bill_attachment_field.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

/// Extracts the vehicle id out of a job's `vehicleId`, which the API returns
/// either as a raw id string or as a populated vehicle object.
String vehicleIdOf(FleetJob job) {
  final v = job.vehicleId;
  if (v is String) return v;
  if (v is Map) {
    return v['_id']?.toString() ?? v['id']?.toString() ?? '';
  }
  return '';
}

/// The fuel type (petrol / diesel / …) of a job's vehicle, when the API sent the vehicle populated.
String? fuelTypeOfJob(FleetJob job) {
  final v = job.vehicleId;
  if (v is Map) {
    final t = v['fuelType']?.toString() ?? '';
    return t.isEmpty ? null : t;
  }
  return null;
}

/// Name of the main (lead) artist assigned to a job, falling back to any
/// assistant, then to an empty string when no artist is assigned yet.
String mainArtistOf(FleetJob job) {
  String pick(String role) {
    for (final s in job.assignedStaff) {
      if (s['roleType'] == role) {
        final name = (s['artistName'] as String? ?? '').trim();
        if (name.isNotEmpty) return name;
      }
    }
    return '';
  }

  final lead = pick('lead');
  if (lead.isNotEmpty) return lead;
  return pick('assistant');
}

/// Human-readable label for a trip in the picker. Identified by the main
/// artist assigned to the work (not the client), falling back to the booking
/// number when no artist is assigned yet.
String _jobLabel(FleetJob job) {
  final d = job.serviceStart.toLocal();
  final date =
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  final artist = mainArtistOf(job);
  return artist.isEmpty ? '$date — ${job.bookingNumber}' : '$date — $artist';
}

// ── "Whole day" expenses ─────────────────────────────────────────────────────
// A toll, parking or meal is often for the whole day rather than one work. When
// a day has two or more works the picker also offers "whole day". The driver just
// files the expense under that day: the works are NOT shown here. Accounts sees the
// day's works (with the clients) and shares the amount equally between them.

const _wholeDayPrefix = 'day:';

String _dayKeyOf(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

String _dayLabel(String dayKey) {
  final p = dayKey.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}' : dayKey;
}

/// Local noon of 'YYYY-MM-DD' — safely inside that day whichever way the
/// server reads the time.
DateTime _noonOf(String dayKey) {
  final p = dayKey.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2], 12);
}

/// The trips grouped by (local) day, in the order given.
Map<String, List<FleetJob>> _jobsByDay(List<FleetJob> jobs) {
  final out = <String, List<FleetJob>>{};
  for (final j in jobs) {
    out.putIfAbsent(_dayKeyOf(j.serviceStart), () => []).add(j);
  }
  return out;
}

/// The vehicle's last recorded odometer reading, when the job carries it.
double? _lastKmOf(FleetJob job) {
  final v = job.vehicleId;
  if (v is Map) {
    final km = v['currentKm'];
    if (km is num && km > 0) return km.toDouble();
  }
  return null;
}

String _kmText(double km) => km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1);

/// Vehicle-related expense categories a driver can log during a trip.
const _driverCategories = <(String, String, IconData)>[
  ('fuel', 'Fuel', Icons.local_gas_station_outlined),
  ('toll', 'Toll', Icons.toll_outlined),
  ('parking', 'Parking', Icons.local_parking_outlined),
  ('food', 'Food', Icons.restaurant_outlined),
  ('service', 'Service / Repair', Icons.build_outlined),
  ('other', 'Other', Icons.receipt_long_outlined),
];

class DriverAddExpenseScreen extends HookConsumerWidget {
  /// Job the expense belongs to. Null when the driver opened the screen from
  /// the Expenses tab instead of from inside an active trip — they then pick
  /// the trip from a dropdown.
  final String? jobId;
  const DriverAddExpenseScreen({super.key, this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountCtrl = useTextEditingController();
    final litersCtrl = useTextEditingController();
    final odometerCtrl = useTextEditingController();
    final descriptionCtrl = useTextEditingController();
    // Opened from inside a trip: charge the whole day instead of just this work.
    final wholeDayFromTrip = useState(false);
    final isSaving = useState(false);
    final billImage = useState<String?>(null);
    final billMissing = useState(false);
    final category = useState('fuel');
    final asyncJobs = ref.watch(driverJobsProvider);
    final jobs = asyncJobs.value ?? const <FleetJob>[];

    // Trips the driver can book an expense against. A job with no vehicle
    // attached can't take one, so it never reaches the dropdown.
    final selectableJobs = jobs
        .where((j) => vehicleIdOf(j).isNotEmpty)
        .toList();

    final selectedJobId = useState<String?>(jobId);
    // Pre-select when there is exactly one trip to choose from.
    useEffect(() {
      if (selectedJobId.value == null && selectableJobs.length == 1) {
        selectedJobId.value = selectableJobs.first.id;
      }
      return null;
    }, [selectableJobs.length]);

    final activeJobId = selectedJobId.value;
    final byDay = _jobsByDay(selectableJobs);

    // What the picker (or the trip we were opened from) points at.
    final pickedDay = (activeJobId != null && activeJobId.startsWith(_wholeDayPrefix))
        ? activeJobId.substring(_wholeDayPrefix.length)
        : null;
    FleetJob? pickedJob;
    if (pickedDay == null) {
      for (final j in jobs) {
        if (j.id == activeJobId) {
          pickedJob = j;
          break;
        }
      }
    }
    // The day this expense falls in, and how many works that day has.
    final contextDay = pickedDay ?? (pickedJob != null ? _dayKeyOf(pickedJob.serviceStart) : null);
    final worksThatDay = contextDay == null ? 0 : (byDay[contextDay]?.length ?? 0);
    // The day the expense is for when it is a WHOLE-DAY one (picked in the list, or
    // switched on from inside a trip) — null when it belongs to a single work.
    final wholeDayKey = pickedDay ??
        (wholeDayFromTrip.value && pickedJob != null ? _dayKeyOf(pickedJob.serviceStart) : null);
    final isFuel = category.value == 'fuel';
    // For the odometer hint / sanity check.
    final lastKm = pickedJob != null
        ? _lastKmOf(pickedJob)
        : (contextDay == null
            ? null
            : byDay[contextDay]?.map(_lastKmOf).whereType<double>().fold<double?>(null, (a, b) => a == null || b > a ? b : a));

    // The vehicle this fill-up is for → its fuel → the price of the day. The amount is filled in from
    // the litres (never over what the driver typed), and the bill's rate is held against the price.
    final fuelJob = wholeDayKey != null ? byDay[wholeDayKey]?.firstOrNull : pickedJob;
    final vehicleFuel = fuelJob == null ? null : fuelTypeOfJob(fuelJob);
    final priceDay = contextDay ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final prices = ref.watch(fuelPricesProvider).value;
    final amountFill = useMemoized(AmountFillIn.new);
    final priceFuel = isFuel ? fuelPriceTypeOf(vehicleFuel) : null;
    useEffect(() {
      var active = true;
      void fill() {
        if (!active) return;
        final litres = double.tryParse(litersCtrl.text.trim()) ?? 0.0;
        amountFill.apply(
          amountCtrl,
          priceFuel != null && prices != null ? prices.suggestAmount(priceFuel, priceDay, litres) : null,
        );
      }

      litersCtrl.addListener(fill);
      // after this frame: the amount box is being built right now
      WidgetsBinding.instance.addPostFrameCallback((_) => fill());
      return () {
        active = false;
        litersCtrl.removeListener(fill);
      };
    }, [prices, priceFuel, priceDay]);

    Future<void> submitExpense() async {
      // Proof of spend is mandatory.
      if (billImage.value == null || billImage.value!.isEmpty) {
        billMissing.value = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attach the bill / screenshot first')),
        );
        return;
      }
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')),
        );
        return;
      }

      if (activeJobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select the trip this expense belongs to'),
          ),
        );
        return;
      }

      // Fuel entries feed the vehicle's mileage, so they need the litres and
      // the odometer reading.
      var liters = 0.0;
      var odometer = 0.0;
      if (isFuel) {
        liters = double.tryParse(litersCtrl.text.trim()) ?? 0.0;
        odometer = double.tryParse(odometerCtrl.text.trim()) ?? 0.0;
        if (liters <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter the litres from the fuel bill')),
          );
          return;
        }
        if (odometer <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter the odometer reading shown now')),
          );
          return;
        }
        if (lastKm != null && odometer < lastKm) {
          final keep = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Check the odometer'),
              content: Text(
                'You entered ${_kmText(odometer)} km, but the vehicle\'s last recorded '
                'reading is ${_kmText(lastKm)} km. An odometer only goes up.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Fix it'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save anyway'),
                ),
              ],
            ),
          );
          if (keep != true || !context.mounted) return;
        }
      }

      // Which vehicle, work and date this is booked under.
      FleetJob? vehicleJob;
      String? workId; // null = the whole day
      DateTime when = DateTime.now();
      if (wholeDayKey != null) {
        vehicleJob = (byDay[wholeDayKey] ?? const <FleetJob>[]).firstOrNull;
        when = _noonOf(wholeDayKey);
      } else {
        // firstWhereOrNull semantics — the job list can be stale or filtered.
        vehicleJob = pickedJob;
        workId = pickedJob?.id;
      }
      if (vehicleJob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip not found — pull to refresh and try again'),
          ),
        );
        return;
      }

      final vId = vehicleIdOf(vehicleJob);
      if (vId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle ID could not be determined')),
        );
        return;
      }

      isSaving.value = true;
      try {
        final saved = await ref
            .read(fuelExpenseServiceProvider)
            .saveFuelExpense(
              vehicleId: vId,
              bookingId: workId,
              category: category.value,
              notes: descriptionCtrl.text.trim(),
              // A UTC instant: a bare local time is read by the server as UTC, which
              // can push an evening entry on the last day of a month into the next
              // month's books.
              date: when.toUtc(),
              odometerKm: odometer,
              liters: liters,
              totalAmount: amount,
              paymentMode: 'cash',
              station: '',
              billImage: billImage.value ?? '',
            );
        ref.refreshData.fuelExpenses();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                saved.rateCheck?.isFlagged == true
                    ? rateFlagNote(saved.rateCheck!)
                    : 'Expense added successfully',
              ),
              duration: Duration(seconds: saved.rateCheck?.isFlagged == true ? 6 : 4),
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
        }
      } finally {
        isSaving.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense'), centerTitle: true),
      // Scrollable: the form grows with the trip picker and has to stay
      // usable on a short phone screen with the keyboard open.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Record an expense incurred during a trip (e.g., Toll, Fuel, Parking).',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // Trip selector — shown whenever the driver has a choice to make,
            // i.e. they came from the Expenses tab rather than an active job.
            if (jobId == null) ...[
              if (asyncJobs.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (selectableJobs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No trips assigned to you yet. An expense has to be booked '
                    'against a trip, so ask your fleet manager to assign one.',
                    style: TextStyle(fontSize: 13),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: const Key('tripPicker'),
                  initialValue: activeJobId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Trip *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  items: [
                    for (final day in byDay.entries) ...[
                      for (final j in day.value)
                        DropdownMenuItem(
                          value: j.id,
                          child: Text(
                            _jobLabel(j),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // A day with several works can take an expense for the whole day.
                      if (day.value.length >= 2)
                        DropdownMenuItem(
                          value: '$_wholeDayPrefix${day.key}',
                          child: Text(
                            '${_dayLabel(day.key)} — whole day (shared)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ],
                  onChanged: (v) => selectedJobId.value = v,
                ),
              if (!asyncJobs.isLoading && selectableJobs.isNotEmpty && worksThatDay >= 2)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    pickedDay != null
                        ? 'Filed under the whole day. Accounts will see that day\'s works and share it equally.'
                        : 'Charged to this work only. For a toll, parking or meal that was for the whole day, pick "whole day".',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            // Opened from inside a trip: the expense goes to that work, unless the
            // driver says it was for the whole day.
            if (jobId != null && worksThatDay >= 2) ...[
              SwitchListTile(
                key: const Key('wholeDaySwitch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('For the whole day'),
                subtitle: Text(
                  wholeDayFromTrip.value
                      ? 'Filed under the whole day — Accounts shares it equally.'
                      : 'Charged to this work only.',
                  style: const TextStyle(fontSize: 12),
                ),
                value: wholeDayFromTrip.value,
                onChanged: (v) => wholeDayFromTrip.value = v,
              ),
              const SizedBox(height: 8),
            ],
            // Expense category — what the money was spent on.
            DropdownButtonFormField<String>(
              key: const Key('categoryPicker'),
              initialValue: category.value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final c in _driverCategories)
                  DropdownMenuItem(
                    value: c.$1,
                    child: Row(
                      children: [
                        Icon(c.$3, size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        Text(c.$2),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) category.value = v;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 16),
            // Fuel only: the litres and odometer reading are how the vehicle's
            // real mileage is worked out.
            if (isFuel) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('litersField'),
                      controller: litersCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Litres *',
                        helperText: 'From the fuel bill',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_gas_station_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('odometerField'),
                      controller: odometerCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: InputDecoration(
                        labelText: 'Odometer *',
                        helperText: lastKm != null ? 'Last: ${_kmText(lastKm)} km' : 'Reading now, km',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.speed_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              FuelRateHint(
                vehicleFuelType: vehicleFuel,
                day: priceDay,
                liters: litersCtrl,
                amount: amountCtrl,
                fillsIn: true,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: descriptionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'e.g. highway toll, refuel at Shell, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),
            // Bill / screenshot proof — required before submitting.
            BillAttachmentField(
              value: billImage.value,
              isMissing: billMissing.value,
              onChanged: (url) {
                billImage.value = url;
                if (url != null) billMissing.value = false;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed:
                  isSaving.value || (jobId == null && selectableJobs.isEmpty)
                  ? null
                  : submitExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isSaving.value
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit Expense',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
