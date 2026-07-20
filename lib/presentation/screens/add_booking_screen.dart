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
import '../../services/district_service.dart';
import '../../core/models/service_package.dart';
import '../../core/models/district.dart';

const double kExtraDateChargePerPackage = 3000;

class AddBookingScreen extends HookConsumerWidget {
  const AddBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncPackages = ref.watch(packagesProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final packages = _uniquePackages(asyncPackages.value ?? const []);
    final districts = _uniqueDistricts(asyncDistricts.value ?? const []);

    final formKey = useMemoized(() => GlobalKey<FormState>());
    TextEditingController? autoCompleteNameCtrl;
    final nameCtrl = useTextEditingController();
    final emailCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final addressCtrl = useTextEditingController();
    final pincodeCtrl = useTextEditingController();
    final allowMissingEmail = useState(false);
    final isSubmitting = useState(false);

    final selectedDistrictId = useState<String?>('');
    final selectedPackageId = useState<String?>(null);
    final selectedDates = useState<List<DateTime>>([]);
    final eventSlotCtrl = useTextEditingController();
    final customPackageNameCtrl = useTextEditingController();
    final customPackageAmountCtrl = useTextEditingController();
    final bookingCart = useState<List<_BookingCartEntry>>([]);
    // 'single' → one package (may span multiple days); 'multiple' → several
    // packages/days, all saved as ONE invoice with a calendar entry each.
    final initialMode =
        GoRouterState.of(context).uri.queryParameters['mode'] == 'single'
            ? 'single'
            : 'multiple';
    final bookingMode = useState<String>(initialMode);
    final isSingleMode = bookingMode.value == 'single';
    final startTime = useState<TimeOfDay>(const TimeOfDay(hour: 9, minute: 0));
    final endTime = useState<TimeOfDay>(const TimeOfDay(hour: 10, minute: 0));
    final totalPrice = useState<double>(0);
    final advanceAmount = useState<double>(0);
    final basePackageAmount = useState<double>(0);
    final extraDateCharge = useState<double>(0);
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

    District? findDistrictById(String? id) {
      for (final district in districts) {
        if (district.id == id) return district;
      }
      return null;
    }

    List<BookingItem> buildBookingItems() {
      final allDates = [...selectedDates.value]..sort((a, b) => a.compareTo(b));

      // Each cart entry runs on its OWN date, so every date becomes its own
      // booking item (and therefore its own calendar slot) while the whole set
      // stays a single booking / single invoice.
      return bookingCart.value
          .expand((entry) {
            final entryDates = entry.date != null
                ? <DateTime>[entry.date!]
                : allDates;
            if (entry.packageId.isEmpty) {
              return List.generate(
                entry.quantity,
                (_) => BookingItem(
                  packageId: '',
                  service: entry.packageName,
                  eventSlot: entry.eventSlot,
                  selectedDates: entryDates,
                  totalPrice: entry.customAmount,
                  advanceAmount: entry.advanceAmount,
                ),
              );
            }
            final package = findPackageById(entry.packageId);
            if (package == null) return const <BookingItem>[];
            final basePrice = package.effectivePriceForDistrict(
              selectedDistrictId.value,
            );
            return List.generate(
              entry.quantity,
              (_) => BookingItem(
                packageId: package.id,
                service: package.name,
                eventSlot: entry.eventSlot,
                selectedDates: entryDates,
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
        basePackageAmount.value = 0;
        extraDateCharge.value = 0;
        totalPrice.value = 0;
        advanceAmount.value = 0;
        return;
      }
      // Mirrors the backend exactly: every date carries its own package, so the
      // base is the sum of each date's package price. The flat extra-date fee
      // now only applies to a package that genuinely spans more than one day.
      basePackageAmount.value = bookingItems.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      );
      // ₹3000 is charged for EVERY booking day (not only extra days), so one
      // date of Platinum = 21500 + 3000 = 24500 and two dates = 49000.
      extraDateCharge.value = bookingItems.fold<double>(
        0,
        (sum, item) => sum + (_itemDayCount(item) * kExtraDateChargePerPackage),
      );
      totalPrice.value = basePackageAmount.value + extraDateCharge.value;
      // ₹3000 advance per package, counted once per day it runs.
      advanceAmount.value = bookingItems.fold<double>(
        0,
        (sum, item) => sum + (item.advanceAmount * _itemDayCount(item)),
      );
    }

    final validPackageId =
        selectedPackageId.value == '' ||
            packages.any((package) => package.id == selectedPackageId.value)
        ? selectedPackageId.value
        : null;
    final validDistrictId =
        selectedDistrictId.value == '' ||
            districts.any((district) => district.id == selectedDistrictId.value)
        ? selectedDistrictId.value
        : '';
    final packageDropdownKey = ValueKey(
      'package-${validPackageId ?? 'none'}-${packages.map((p) => p.id).join(',')}',
    );
    final districtDropdownKey = ValueKey(
      'district-${validDistrictId ?? 'none'}-${districts.map((d) => d.id).join(',')}',
    );

    useEffect(() {
      if (packages.isNotEmpty &&
          (selectedPackageId.value == null ||
              (selectedPackageId.value!.isNotEmpty &&
                  !packages.any(
                    (package) => package.id == selectedPackageId.value,
                  )))) {
        selectedPackageId.value = packages.first.id;
      }

      if (selectedDistrictId.value == null ||
          (selectedDistrictId.value!.isNotEmpty &&
              !districts.any((district) => district.id == selectedDistrictId.value))) {
        selectedDistrictId.value = '';
      }

      recalculate();
      return null;
    }, [
      packages,
      districts,
      bookingCart.value,
      selectedPackageId.value,
      selectedDistrictId.value,
      selectedDates.value,
    ]);

    // Single mode: mirror the selected real package into a single cart entry so
    // the total computes live and no "Add package" click is required. Custom
    // packages in single mode still use the "Set Package" button.
    useEffect(() {
      if (isSingleMode) {
        final pid = selectedPackageId.value;
        if (pid != null && pid.isNotEmpty) {
          // One row per date so each day is its own calendar slot, all running
          // the same package (that's what "single" means). With no dates there
          // are no packages yet — a package must always belong to a date.
          bookingCart.value = [
            for (final d in selectedDates.value)
              _BookingCartEntry(
                id: 'single-$pid-${_dateKey(d)}',
                packageId: pid,
                eventSlot: eventSlotCtrl.text.trim(),
                quantity: 1,
                date: d,
              ),
          ];
          recalculate();
        }
      }
      return null;
    }, [bookingMode.value, selectedPackageId.value, selectedDates.value]);

    void addPackageToCart() {
      final isCustomPackage = selectedPackageId.value == '';
      if (isCustomPackage) {
        final customName = customPackageNameCtrl.text.trim();
        final customAmount =
            double.tryParse(customPackageAmountCtrl.text.trim()) ?? 0;
        if (customName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a custom package name.')),
          );
          return;
        }
        if (customAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid custom package amount.')),
          );
          return;
        }

        if (selectedDates.value.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add a booking date first, then choose its package.'),
            ),
          );
          return;
        }

        final normalizedSlot = eventSlotCtrl.text.trim();
        final stamp = DateTime.now().microsecondsSinceEpoch;
        bookingCart.value = [
          // Single mode keeps exactly one package, so replace instead of add.
          if (!isSingleMode) ...bookingCart.value,
          // A custom package covers every selected date, one row each.
          for (final d in selectedDates.value)
            _BookingCartEntry(
              id: 'custom-$stamp-${_dateKey(d)}',
              packageId: '',
              packageName: customName,
              customAmount: customAmount,
              eventSlot: normalizedSlot,
              quantity: 1,
              date: d,
            ),
        ];
        eventSlotCtrl.clear();
        customPackageNameCtrl.clear();
        customPackageAmountCtrl.clear();
        recalculate();
        return;
      }

      final selectedPackage = findPackageById(selectedPackageId.value);
      if (selectedPackage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a package first.')),
        );
        return;
      }

      final normalizedSlot = eventSlotCtrl.text.trim();
      bookingCart.value = [
        // Single mode keeps exactly one package, so replace instead of add.
        if (!isSingleMode) ...bookingCart.value,
        _BookingCartEntry(
          id: '${selectedPackage.id}-${DateTime.now().microsecondsSinceEpoch}',
          packageId: selectedPackage.id,
          eventSlot: normalizedSlot,
          quantity: 1,
          date: selectedDates.value.isNotEmpty
              ? selectedDates.value.first
              : null,
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
          // Multiple mode: every new date gets its own package row, pre-filled
          // with the currently selected package. The user can then change that
          // day's package independently. (Single mode is handled by useEffect.)
          final pid = selectedPackageId.value;
          if (!isSingleMode && pid != null && pid.isNotEmpty) {
            bookingCart.value = [
              ...bookingCart.value,
              _BookingCartEntry(
                id: 'date-${_dateKey(normalizedDate)}-$pid-${DateTime.now().microsecondsSinceEpoch}',
                packageId: pid,
                eventSlot: eventSlotCtrl.text.trim(),
                quantity: 1,
                date: normalizedDate,
              ),
            ];
          }
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

      // Single mode: refresh the slot on each per-date row so a slot typed
      // after the package/dates were chosen is captured. This must PRESERVE
      // every row's date — rebuilding one dateless row would collapse a
      // multi-day booking into a single item and undercharge it.
      if (isSingleMode && bookingCart.value.isNotEmpty) {
        final slot = eventSlotCtrl.text.trim();
        bookingCart.value = [
          for (final entry in bookingCart.value) entry.copyWith(eventSlot: slot),
        ];
      }

      // Guard against a selected date having no package (e.g. a custom package
      // was only added to the first date) — otherwise that day is silently
      // booked with nothing.
      final orphanDates = selectedDates.value
          .where((d) => !bookingCart.value.any(
                (e) => e.date == null || _dateKey(e.date!) == _dateKey(d),
              ))
          .toList();
      if (orphanDates.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Add a package for ${_formatDayLabel(orphanDates.first)}.',
            ),
          ),
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

      final selectedDistrictModel = findDistrictById(selectedDistrictId.value);
      final actualName =
          autoCompleteNameCtrl?.text.trim() ?? nameCtrl.text.trim();

      // Booking-level summaries derived from every package (mirrors backend).
      final aggregatedService = <String>{
        for (final it in bookingItems)
          if (it.service.trim().isNotEmpty) it.service.trim(),
      }.join(' + ');
      final aggregatedSlot = <String>{
        for (final it in bookingItems)
          if (it.eventSlot.trim().isNotEmpty) it.eventSlot.trim(),
      }.join(' | ');

      isSubmitting.value = true;
      try {
        // ONE booking carries every package/day as bookingItems → a single
        // invoice. Booking.displayEntries then expands it into one calendar
        // entry per package × date, each showing that item's own amount.
        final booking = Booking(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          packageId: bookingItems.first.packageId,
          regionId: selectedDistrictModel?.regionId ?? '',
          districtId: selectedDistrictModel?.id ?? '',
          customerName: actualName,
          phone: phoneCtrl.text.trim(),
          address: addressCtrl.text.trim(),
          pincode: pincodeCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          legacyBooking: allowMissingEmail.value,
          service: aggregatedService.isEmpty
              ? bookingItems.first.service
              : aggregatedService,
          eventSlot: aggregatedSlot,
          region: selectedDistrictModel?.regionName ?? '',
          district: selectedDistrictModel?.name ?? '',
          bookingDate: d,
          selectedDates: sortedDates,
          serviceStart: sStart,
          serviceEnd: sEnd,
          totalPrice: totalPrice.value,
          advanceAmount: advanceAmount.value,
          bookingItems: bookingItems,
        );
        await ref.read(bookingProvider.notifier).addBooking(booking);

        if (!context.mounted) return;

        // Invalidate the customers list so the new customer (auto-created
        // on the backend during booking) appears in the Clients Directory.
        ref.invalidate(customersProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bookingItems.length > 1
                  ? 'Booking created with ${bookingItems.length} packages — one invoice.'
                  : 'Booking created and added to calendar.',
            ),
            backgroundColor: const Color(0xFF10B981),
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

    final selectedDistrictModel = findDistrictById(selectedDistrictId.value);

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
                              // ── Booking mode (Single vs Multiple) ────────────
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'single',
                                    icon: Icon(Icons.event_available_outlined),
                                    label: Text('Single'),
                                  ),
                                  ButtonSegment(
                                    value: 'multiple',
                                    icon:
                                        Icon(Icons.dashboard_customize_outlined),
                                    label: Text('Multiple'),
                                  ),
                                ],
                                selected: {bookingMode.value},
                                onSelectionChanged: (s) {
                                  bookingMode.value = s.first;
                                  recalculate();
                                },
                              ),
                              10.h,
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: crmColors.primary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: crmColors.primary
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                        isSingleMode
                                            ? Icons.event_available_outlined
                                            : Icons.dashboard_customize_outlined,
                                        size: 18,
                                        color: crmColors.primary),
                                    10.w,
                                    Expanded(
                                      child: Text(
                                        isSingleMode
                                            ? 'Single booking — one package for this client. Pick more than one date for a multi-day event; it stays one invoice.'
                                            : 'Multiple booking — add several packages and/or days. All are saved as ONE invoice, and each package/day shows as its own calendar entry.',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.3,
                                            color: crmColors.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              24.h,
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
                                      addressCtrl.text = selection.address ?? '';
                                      pincodeCtrl.text = selection.pincode ?? '';
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
                              16.h,
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: addressCtrl,
                                      decoration: _inputDeco(
                                        'Address',
                                        crmColors,
                                      ),
                                      validator: (v) => (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                  16.w,
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      controller: pincodeCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDeco(
                                        'Pincode',
                                        crmColors,
                                      ),
                                      validator: (v) => (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
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
                              if (asyncPackages.isLoading || asyncDistricts.isLoading)
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
                                        'Loading packages and districts...',
                                        style: TextStyle(
                                          color: crmColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (asyncPackages.hasError || asyncDistricts.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    'Failed to load package setup. Check backend packages and districts.',
                                    style: TextStyle(color: crmColors.warning),
                                  ),
                                ),
                              Row(
                                children: [
                                  // District
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        DropdownButtonFormField<String>(
                                          key: districtDropdownKey,
                                          initialValue: validDistrictId,
                                          items: [
                                            const DropdownMenuItem(
                                              value: '',
                                              child: Text('Default (Base Price)'),
                                            ),
                                            ...districts.map(
                                              (d) => DropdownMenuItem(
                                                value: d.id,
                                                child: Text('${d.name} (${d.regionName})'),
                                              ),
                                            ),
                                          ],
                                          onChanged: districts.isEmpty
                                              ? null
                                              : (val) {
                                                  selectedDistrictId.value = val;
                                                  recalculate();
                                                },
                                          decoration: _inputDeco(
                                            'Select District',
                                            crmColors,
                                          ),
                                        ),
                                        if (selectedDistrictModel != null) ...[
                                          6.h,
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              'Region: ${selectedDistrictModel.regionName}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: crmColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Multiple mode picks the package on each date
                                  // row instead, so only the date selection is
                                  // needed here.
                                  if (isSingleMode) ...[
                                    16.w,
                                    // Package
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        key: packageDropdownKey,
                                        initialValue: validPackageId,
                                        items: [
                                          const DropdownMenuItem(
                                            value: '',
                                            child: Text('Custom Package'),
                                          ),
                                          ...packages.map(
                                            (p) => DropdownMenuItem(
                                              value: p.id,
                                              child: Text(
                                                // Price actually charged for the
                                                // selected district, so this
                                                // matches the per-date rows.
                                                '${p.name} (₹${p.effectivePriceForDistrict(selectedDistrictId.value).toStringAsFixed(0)})',
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: packages.isEmpty
                                            ? null
                                            : (val) {
                                                selectedPackageId.value = val;
                                                recalculate();
                                              },
                                        decoration:
                                            _inputDeco('Package', crmColors),
                                        validator: (v) =>
                                            v == null ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (isSingleMode && selectedPackageId.value == '') ...[
                                16.h,
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: customPackageNameCtrl,
                                        decoration: _inputDeco(
                                          'Custom Package Name',
                                          crmColors,
                                        ),
                                      ),
                                    ),
                                    16.w,
                                    Expanded(
                                      child: TextFormField(
                                        controller: customPackageAmountCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: _inputDeco(
                                          'Custom Package Amount',
                                          crmColors,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                                  // Package rows are driven by the dates you
                                  // pick, so no manual "add to cart" step is
                                  // needed. The button is only for entering a
                                  // custom (non-catalogue) package.
                                  if (isSingleMode && selectedPackageId.value == '') ...[
                                    16.w,
                                    SizedBox(
                                      height: 56,
                                      child: ElevatedButton.icon(
                                        onPressed: isSubmitting.value
                                            ? null
                                            : addPackageToCart,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Custom Package'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              // ── Booking dates (these drive the package rows) ──
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
                                  4.h,
                                  Text(
                                    'Tip: each date you add gets its own package row below — pick a different package per day if the client needs one. Every day becomes its own calendar slot under this one booking.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: crmColors.textSecondary,
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
                                                // Drop the package rows that
                                                // belonged to this date.
                                                bookingCart.value = bookingCart
                                                    .value
                                                    .where((e) =>
                                                        e.date == null ||
                                                        _dateKey(e.date!) !=
                                                            _dateKey(date))
                                                    .toList();
                                                recalculate();
                                              },
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                              // Nothing to price until a date exists — packages
                              // are always attached to a date.
                              if (bookingCart.value.isEmpty) ...[
                                16.h,
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: crmColors.surface,
                                    border: Border.all(color: crmColors.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.event_outlined,
                                          size: 18,
                                          color: crmColors.textSecondary),
                                      10.w,
                                      Expanded(
                                        child: Text(
                                          selectedDates.value.isEmpty
                                              ? 'Add a booking date above — each date you add appears here with its own package to choose.'
                                              : 'Choose a package for each date above.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: crmColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                                        isSingleMode
                                            ? 'PACKAGE IN THIS BOOKING'
                                            : 'PACKAGES IN THIS BOOKING ($totalPackageCount)',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      2.h,
                                      Text(
                                        isSingleMode
                                            ? 'One row per date, all running the same package. Saved as ONE booking (one invoice), with a calendar slot per date.'
                                            : 'Each date has its own package — change any day below. All saved as ONE booking (one invoice), with a calendar slot per date.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: crmColors.textSecondary,
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
                                                    if (entry.value.date !=
                                                        null) ...[
                                                      Text(
                                                        _formatDayLabel(
                                                            entry.value.date!),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          letterSpacing: 0.6,
                                                          color: crmColors
                                                              .primary,
                                                        ),
                                                      ),
                                                      4.h,
                                                    ],
                                                    if (entry.value.packageId
                                                        .isEmpty)
                                                      Text(
                                                        entry.value.packageName,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      )
                                                    else
                                                      // Choose THIS day's package.
                                                      // Disabled in single mode,
                                                      // where every day shares
                                                      // the one chosen package.
                                                      SizedBox(
                                                        width: 280,
                                                        child:
                                                            DropdownButtonFormField<
                                                                String>(
                                                          initialValue: entry
                                                              .value.packageId,
                                                          isExpanded: true,
                                                          isDense: true,
                                                          decoration:
                                                              const InputDecoration(
                                                            isDense: true,
                                                            border:
                                                                OutlineInputBorder(),
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 10,
                                                              vertical: 8,
                                                            ),
                                                          ),
                                                          items: [
                                                            for (final p
                                                                in packages)
                                                              DropdownMenuItem(
                                                                value: p.id,
                                                                child: Text(
                                                                  '${p.name} (₹${p.effectivePriceForDistrict(selectedDistrictId.value).toStringAsFixed(0)})',
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                          ],
                                                          onChanged: isSingleMode
                                                              ? null
                                                              : (val) {
                                                                  if (val ==
                                                                      null) {
                                                                    return;
                                                                  }
                                                                  final list = [
                                                                    ...bookingCart
                                                                        .value
                                                                  ];
                                                                  list[entry
                                                                          .key] =
                                                                      list[entry
                                                                              .key]
                                                                          .copyWith(
                                                                    packageId:
                                                                        val,
                                                                  );
                                                                  bookingCart
                                                                          .value =
                                                                      list;
                                                                  recalculate();
                                                                },
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
                                                      'Advance ₹${(((entry.value.packageId.isEmpty ? entry.value.advanceAmount : (findPackageById(entry.value.packageId)?.advanceAmount ?? 0)) * entry.value.quantity)).toStringAsFixed(0)}',
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
                              // ── Time row ─────────────────────────────────────
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                      label: 'BASE PACKAGE AMOUNT',
                                      value:
                                          '₹ ${basePackageAmount.value.toStringAsFixed(0)}',
                                      border: crmColors.border,
                                      valueColor: crmColors.textPrimary,
                                    ),
                                  ),
                                  16.w,
                                  Expanded(
                                    child: _summaryBox(
                                      label: 'DATE CHARGE (₹3000/DAY)',
                                      value:
                                          '₹ ${extraDateCharge.value.toStringAsFixed(0)}',
                                      border: crmColors.border,
                                      valueColor: crmColors.warning,
                                    ),
                                  ),
                                  16.w,
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

List<District> _uniqueDistricts(List<District> districts) {
  final seen = <String>{};
  final unique = <District>[];

  for (final district in districts) {
    if (district.id.isEmpty || seen.contains(district.id)) continue;
    seen.add(district.id);
    unique.add(district);
  }

  return unique;
}

class _BookingCartEntry {
  final String id;
  final String packageId;
  final String packageName;
  final double customAmount;
  final double advanceAmount;
  final String eventSlot;
  final int quantity;

  /// The single date this package runs on. Every selected booking date gets
  /// its own entry, so a client can take a different package per day while
  /// everything still bills as ONE invoice.
  final DateTime? date;

  const _BookingCartEntry({
    required this.id,
    required this.packageId,
    this.packageName = '',
    this.customAmount = 0,
    this.advanceAmount = 0,
    this.eventSlot = '',
    this.quantity = 1,
    this.date,
  });

  _BookingCartEntry copyWith({
    String? id,
    String? packageId,
    String? packageName,
    double? customAmount,
    double? advanceAmount,
    String? eventSlot,
    int? quantity,
    DateTime? date,
  }) {
    return _BookingCartEntry(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      customAmount: customAmount ?? this.customAmount,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      eventSlot: eventSlot ?? this.eventSlot,
      quantity: quantity ?? this.quantity,
      date: date ?? this.date,
    );
  }
}

String _formatDayLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

int _itemDayCount(BookingItem item) =>
    item.selectedDates.isEmpty ? 1 : item.selectedDates.length;

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
