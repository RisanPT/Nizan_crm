import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';

class AddBookingScreen extends HookConsumerWidget {
  const AddBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final formKey = useMemoized(() => GlobalKey<FormState>());
    final nameCtrl = useTextEditingController();
    final emailCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();

    final selectedRegion = useState<String?>('');
    final selectedPackageId = useState<String?>('1');
    final bookingDate = useState<DateTime?>(null);
    final startTime = useState<TimeOfDay>(const TimeOfDay(hour: 9, minute: 0));
    final endTime = useState<TimeOfDay>(const TimeOfDay(hour: 10, minute: 0));
    final totalPrice = useState<double>(18500.0);
    final advanceAmount = useState<double>(5000.0);

    const regions = [
      {'id': '1', 'name': 'Downtown Studio'},
      {'id': '2', 'name': 'Westside Salon'},
      {'id': '3', 'name': 'East End Branch'},
    ];

    const packages = [
      {'id': '1', 'name': 'Bridal Makeover Package',  'price': 18500.0, 'advance': 5000.0},
      {'id': '2', 'name': 'Premium Hair Styling',     'price': 8200.0,  'advance': 2000.0},
      {'id': '3', 'name': 'Luxury Spa Facial',        'price': 6500.0,  'advance': 1500.0},
    ];

    void recalculate() {
      final pkg = packages.firstWhere(
        (p) => p['id'] == selectedPackageId.value,
        orElse: () => packages.first,
      );
      totalPrice.value = pkg['price'] as double;
      advanceAmount.value = pkg['advance'] as double;
    }

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (ctx, child) => Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: crmColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        ),
      );
      if (picked != null) bookingDate.value = picked;
    }

    Future<void> pickStartTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: startTime.value,
      );
      if (picked != null) {
        startTime.value = picked;
        // Auto-adjust end time if end is now before start
        final startMinutes = picked.hour * 60 + picked.minute;
        final endMinutes = endTime.value.hour * 60 + endTime.value.minute;
        if (endMinutes <= startMinutes) {
          final newEnd = TimeOfDay(
            hour: (picked.hour + 1).clamp(0, 23),
            minute: picked.minute,
          );
          endTime.value = newEnd;
        }
      }
    }

    Future<void> pickEndTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: endTime.value,
      );
      if (picked != null) endTime.value = picked;
    }

    String fmtTime(TimeOfDay t) {
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      final m = t.minute.toString().padLeft(2, '0');
      final ampm = t.hour < 12 ? 'AM' : 'PM';
      return '$h:$m $ampm';
    }

    void submitBooking() {
      if (!formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }
      if (bookingDate.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an appointment date.')),
        );
        return;
      }

      final d = bookingDate.value!;
      final sStart = DateTime(d.year, d.month, d.day, startTime.value.hour, startTime.value.minute);
      final sEnd = DateTime(d.year, d.month, d.day, endTime.value.hour, endTime.value.minute);

      final regionName = selectedRegion.value != null && selectedRegion.value!.isNotEmpty
          ? regions.firstWhere((r) => r['id'] == selectedRegion.value)['name'] as String
          : '';

      final pkg = packages.firstWhere(
        (p) => p['id'] == selectedPackageId.value,
        orElse: () => packages.first,
      );

      final booking = Booking(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerName: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        service: pkg['name'] as String,
        region: regionName,
        bookingDate: d,
        serviceStart: sStart,
        serviceEnd: sEnd,
        totalPrice: totalPrice.value,
        advanceAmount: advanceAmount.value,
      );

      ref.read(bookingProvider.notifier).addBooking(booking);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking saved! View it on the calendar.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      context.go('/calendar');
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back)),
              8.w,
              Text('Create New Booking',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          24.h,
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: crmColors.border),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Customer Details ──────────────────────────────
                        Text('Customer Details',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        16.h,
                        TextFormField(
                          controller: nameCtrl,
                          decoration: _inputDeco('Full Name', crmColors),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        16.h,
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: _inputDeco('Phone Number', crmColors),
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDeco('Email (Optional)', crmColors),
                              ),
                            ),
                          ],
                        ),
                        32.h,
                        const Divider(),
                        16.h,
                        // ── Booking Details ───────────────────────────────
                        Text('Booking Details',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        16.h,
                        Row(
                          children: [
                            // Region
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedRegion.value,
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('Default (Base Price)')),
                                  ...regions.map((r) => DropdownMenuItem(
                                      value: r['id'] as String,
                                      child: Text(r['name'] as String))),
                                ],
                                onChanged: (val) => selectedRegion.value = val,
                                decoration: _inputDeco('Select Region', crmColors),
                              ),
                            ),
                            16.w,
                            // Package
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedPackageId.value,
                                items: packages
                                    .map((p) => DropdownMenuItem(
                                        value: p['id'] as String,
                                        child: Text('${p['name']} (₹${p['price']})')))
                                    .toList(),
                                onChanged: (val) {
                                  selectedPackageId.value = val;
                                  recalculate();
                                },
                                decoration: _inputDeco('Package', crmColors),
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        16.h,
                        // ── Date + Time row ───────────────────────────────
                        Row(
                          children: [
                            // Appointment date
                            Expanded(
                              child: InkWell(
                                onTap: pickDate,
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: _inputDeco('Appointment Date', crmColors),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 16, color: crmColors.textSecondary),
                                      8.w,
                                      Text(
                                        bookingDate.value != null
                                            ? bookingDate.value!.toString().split(' ')[0]
                                            : 'Select date…',
                                        style: TextStyle(
                                          color: bookingDate.value != null
                                              ? crmColors.textPrimary
                                              : crmColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            16.w,
                            // Start time
                            Expanded(
                              child: InkWell(
                                onTap: pickStartTime,
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: _inputDeco('Start Time', crmColors),
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule,
                                          size: 16, color: crmColors.textSecondary),
                                      8.w,
                                      Text(fmtTime(startTime.value)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            16.w,
                            // End time
                            Expanded(
                              child: InkWell(
                                onTap: pickEndTime,
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: _inputDeco('End Time', crmColors),
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule_outlined,
                                          size: 16, color: crmColors.textSecondary),
                                      8.w,
                                      Text(fmtTime(endTime.value)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        32.h,
                        // ── Totals + Submit ──────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _summaryBox(
                                label: 'TOTAL AMOUNT',
                                value: '₹ ${totalPrice.value.toStringAsFixed(0)}',
                                border: crmColors.border,
                                valueColor: crmColors.textPrimary,
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: _summaryBox(
                                label: 'ADVANCE (FIXED)',
                                value: '₹ ${advanceAmount.value.toStringAsFixed(0)}',
                                border: crmColors.border,
                                valueColor: const Color(0xFFD97706),
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: ElevatedButton(
                                onPressed: submitBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Create Booking',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          48.h,
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, CrmTheme crmColors) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: crmColors.textSecondary, fontSize: 14),
      floatingLabelStyle:
          TextStyle(color: crmColors.primary, fontWeight: FontWeight.bold),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: crmColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: crmColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: crmColors.primary, width: 2)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _summaryBox({
    required String label,
    required String value,
    required Color border,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.1)),
          4.h,
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}
