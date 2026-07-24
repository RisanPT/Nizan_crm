import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nizan_crm/features/fleet/services/fleet_service.dart';
import 'package:nizan_crm/services/fuel_expense_service.dart';
import 'package:nizan_crm/services/upload_service.dart';

class DriverAddExpenseScreen extends HookConsumerWidget {
  final String jobId;
  const DriverAddExpenseScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountCtrl = useTextEditingController();
    final descriptionCtrl = useTextEditingController();
    final isSaving = useState(false);
    final billImage = useState<String?>(null);
    final uploadingBill = useState(false);

    Future<void> attachBill() async {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final img =
          await ImagePicker().pickImage(source: source, imageQuality: 70);
      if (img == null) return;
      uploadingBill.value = true;
      try {
        final url = await ref.read(uploadServiceProvider).uploadImage(img);
        billImage.value = url;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Bill upload failed: $e')));
        }
      } finally {
        uploadingBill.value = false;
      }
    }

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
            const SizedBox(height: 16),
            // Bill / receipt upload → goes to the fleet manager.
            InkWell(
              onTap: uploadingBill.value ? null : attachBill,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: billImage.value != null
                          ? Colors.green
                          : Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (uploadingBill.value)
                      const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(
                          billImage.value != null
                              ? Icons.check_circle
                              : Icons.receipt_long_outlined,
                          color: billImage.value != null
                              ? Colors.green
                              : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        billImage.value != null
                            ? 'Bill attached — tap to change'
                            : 'Attach bill / receipt (photo)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (billImage.value != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => billImage.value = null,
                      ),
                  ],
                ),
              ),
            ),
            if (billImage.value != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(billImage.value!,
                    height: 160, fit: BoxFit.cover),
              ),
            ],
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
