import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../services/fleet_service.dart';
import '../../../services/fuel_expense_service.dart';

class DriverAddExpenseScreen extends HookConsumerWidget {
  final String jobId;
  const DriverAddExpenseScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountCtrl = useTextEditingController();
    final descriptionCtrl = useTextEditingController();
    final isSaving = useState(false);

    Future<void> submitExpense() async {
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')),
        );
        return;
      }

      final asyncJobs = ref.read(driverJobsProvider);
      final job = asyncJobs.value?.firstWhere(
        (j) => j.id == jobId,
      );
      
      if (job?.vehicleId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle not found for this job')),
        );
        return;
      }

      String vId = '';
      if (job!.vehicleId is String) {
        vId = job.vehicleId as String;
      } else if (job.vehicleId is Map) {
        vId = job.vehicleId['_id']?.toString() ?? job.vehicleId['id']?.toString() ?? '';
      }

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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Record an expense incurred during this trip (e.g., Toll, Fuel, Parking).',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: isSaving.value ? null : submitExpense,
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
