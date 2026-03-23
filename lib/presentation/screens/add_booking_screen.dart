import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/utils/booking_print_service.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';
import '../../services/package_service.dart';
import '../../services/region_service.dart';
import '../../core/models/service_package.dart';
import '../../core/models/service_region.dart';

class AddBookingScreen extends HookConsumerWidget {
  const AddBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncPackages = ref.watch(packagesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final packages = _uniquePackages(asyncPackages.value ?? const []);
    final regions = _uniqueRegions(asyncRegions.value ?? const []);

    final formKey = useMemoized(() => GlobalKey<FormState>());
    TextEditingController? autoCompleteNameCtrl;
    final nameCtrl = useTextEditingController();
    final emailCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();

    final selectedRegion = useState<String?>('');
    final selectedPackageId = useState<String?>(null);
    final bookingDate = useState<DateTime?>(null);
    final startTime = useState<TimeOfDay>(const TimeOfDay(hour: 9, minute: 0));
    final endTime = useState<TimeOfDay>(const TimeOfDay(hour: 10, minute: 0));
    final totalPrice = useState<double>(0);
    final advanceAmount = useState<double>(0);

    void recalculate() {
      if (packages.isEmpty) {
        totalPrice.value = 0;
        advanceAmount.value = 0;
        return;
      }

      dynamic selectedPackage;
      for (final package in packages) {
        if (package.id == selectedPackageId.value) {
          selectedPackage = package;
          break;
        }
      }
      selectedPackage ??= packages.first;

      totalPrice.value = selectedPackage.effectivePriceForRegion(
        selectedRegion.value,
      );
      advanceAmount.value = selectedPackage.advanceAmount;
    }

    final validPackageId =
        packages.any((package) => package.id == selectedPackageId.value)
        ? selectedPackageId.value
        : null;
    final validRegionId =
        selectedRegion.value == '' ||
            regions.any((region) => region.id == selectedRegion.value)
        ? selectedRegion.value
        : '';
    final packageDropdownKey = ValueKey(
      'package-${validPackageId ?? 'none'}-${packages.map((p) => p.id).join(',')}',
    );
    final regionDropdownKey = ValueKey(
      'region-${validRegionId ?? 'none'}-${regions.map((r) => r.id).join(',')}',
    );

    useEffect(() {
      if (packages.isNotEmpty &&
          (selectedPackageId.value == null ||
              selectedPackageId.value!.isEmpty ||
              !packages.any(
                (package) => package.id == selectedPackageId.value,
              ))) {
        selectedPackageId.value = packages.first.id;
      }

      if (selectedRegion.value == null ||
          (selectedRegion.value!.isNotEmpty &&
              !regions.any((region) => region.id == selectedRegion.value))) {
        selectedRegion.value = '';
      }

      recalculate();
      return null;
    }, [packages, regions, selectedPackageId.value, selectedRegion.value]);

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

    Future<void> showPrintDialog(Booking booking) async {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Booking Saved'),
          content: const Text('Choose which PDF you want to print.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('skip'),
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop('client'),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Client PDF'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop('artist'),
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('Artist PDF'),
            ),
          ],
        ),
      );

      if (action == 'client') {
        await printBookingDetails(booking, variant: BookingPrintVariant.client);
      } else if (action == 'artist') {
        await printBookingDetails(
          booking,
          variant: BookingPrintVariant.artist,
          relatedArtistBookings: const [],
        );
      }

      if (context.mounted) {
        context.go('/calendar');
      }
    }

    Future<void> submitBooking() async {
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
      dynamic selectedPackage;
      for (final package in packages) {
        if (package.id == selectedPackageId.value) {
          selectedPackage = package;
          break;
        }
      }
      if (selectedPackage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a package.')),
        );
        return;
      }

      final sStart = DateTime(
        d.year,
        d.month,
        d.day,
        startTime.value.hour,
        startTime.value.minute,
      );
      final sEnd = DateTime(
        d.year,
        d.month,
        d.day,
        endTime.value.hour,
        endTime.value.minute,
      );

      dynamic selectedRegionModel;
      for (final region in regions) {
        if (region.id == selectedRegion.value) {
          selectedRegionModel = region;
          break;
        }
      }

      final actualName =
          autoCompleteNameCtrl?.text.trim() ?? nameCtrl.text.trim();

      final booking = Booking(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        packageId: selectedPackage.id,
        regionId: selectedRegionModel?.id ?? '',
        customerName: actualName,
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        service: selectedPackage.name,
        region: selectedRegionModel?.name ?? '',
        bookingDate: d,
        serviceStart: sStart,
        serviceEnd: sEnd,
        totalPrice: totalPrice.value,
        advanceAmount: advanceAmount.value,
      );

      final savedBooking = await ref
          .read(bookingProvider.notifier)
          .addBooking(booking);

      // Invalidate the customers list so the new customer (auto-created
      // on the backend during booking) appears in the Clients Directory.
      ref.invalidate(customersProvider);

      if (context.mounted) {
        await showPrintDialog(savedBooking);
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              8.w,
              Text(
                'Create New Booking',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                        Text(
                          'Customer Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        16.h,
                        Consumer(
                          builder: (context, ref, child) {
                            final asyncCustomers = ref.watch(customersProvider);
                            final customersList = asyncCustomers.value ?? [];

                            return Autocomplete<Customer>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<Customer>.empty();
                                    }
                                    return customersList.where(
                                      (c) => c.name.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      ),
                                    );
                                  },
                              displayStringForOption: (Customer option) =>
                                  option.name,
                              onSelected: (Customer selection) {
                                phoneCtrl.text = selection.phone ?? '';
                                emailCtrl.text =
                                    selection.email.contains(
                                      '@placeholder.local',
                                    )
                                    ? ''
                                    : selection.email;
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    autoCompleteNameCtrl = controller;
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration:
                                          _inputDeco(
                                            'Full Name',
                                            crmColors,
                                          ).copyWith(
                                            suffixIcon: asyncCustomers.isLoading
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: Padding(
                                                      padding: EdgeInsets.all(
                                                        14,
                                                      ),
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Required'
                                          : null,
                                      onFieldSubmitted: (v) =>
                                          onFieldSubmitted(),
                                    );
                                  },
                            );
                          },
                        ),
                        16.h,
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: _inputDeco(
                                  'Phone Number',
                                  crmColors,
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDeco('Email', crmColors),
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (value.isEmpty) return 'Required';
                                  final emailPattern = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  );
                                  if (!emailPattern.hasMatch(value)) {
                                    return 'Enter a valid email';
                                  }
                                  if (value.toLowerCase().endsWith(
                                    '@placeholder.local',
                                  )) {
                                    return 'Enter a real client email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        32.h,
                        const Divider(),
                        16.h,
                        // ── Booking Details ───────────────────────────────
                        Text(
                          'Booking Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        16.h,
                        if (asyncPackages.isLoading || asyncRegions.isLoading)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                12.w,
                                Text(
                                  'Loading packages and regions...',
                                  style: TextStyle(
                                    color: crmColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (asyncPackages.hasError || asyncRegions.hasError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Failed to load package setup. Check backend packages and regions.',
                              style: TextStyle(color: crmColors.warning),
                            ),
                          ),
                        Row(
                          children: [
                            // Region
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: regionDropdownKey,
                                initialValue: validRegionId,
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('Default (Base Price)'),
                                  ),
                                  ...regions.map(
                                    (r) => DropdownMenuItem(
                                      value: r.id,
                                      child: Text(r.name),
                                    ),
                                  ),
                                ],
                                onChanged: regions.isEmpty
                                    ? null
                                    : (val) {
                                        selectedRegion.value = val;
                                        recalculate();
                                      },
                                decoration: _inputDeco(
                                  'Select Region',
                                  crmColors,
                                ),
                              ),
                            ),
                            16.w,
                            // Package
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: packageDropdownKey,
                                initialValue: validPackageId,
                                items: packages
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p.id,
                                        child: Text(
                                          '${p.name} (₹${p.price.toStringAsFixed(0)})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: packages.isEmpty
                                    ? null
                                    : (val) {
                                        selectedPackageId.value = val;
                                        recalculate();
                                      },
                                decoration: _inputDeco('Package', crmColors),
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
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
                                  decoration: _inputDeco(
                                    'Appointment Date',
                                    crmColors,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: crmColors.textSecondary,
                                      ),
                                      8.w,
                                      Text(
                                        bookingDate.value != null
                                            ? bookingDate.value!
                                                  .toString()
                                                  .split(' ')[0]
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
                                  decoration: _inputDeco(
                                    'Start Time',
                                    crmColors,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 16,
                                        color: crmColors.textSecondary,
                                      ),
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
                                      Icon(
                                        Icons.schedule_outlined,
                                        size: 16,
                                        color: crmColors.textSecondary,
                                      ),
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
                                value:
                                    '₹ ${totalPrice.value.toStringAsFixed(0)}',
                                border: crmColors.border,
                                valueColor: crmColors.textPrimary,
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: _summaryBox(
                                label: 'ADVANCE (FIXED)',
                                value:
                                    '₹ ${advanceAmount.value.toStringAsFixed(0)}',
                                border: crmColors.border,
                                valueColor: crmColors.accent,
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: ElevatedButton(
                                onPressed: submitBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: crmColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Create Booking',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
      floatingLabelStyle: TextStyle(
        color: crmColors.primary,
        fontWeight: FontWeight.bold,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: crmColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: crmColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: crmColors.primary, width: 2),
      ),
      filled: true,
      fillColor: crmColors.surface,
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 1.1,
            ),
          ),
          4.h,
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

List<ServicePackage> _uniquePackages(List<ServicePackage> packages) {
  final seen = <String>{};
  final unique = <ServicePackage>[];

  for (final package in packages) {
    if (package.id.isEmpty || seen.contains(package.id)) continue;
    seen.add(package.id);
    unique.add(package);
  }

  return unique;
}

List<ServiceRegion> _uniqueRegions(List<ServiceRegion> regions) {
  final seen = <String>{};
  final unique = <ServiceRegion>[];

  for (final region in regions) {
    if (region.id.isEmpty || seen.contains(region.id)) continue;
    seen.add(region.id);
    unique.add(region);
  }

  return unique;
}
