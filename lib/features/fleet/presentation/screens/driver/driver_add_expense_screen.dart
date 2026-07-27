import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_expense_controller.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/bill_attachment_field.dart';

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

/// Human-readable label for a trip in the picker: date + destination.
String _jobLabel(FleetJob job) {
  final d = job.serviceStart.toLocal();
  final date =
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  final who = job.customerName.trim();
  return who.isEmpty ? '$date — ${job.bookingNumber}' : '$date — $who';
}

class DriverAddExpenseScreen extends HookConsumerWidget {
  /// Job the expense belongs to. Null when the driver opened the screen from
  /// the Expenses tab instead of from inside an active trip — they then pick
  /// the trip from a dropdown.
  final String? jobId;
  const DriverAddExpenseScreen({super.key, this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountCtrl = useTextEditingController();
    final descriptionCtrl = useTextEditingController();
    final isSaving = useState(false);
    final billImage = useState<String?>(null);
    final billMissing = useState(false);
    final asyncJobs = ref.watch(driverJobsProvider);
    final jobs = asyncJobs.value ?? const <FleetJob>[];

    // Trips the driver can book an expense against. A job with no vehicle
    // attached can't take one, so it never reaches the dropdown.
    final selectableJobs =
        jobs.where((j) => vehicleIdOf(j).isNotEmpty).toList();

    final selectedJobId = useState<String?>(jobId);
    // Pre-select when there is exactly one trip to choose from.
    useEffect(() {
      if (selectedJobId.value == null && selectableJobs.length == 1) {
        selectedJobId.value = selectableJobs.first.id;
      }
      return null;
    }, [selectableJobs.length]);

    final activeJobId = selectedJobId.value;

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
          const SnackBar(content: Text('Select the trip this expense belongs to')),
        );
        return;
      }

      // firstWhereOrNull semantics — the job list can be stale or filtered.
      FleetJob? job;
      for (final j in jobs) {
        if (j.id == activeJobId) {
          job = j;
          break;
        }
      }
      if (job == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip not found — pull to refresh and try again')),
        );
        return;
      }

      final vId = vehicleIdOf(job);
      if (vId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle ID could not be determined')),
        );
        return;
      }
      
      isSaving.value = true;
      try {
        await ref.read(fuelExpenseServiceProvider).saveFuelExpense(
          vehicleId: vId,
          category: 'other',
          notes: descriptionCtrl.text.trim(),
          date: DateTime.now(),
          odometerKm: 0,
          liters: 0,
          totalAmount: amount,
          paymentMode: 'cash',
          station: '',
          billImage: billImage.value ?? '',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully')),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        centerTitle: true,
      ),
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
                  initialValue: activeJobId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Trip *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  items: [
                    for (final j in selectableJobs)
                      DropdownMenuItem(
                        value: j.id,
                        child: Text(
                          _jobLabel(j),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => selectedJobId.value = v,
                ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
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
                  : const Text('Submit Expense', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
