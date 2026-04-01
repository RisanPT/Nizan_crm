import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
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
    final allowMissingEmail = useState(false);
    final isSubmitting = useState(false);

    final selectedRegion = useState<String?>('');
    final selectedPackageId = useState<String?>(null);
    final selectedDates = useState<List<DateTime>>([]);
    final eventSlotCtrl = useTextEditingController();
    final bookingCart = useState<List<_BookingCartEntry>>([]);
    final startTime = useState<TimeOfDay>(const TimeOfDay(hour: 9, minute: 0));
    final endTime = useState<TimeOfDay>(const TimeOfDay(hour: 10, minute: 0));
    final totalPrice = useState<double>(0);
    final advanceAmount = useState<double>(0);
    final totalPackageCount = bookingCart.value.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    ServicePackage? findPackageById(String? id) {
      for (final package in packages) {
        if (package.id == id) return package;
      }
      return null;
    }

    List<BookingItem> buildBookingItems() {
      final dates = [...selectedDates.value]..sort((a, b) => a.compareTo(b));

      return bookingCart.value
          .expand((entry) {
            final package = findPackageById(entry.packageId);
            if (package == null) return const <BookingItem>[];
            final basePrice = package.effectivePriceForRegion(
              selectedRegion.value,
            );
            return List.generate(
              entry.quantity,
              (_) => BookingItem(
                packageId: package.id,
                service: package.name,
                eventSlot: entry.eventSlot,
                selectedDates: dates,
                totalPrice: basePrice,
                advanceAmount: package.advanceAmount,
              ),
            );
          })
          .whereType<BookingItem>()
          .toList();
    }

    void recalculate() {
      final bookingItems = buildBookingItems();
      if (packages.isEmpty || bookingItems.isEmpty) {
        totalPrice.value = 0;
        advanceAmount.value = 0;
        return;
      }
      totalPrice.value = bookingItems.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      ) +
      ((selectedDates.value.length > 1 ? selectedDates.value.length - 1 : 0) *
          3000);
      advanceAmount.value = bookingItems.fold<double>(
        0,
        (sum, item) => sum + item.advanceAmount,
      );
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
    }, [
      packages,
      regions,
      bookingCart.value,
      selectedPackageId.value,
      selectedRegion.value,
      selectedDates.value,
    ]);

    void addPackageToCart() {
      final selectedPackage = findPackageById(selectedPackageId.value);
      if (selectedPackage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a package first.')),
        );
        return;
      }

      final normalizedSlot = eventSlotCtrl.text.trim();
      bookingCart.value = [
        ...bookingCart.value,
        _BookingCartEntry(
          id: '${selectedPackage.id}-${DateTime.now().microsecondsSinceEpoch}',
          packageId: selectedPackage.id,
          eventSlot: normalizedSlot,
          quantity: 1,
        ),
      ];
      eventSlotCtrl.clear();
      recalculate();
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
      if (picked != null) {
        final normalizedDate = DateTime(picked.year, picked.month, picked.day);
        final exists = selectedDates.value.any(
          (date) =>
              date.year == normalizedDate.year &&
              date.month == normalizedDate.month &&
              date.day == normalizedDate.day,
        );
        if (!exists) {
          selectedDates.value = [...selectedDates.value, normalizedDate]
            ..sort((a, b) => a.compareTo(b));
          recalculate();
        }
      }
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

    String formatDateForRoute(DateTime date) {
      final year = date.year.toString().padLeft(4, '0');
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    Future<void> submitBooking() async {
      if (isSubmitting.value) return;
      if (!formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }
      if (selectedDates.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one date.')),
        );
        return;
      }

      final sortedDates = [...selectedDates.value]..sort((a, b) => a.compareTo(b));
      final d = sortedDates.first;
      final lastDate = sortedDates.last;
      final bookingItems = buildBookingItems();
      if (bookingCart.value.isEmpty || bookingItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one package.')),
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
        lastDate.year,
        lastDate.month,
        lastDate.day,
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
        packageId: bookingItems.first.packageId,
        regionId: selectedRegionModel?.id ?? '',
        customerName: actualName,
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        legacyBooking: allowMissingEmail.value,
        service: bookingItems.map((item) => item.service).join(' + '),
        eventSlot: bookingItems
            .map((item) => item.eventSlot.trim())
            .where((item) => item.isNotEmpty)
            .join(' | '),
        region: selectedRegionModel?.name ?? '',
        bookingDate: d,
        selectedDates: sortedDates,
        serviceStart: sStart,
        serviceEnd: sEnd,
        totalPrice: totalPrice.value,
        advanceAmount: advanceAmount.value,
        bookingItems: bookingItems,
      );

      isSubmitting.value = true;
      try {
        await ref.read(bookingProvider.notifier).addBooking(booking);

        if (!context.mounted) return;

        // Invalidate the customers list so the new customer (auto-created
        // on the backend during booking) appears in the Clients Directory.
        ref.invalidate(customersProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking created and added to calendar.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        context.go('/calendar?date=${formatDateForRoute(d)}');
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        if (context.mounted) {
          isSubmitting.value = false;
        }
      }
    }

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: isSubmitting.value,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            children: [
              IconButton(
                onPressed: isSubmitting.value
                    ? null
                    : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/calendar');
                  }
                },
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
                                final isPlaceholder = selection.email.contains(
                                  '@placeholder.local',
                                );
                                emailCtrl.text = isPlaceholder
                                    ? ''
                                    : selection.email;
                                allowMissingEmail.value = isPlaceholder;
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
                                decoration: _inputDeco(
                                  allowMissingEmail.value
                                      ? 'Email (Optional for old booking)'
                                      : 'Email',
                                  crmColors,
                                ),
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (allowMissingEmail.value && value.isEmpty) {
                                    return null;
                                  }
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
                        10.h,
                        CheckboxListTile(
                          value: allowMissingEmail.value,
                          onChanged: (value) {
                            allowMissingEmail.value = value ?? false;
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('This is an old booking without email'),
                          subtitle: const Text(
                            'CRM can save legacy bookings without a real client email. Confirmation email will be skipped.',
                          ),
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
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: eventSlotCtrl,
                                decoration: _inputDeco(
                                  'Package Slot (Optional)',
                                  crmColors,
                                ),
                              ),
                            ),
                            16.w,
                            SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: isSubmitting.value
                                    ? null
                                    : addPackageToCart,
                                icon: const Icon(Icons.add_shopping_cart),
                                label: const Text('Add Package'),
                              ),
                            ),
                          ],
                        ),
                        if (bookingCart.value.isNotEmpty) ...[
                          16.h,
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: crmColors.surface,
                              border: Border.all(color: crmColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PACKAGE CART ($totalPackageCount)',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                12.h,
                                ...bookingCart.value.asMap().entries.map(
                                  (entry) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: entry.key ==
                                              bookingCart.value.length - 1
                                          ? 0
                                          : 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                findPackageById(
                                                      entry.value.packageId,
                                                    )?.name ??
                                                    'Package',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (entry.value.eventSlot
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                4.h,
                                                Text(entry.value.eventSlot),
                                              ],
                                              4.h,
                                              Text(
                                                'Qty ${entry.value.quantity}',
                                                style: TextStyle(
                                                  color: crmColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              4.h,
                                              Text(
                                                'Advance ₹${((findPackageById(entry.value.packageId)?.advanceAmount ?? 0) * entry.value.quantity).toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: crmColors.accent,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                final item = bookingCart
                                                    .value[entry.key];
                                                if (item.quantity <= 1) {
                                                  bookingCart.value = bookingCart
                                                      .value
                                                      .where(
                                                        (cartItem) =>
                                                            cartItem.id !=
                                                            item.id,
                                                      )
                                                      .toList();
                                                } else {
                                                  bookingCart.value = bookingCart
                                                      .value
                                                      .asMap()
                                                      .entries
                                                      .map(
                                                        (cartEntry) => cartEntry
                                                                    .key ==
                                                                entry.key
                                                            ? cartEntry.value
                                                                  .copyWith(
                                                                    quantity:
                                                                        cartEntry
                                                                                .value
                                                                                .quantity -
                                                                            1,
                                                                  )
                                                            : cartEntry.value,
                                                      )
                                                      .toList();
                                                }
                                                recalculate();
                                              },
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                              ),
                                            ),
                                            Text(
                                              '${entry.value.quantity}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                bookingCart.value = bookingCart
                                                    .value
                                                    .asMap()
                                                    .entries
                                                    .map(
                                                      (cartEntry) => cartEntry
                                                                  .key ==
                                                              entry.key
                                                          ? cartEntry.value
                                                                .copyWith(
                                                                  quantity:
                                                                      cartEntry
                                                                              .value
                                                                              .quantity +
                                                                          1,
                                                                )
                                                          : cartEntry.value,
                                                    )
                                                    .toList();
                                                recalculate();
                                              },
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        16.h,
                        // ── Date + Time row ───────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: isSubmitting.value ? null : pickDate,
                              borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: _inputDeco(
                                    'Booking Dates',
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
                                    Expanded(
                                      child: Text(
                                        selectedDates.value.isNotEmpty
                                            ? '${selectedDates.value.length} date${selectedDates.value.length == 1 ? '' : 's'} selected'
                                            : 'Add booking date…',
                                        style: TextStyle(
                                          color: selectedDates.value.isNotEmpty
                                              ? crmColors.textPrimary
                                              : crmColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.add_circle_outline,
                                      size: 18,
                                      color: crmColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (selectedDates.value.isNotEmpty) ...[
                              12.h,
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectedDates.value
                                    .map(
                                      (date) => Chip(
                                        label: Text(
                                          date.toString().split(' ')[0],
                                        ),
                                        onDeleted: () {
                                          selectedDates.value = selectedDates.value
                                              .where(
                                                (item) =>
                                                    item.year != date.year ||
                                                    item.month != date.month ||
                                                    item.day != date.day,
                                              )
                                              .toList();
                                          recalculate();
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            16.h,
                            Row(
                              children: [
                                // Start time
                                Expanded(
                                  child: InkWell(
                                    onTap: isSubmitting.value
                                        ? null
                                        : pickStartTime,
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
                                    onTap: isSubmitting.value
                                        ? null
                                        : pickEndTime,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InputDecorator(
                                      decoration: _inputDeco(
                                        'End Time',
                                        crmColors,
                                      ),
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
                                label: 'ADVANCE TO CONFIRM',
                                value:
                                    '₹ ${advanceAmount.value.toStringAsFixed(0)}',
                                border: crmColors.border,
                                valueColor: crmColors.accent,
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSubmitting.value
                                    ? null
                                    : submitBooking,
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
                                child: isSubmitting.value
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
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
          ),
        ),
        if (isSubmitting.value)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Saving booking...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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

class _BookingCartEntry {
  final String id;
  final String packageId;
  final String eventSlot;
  final int quantity;

  const _BookingCartEntry({
    required this.id,
    required this.packageId,
    this.eventSlot = '',
    this.quantity = 1,
  });

  _BookingCartEntry copyWith({
    String? id,
    String? packageId,
    String? eventSlot,
    int? quantity,
  }) {
    return _BookingCartEntry(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      eventSlot: eventSlot ?? this.eventSlot,
      quantity: quantity ?? this.quantity,
    );
  }
}
