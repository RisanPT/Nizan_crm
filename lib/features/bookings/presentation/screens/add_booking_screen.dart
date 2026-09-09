import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/utils/phone_utils.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/models/customer.dart';
import 'package:nizan_crm/services/customer_service.dart';
import 'package:nizan_crm/services/package_service.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/addon_service_service.dart';
import 'package:nizan_crm/core/models/addon_service.dart';
import 'package:nizan_crm/core/models/service_package.dart';
import 'package:nizan_crm/core/models/district.dart';
import 'package:nizan_crm/core/error/errors.dart';

class AddBookingScreen extends HookConsumerWidget {
  const AddBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncPackages = ref.watch(packagesProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final asyncAddonServices = ref.watch(addonServicesProvider);
    final packages = _uniquePackages(asyncPackages.value ?? const []);
    final districts = _uniqueDistricts(asyncDistricts.value ?? const []);
    final availableAddonServices =
        (asyncAddonServices.value ?? const <AddonService>[])
            .where((s) => s.status.toLowerCase() == 'active')
            .toList();

    final formKey = useMemoized(() => GlobalKey<FormState>());
    TextEditingController? autoCompleteNameCtrl;
    final qParams = GoRouterState.of(context).uri.queryParameters;
    // Prefill from query params — used by the Lead → Booking conversion so the
    // salesperson only has to pick the package + dates (see lead_conversion.dart).
    final nameCtrl = useTextEditingController(text: qParams['name'] ?? '');
    final emailCtrl = useTextEditingController(text: qParams['email'] ?? '');
    final phoneCtrl = useTextEditingController(text: qParams['phone'] ?? '');
    final addressCtrl = useTextEditingController(text: qParams['address'] ?? '');
    final pincodeCtrl = useTextEditingController(text: qParams['pincode'] ?? '');
    final allowMissingEmail = useState(false);
    final isSubmitting = useState(false);

    final selectedDistrictId = useState<String?>('');
    final selectedPackageId = useState<String?>(null);
    final selectedDates = useState<List<DateTime>>([]);
    // The date the booking was actually made/entered (defaults to today). For a
    // forgotten booking entered late, set this to the real past date — it drives
    // the record's createdAt so sales/reports count it in the right period.
    final bookedDate = useState<DateTime>(DateTime.now());
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
    // Optional add-ons (single or multiple). Each row = one add-on service ×
    // persons. The backend re-sums the grand total as Σ packages + Σ add-ons,
    // so add-ons are extra on top of the package base, not a substitute.
    final addons = useState<List<BookingAddon>>([]);
    // Discount entered directly on the booking form. `discountType` is 'inr'
    // (a flat amount) or 'percent' (a % of the total). `discountValue` is the
    // raw number the user typed; the resolved rupee amount is computed below.
    final discountType = useState<String>('inr');
    final discountCtrl = useTextEditingController();
    final discountValue = useState<double>(0);
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
            // This package's OWN district (falls back to the booking-level
            // district), used both for its district-based price and to store
            // the per-item district so a multi-district booking prices each
            // package correctly.
            final entryDistrictId = entry.districtId.isNotEmpty
                ? entry.districtId
                : (selectedDistrictId.value ?? '');
            final entryRegionId =
                findDistrictById(entryDistrictId)?.regionId ?? '';
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
                  districtId: entryDistrictId,
                  regionId: entryRegionId,
                  addons: entry.addons,
                ),
              );
            }
            final package = findPackageById(entry.packageId);
            if (package == null) return const <BookingItem>[];
            final basePrice =
                package.effectivePriceForDistrict(entryDistrictId);
            return List.generate(
              entry.quantity,
              (_) => BookingItem(
                packageId: package.id,
                service: package.name,
                eventSlot: entry.eventSlot,
                selectedDates: entryDates,
                totalPrice: basePrice,
                advanceAmount: package.advanceAmount,
                districtId: entryDistrictId,
                regionId: entryRegionId,
                addons: entry.addons,
              ),
            );
          })
          .whereType<BookingItem>()
          .toList();
    }

    double addonsTotalOf(List<BookingAddon> items) => items.fold<double>(
          0,
          (sum, a) => sum + (a.amount * a.persons),
        );

    void recalculate() {
      final bookingItems = buildBookingItems();
      // Single mode: one booking-level add-on list. Multiple mode: each package
      // carries its OWN add-ons, so sum them across the packages.
      final addonsSum = isSingleMode
          ? addonsTotalOf(addons.value)
          : bookingCart.value
              .fold<double>(0, (s, e) => s + addonsTotalOf(e.addons));
      if (packages.isEmpty || bookingItems.isEmpty) {
        basePackageAmount.value = 0;
        // Add-ons can still be priced even before a package is chosen so the
        // running total is never wrong.
        totalPrice.value = addonsSum;
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
      // Total = Σ package base prices + Σ add-ons. The ₹3000/package is the
      // ADVANCE (below), not an addition to the bill.
      totalPrice.value = basePackageAmount.value + addonsSum;
      // Advance is per package, once each (package count × ₹3000).
      advanceAmount.value = bookingItems.fold<double>(
        0,
        (sum, item) => sum + item.advanceAmount,
      );
    }

    // Resolved discount in rupees (a flat amount, or a % of the total), never
    // more than the total itself.
    double computedDiscount() {
      final raw = discountValue.value;
      final amt = discountType.value == 'percent'
          ? totalPrice.value * raw / 100
          : raw;
      return amt.clamp(0.0, totalPrice.value).toDouble();
    }

    // Add-on editor — supports zero, one, or many add-ons on a single booking.
    Widget addonSection() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ADD-ONS (OPTIONAL)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: crmColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton.icon(
                onPressed: isSubmitting.value
                    ? null
                    : () {
                        addons.value = [
                          ...addons.value,
                          const BookingAddon(
                            addonServiceId: '',
                            service: '',
                            amount: 0,
                            persons: 1,
                          ),
                        ];
                        recalculate();
                      },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Add-on'),
              ),
            ],
          ),
          if (asyncAddonServices.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (asyncAddonServices.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Could not load add-on services.',
                style: TextStyle(color: Colors.red.shade400, fontSize: 12),
              ),
            ),
          if (addons.value.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: crmColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: crmColors.border),
              ),
              child: Text(
                'No add-ons. Tap "Add Add-on" to include one or more extra '
                'services (e.g. hairstyling, saree draping) — each add-on can '
                'have its own price and number of persons.',
                style: TextStyle(color: crmColors.textSecondary, fontSize: 12),
              ),
            )
          else
            ...List.generate(
              addons.value.length,
              (i) => _AddonRow(
                index: i,
                addon: addons.value[i],
                services: availableAddonServices,
                crm: crmColors,
                enabled: !isSubmitting.value,
                onChanged: (updated) {
                  final next = [...addons.value];
                  next[i] = updated;
                  addons.value = next;
                  recalculate();
                },
                onRemove: () {
                  final next = [...addons.value]..removeAt(i);
                  addons.value = next;
                  recalculate();
                },
              ),
            ),
        ],
      );
    }

    // Compact add-on editor scoped to ONE package row (multiple-booking mode).
    Widget packageAddonEditor(int entryIndex) {
      final entry = bookingCart.value[entryIndex];
      final entryAddons = entry.addons;
      void setAddons(List<BookingAddon> next) {
        final list = [...bookingCart.value];
        list[entryIndex] = list[entryIndex].copyWith(addons: next);
        bookingCart.value = list;
        recalculate();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ADD-ONS',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: crmColors.textSecondary,
                      letterSpacing: 1.1)),
              TextButton.icon(
                onPressed: () => setAddons([
                  ...entryAddons,
                  const BookingAddon(
                      addonServiceId: '', service: '', amount: 0, persons: 1),
                ]),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          if (entryAddons.isEmpty)
            Text('No add-ons for this package.',
                style: TextStyle(fontSize: 11, color: crmColors.textSecondary))
          else
            ...List.generate(
              entryAddons.length,
              (i) => KeyedSubtree(
                key: ValueKey('addon-$entryIndex-$i'),
                child: _AddonRow(
                  index: i,
                  addon: entryAddons[i],
                  services: availableAddonServices,
                  crm: crmColors,
                  enabled: !isSubmitting.value,
                  onChanged: (updated) {
                    final next = [...entryAddons];
                    next[i] = updated;
                    setAddons(next);
                  },
                  onRemove: () {
                    final next = [...entryAddons]..removeAt(i);
                    setAddons(next);
                  },
                ),
              ),
            ),
        ],
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

    Future<void> pickBookedDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: bookedDate.value,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(), // a booking can't have been made in the future
      );
      if (picked != null) {
        bookedDate.value = DateTime(picked.year, picked.month, picked.day);
      }
    }

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        // Bridal dates are often booked 1–2+ years ahead; keep a wide window
        // (and allow older dates for legacy bookings) — matches the edit screen.
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
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

      // Booking-level district: the top selector in single mode, else the FIRST
      // package's own district in multiple mode — so the booking still carries a
      // representative district for geo/reports even though each package prices
      // by its own district.
      final bookingLevelDistrictId = (selectedDistrictId.value?.isNotEmpty == true)
          ? selectedDistrictId.value!
          : (bookingItems.isNotEmpty ? bookingItems.first.districtId : '');
      final selectedDistrictModel = findDistrictById(bookingLevelDistrictId);
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
          phone: normalizePhone(phoneCtrl.text),
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
          // When the booking was made/entered (past-dated for late entries).
          createdAt: bookedDate.value,
          serviceStart: sStart,
          serviceEnd: sEnd,
          totalPrice: totalPrice.value,
          discountAmount: computedDiscount(),
          discountType: discountType.value,
          advanceAmount: advanceAmount.value,
          leadId: qParams['leadId'],
          bookingItems: bookingItems,
          // Single mode: booking-level add-ons. Multiple mode: add-ons live on
          // each package (bookingItems), so keep the booking level empty to
          // avoid double-counting.
          addons: isSingleMode ? addons.value : const <BookingAddon>[],
        );
        await ref.read(bookingProvider.notifier).addBooking(booking);

        if (!context.mounted) return;

        // Invalidate the customers list so the new customer (auto-created
        // on the backend during booking) appears in the Clients Directory.
        ref.invalidate(customersProvider);

        final isConversion = (qParams['leadId'] ?? '').isNotEmpty;
        if (isConversion) {
          // The lead is now Converted on the backend — refresh the leads lists
          // so the new status shows when the salesperson returns to them.
          ref.invalidate(leadsProvider);
          ref.invalidate(paginatedLeadsProvider);
        }
        ref.invalidate(paginatedBookingsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConversion
                  ? 'Lead converted — booking created.'
                  : bookingItems.length > 1
                      ? 'Booking created with ${bookingItems.length} packages — one invoice.'
                      : 'Booking created and added to calendar.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );

        // Navigate somewhere the current user can actually open. Salespeople and
        // custom sales roles often lack calendar access, so blindly going to
        // /calendar here trips the route guard and bounces them (the reported
        // navigation bug). Return a converting salesperson to their leads;
        // otherwise show the calendar when permitted, else fall back safely.
        final access = Access.of(ref.read(authSessionProvider));
        if (isConversion && context.canPop()) {
          context.pop();
        } else if (access.canSeeCalendar) {
          context.go('/calendar?date=${formatDateForRoute(d)}');
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go(access.homeRoute.isNotEmpty ? access.homeRoute : '/');
        }
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(error),
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
                                    // Seed the field from the prefill (e.g. a
                                    // Lead → Booking conversion). The Autocomplete
                                    // owns its own controller, so without this the
                                    // name never shows and submits blank.
                                    initialValue:
                                        TextEditingValue(text: qParams['name'] ?? ''),
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
                              // The booking-level district selector shows ONLY in
                              // single mode. In multiple mode each date row below
                              // picks its own package AND its own district, so a
                              // top-level district here would be redundant.
                              if (isSingleMode)
                              Row(
                                children: [
                                  // District
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        DropdownButtonFormField<String>(
                                          key: districtDropdownKey,
                                          isExpanded: true,
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
                                        isExpanded: true,
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
                                  // Booking date = when it was BOOKED/entered
                                  // (past-date a forgotten booking here).
                                  InkWell(
                                    onTap: isSubmitting.value ? null : pickBookedDate,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InputDecorator(
                                      decoration: _inputDeco('Booking Date (when booked)', crmColors),
                                      child: Row(
                                        children: [
                                          Icon(Icons.event_note_outlined, size: 16, color: crmColors.textSecondary),
                                          8.w,
                                          Expanded(
                                            child: Text(
                                              bookedDate.value.toString().split(' ')[0],
                                              style: TextStyle(color: crmColors.textPrimary),
                                            ),
                                          ),
                                          Icon(Icons.edit_calendar_outlined, size: 18, color: crmColors.primary),
                                        ],
                                      ),
                                    ),
                                  ),
                                  4.h,
                                  Text(
                                    'Forgot to enter a booking earlier? Set this to the real past date it was booked.',
                                    style: TextStyle(fontSize: 11.5, color: crmColors.textSecondary),
                                  ),
                                  16.h,
                                  InkWell(
                                    onTap: isSubmitting.value ? null : pickDate,
                                    borderRadius: BorderRadius.circular(8),
                                      child: InputDecorator(
                                        decoration: _inputDeco(
                                          'Event Date(s)',
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
                                                  : 'Add event date…',
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
                                                            null &&
                                                        (entry.key == 0 ||
                                                            bookingCart
                                                                    .value[entry
                                                                        .key -
                                                                    1]
                                                                    .date ==
                                                                null ||
                                                            _dateKey(bookingCart
                                                                    .value[entry
                                                                        .key -
                                                                    1]
                                                                    .date!) !=
                                                                _dateKey(entry
                                                                    .value
                                                                    .date!))) ...[
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
                                                    // Per-package district —
                                                    // prices THIS package by its
                                                    // own district. Empty = use
                                                    // the booking's district.
                                                    if (!isSingleMode) ...[
                                                      6.h,
                                                      Builder(builder: (ctx) {
                                                        final pkg = findPackageById(
                                                            entry.value.packageId);
                                                        final dId = entry.value.districtId;
                                                        final match = districts
                                                            .where((d) => d.id == dId)
                                                            .toList();
                                                        final label = dId.isEmpty
                                                            ? 'Default (Base Price)'
                                                            : (match.isNotEmpty
                                                                ? '${match.first.name} (${match.first.regionName})'
                                                                : 'Default (Base Price)');
                                                        final priceStr = pkg == null
                                                            ? ''
                                                            : '₹${pkg.effectivePriceForDistrict(dId).toStringAsFixed(0)}';
                                                        return InkWell(
                                                          onTap: districts.isEmpty
                                                              ? null
                                                              : () async {
                                                                  final picked = await _showDistrictPricePicker(
                                                                    context: ctx,
                                                                    districts: districts,
                                                                    package: pkg,
                                                                    currentId: dId,
                                                                  );
                                                                  if (picked != null) {
                                                                    final list = [...bookingCart.value];
                                                                    list[entry.key] =
                                                                        list[entry.key].copyWith(districtId: picked);
                                                                    bookingCart.value = list;
                                                                    recalculate();
                                                                  }
                                                                },
                                                          child: InputDecorator(
                                                            decoration: const InputDecoration(
                                                              isDense: true,
                                                              border: OutlineInputBorder(),
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                              prefixIcon: Icon(Icons.location_on_outlined, size: 16),
                                                              prefixIconConstraints:
                                                                  BoxConstraints(minWidth: 32, minHeight: 0),
                                                            ),
                                                            child: Row(children: [
                                                              Expanded(
                                                                  child: Text(label, overflow: TextOverflow.ellipsis)),
                                                              if (priceStr.isNotEmpty)
                                                                Text(priceStr,
                                                                    style: TextStyle(
                                                                        fontWeight: FontWeight.w700,
                                                                        color: crmColors.primary)),
                                                              Icon(Icons.arrow_drop_down, color: crmColors.textSecondary),
                                                            ]),
                                                          ),
                                                        );
                                                      }),
                                                    ],
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
                                                    // Per-package add-ons live
                                                    // right under the package.
                                                    if (!isSingleMode) ...[
                                                      10.h,
                                                      Divider(
                                                          height: 1,
                                                          color:
                                                              crmColors.border),
                                                      8.h,
                                                      packageAddonEditor(
                                                          entry.key),
                                                    ],
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
                                      if (!isSingleMode &&
                                          selectedDates.value.isNotEmpty) ...[
                                        14.h,
                                        Divider(height: 1, color: crmColors.border),
                                        10.h,
                                        Text(
                                          'Same day, more than one package? Add it here \u2014 each package becomes its own calendar slot and carries its own day charge.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: crmColors.textSecondary,
                                          ),
                                        ),
                                        8.h,
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            for (final d in selectedDates.value)
                                              OutlinedButton.icon(
                                                onPressed: isSubmitting.value
                                                    ? null
                                                    : () {
                                                        final pid = selectedPackageId.value ?? '';
                                                        if (pid.isEmpty) return;
                                                        // Insert beside the other
                                                        // rows for this date so the
                                                        // day stays grouped.
                                                        final list = [...bookingCart.value];
                                                        var insertAt = list.length;
                                                        for (var i = list.length - 1; i >= 0; i--) {
                                                          if (list[i].date != null &&
                                                              _dateKey(list[i].date!) == _dateKey(d)) {
                                                            insertAt = i + 1;
                                                            break;
                                                          }
                                                        }
                                                        list.insert(
                                                          insertAt,
                                                          _BookingCartEntry(
                                                            id: 'extra-${_dateKey(d)}-${DateTime.now().microsecondsSinceEpoch}',
                                                            packageId: pid,
                                                            eventSlot: eventSlotCtrl.text.trim(),
                                                            quantity: 1,
                                                            date: d,
                                                          ),
                                                        );
                                                        bookingCart.value = list;
                                                        recalculate();
                                                      },
                                                icon: const Icon(Icons.add, size: 16),
                                                label: Text('Add to ${_formatDayLabel(d)}'),
                                                style: OutlinedButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  foregroundColor: crmColors.primary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
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
                              // Single mode only — in multiple mode each package
                              // row carries its own add-ons below.
                              if (isSingleMode) addonSection(),
                              24.h,
                              // ── Discount (applied to the balance) ────────────
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: discountCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      onChanged: (v) => discountValue.value =
                                          double.tryParse(v.trim()) ?? 0,
                                      decoration: _inputDeco(
                                        discountType.value == 'percent'
                                            ? 'Discount (%)'
                                            : 'Discount (₹)',
                                        crmColors,
                                      ),
                                    ),
                                  ),
                                  12.w,
                                  ToggleButtons(
                                    isSelected: [
                                      discountType.value == 'inr',
                                      discountType.value == 'percent',
                                    ],
                                    onPressed: (i) => discountType.value =
                                        i == 0 ? 'inr' : 'percent',
                                    borderRadius: BorderRadius.circular(8),
                                    constraints: const BoxConstraints(
                                        minHeight: 44, minWidth: 48),
                                    children: const [Text('₹'), Text('%')],
                                  ),
                                  16.w,
                                  if (computedDiscount() > 0)
                                    Flexible(
                                      child: Text(
                                        '− ₹${computedDiscount().toStringAsFixed(0)} discount',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: crmColors.accent,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                ],
                              ),
                              16.h,
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
                                      label: 'ADVANCE (₹3000 / PACKAGE)',
                                      value:
                                          '₹ ${advanceAmount.value.toStringAsFixed(0)}',
                                      border: crmColors.border,
                                      valueColor: crmColors.accent,
                                    ),
                                  ),
                                  16.w,
                                  Expanded(
                                    child: _summaryBox(
                                      label: 'BALANCE DUE',
                                      value:
                                          '₹ ${(totalPrice.value - computedDiscount() - advanceAmount.value).clamp(0, double.infinity).toStringAsFixed(0)}',
                                      border: crmColors.border,
                                      valueColor: crmColors.textPrimary,
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

  /// This package's own district (multi-district bookings). '' = use the
  /// booking-level district. Drives THIS package's district-based price.
  final String districtId;

  /// This package's own add-ons (multi-package bookings). Priced + invoiced
  /// under this package.
  final List<BookingAddon> addons;

  const _BookingCartEntry({
    required this.id,
    required this.packageId,
    this.packageName = '',
    this.customAmount = 0,
    this.advanceAmount = 0,
    this.eventSlot = '',
    this.quantity = 1,
    this.date,
    this.districtId = '',
    this.addons = const [],
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
    String? districtId,
    List<BookingAddon>? addons,
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
      districtId: districtId ?? this.districtId,
      addons: addons ?? this.addons,
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

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One add-on row in the Add Booking screen. Stateful so its price/persons text
/// fields keep their own controllers and don't lose the cursor when the parent
/// rebuilds after each keystroke (the total recomputes live).
class _AddonRow extends StatefulWidget {
  final int index;
  final BookingAddon addon;
  final List<AddonService> services;
  final CrmTheme crm;
  final bool enabled;
  final ValueChanged<BookingAddon> onChanged;
  final VoidCallback onRemove;

  const _AddonRow({
    required this.index,
    required this.addon,
    required this.services,
    required this.crm,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_AddonRow> createState() => _AddonRowState();
}

class _AddonRowState extends State<_AddonRow> {
  late final TextEditingController _price;
  late final TextEditingController _persons;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: widget.addon.amount == 0 ? '' : widget.addon.amount.toStringAsFixed(0),
    );
    _persons = TextEditingController(text: widget.addon.persons.toString());
  }

  @override
  void dispose() {
    _price.dispose();
    _persons.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;
    final selectedId =
        widget.services.any((s) => s.id == widget.addon.addonServiceId)
            ? widget.addon.addonServiceId
            : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ADD-ON ${widget.index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: crm.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: widget.enabled ? widget.onRemove : null,
                child: const Text(
                  'REMOVE',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          8.h,
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            isExpanded: true,
            decoration: _deco('Add-on service'),
            items: widget.services
                .map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.name} — ₹ ${s.price.toStringAsFixed(0)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: widget.enabled
                ? (value) {
                    if (value == null) return;
                    final sel =
                        widget.services.firstWhere((s) => s.id == value);
                    // Auto-fill the price from the chosen service; the user can
                    // still override it below.
                    _price.text = sel.price.toStringAsFixed(0);
                    widget.onChanged(
                      widget.addon.copyWith(
                        addonServiceId: sel.id,
                        service: sel.name,
                        amount: sel.price,
                        description: sel.description,
                      ),
                    );
                  }
                : null,
          ),
          10.h,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  enabled: widget.enabled,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _deco('Price (₹)'),
                  onChanged: (v) => widget.onChanged(
                    widget.addon.copyWith(amount: double.tryParse(v) ?? 0),
                  ),
                ),
              ),
              12.w,
              Expanded(
                child: TextField(
                  controller: _persons,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  decoration: _deco('Persons'),
                  onChanged: (v) => widget.onChanged(
                    widget.addon.copyWith(persons: int.tryParse(v) ?? 1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Searchable, priced district picker ──────────────────────────────────────
// Bottom sheet listing districts with a search box and each district's price
// for the given package, so a per-package district is quick to choose.
Future<String?> _showDistrictPricePicker({
  required BuildContext context,
  required List<District> districts,
  required ServicePackage? package,
  required String currentId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DistrictPricePickerSheet(
      districts: districts,
      package: package,
      currentId: currentId,
    ),
  );
}

class _DistrictPricePickerSheet extends StatefulWidget {
  final List<District> districts;
  final ServicePackage? package;
  final String currentId;
  const _DistrictPricePickerSheet({
    required this.districts,
    required this.package,
    required this.currentId,
  });
  @override
  State<_DistrictPricePickerSheet> createState() =>
      _DistrictPricePickerSheetState();
}

class _DistrictPricePickerSheetState extends State<_DistrictPricePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _priceFor(String districtId) {
    final p = widget.package;
    if (p == null) return '';
    return '₹${p.effectivePriceForDistrict(districtId).toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final media = MediaQuery.of(context);
    final q = _q.trim().toLowerCase();
    final filtered = widget.districts
        .where((d) =>
            q.isEmpty ||
            d.name.toLowerCase().contains(q) ||
            d.regionName.toLowerCase().contains(q))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: crm.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Row(
                children: [
                  Text('Select district',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: crm.textPrimary)),
                  const Spacer(),
                  if (widget.package != null)
                    Flexible(
                      child: Text(widget.package!.name,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search district or region…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (q.isEmpty)
                    _row(crm,
                        id: '',
                        title: 'Default (Base Price)',
                        subtitle: '',
                        price: _priceFor('')),
                  for (final d in filtered)
                    _row(crm,
                        id: d.id,
                        title: d.name,
                        subtitle: d.regionName,
                        price: _priceFor(d.id)),
                  if (filtered.isEmpty && q.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No districts match "$_q"',
                            style: TextStyle(color: crm.textSecondary)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    CrmTheme crm, {
    required String id,
    required String title,
    required String subtitle,
    required String price,
  }) {
    final selected = id == widget.currentId;
    return InkWell(
      onTap: () => Navigator.of(context).pop(id),
      child: Container(
        color: selected ? crm.primary.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.location_on_outlined,
                size: 18,
                color: selected ? crm.primary : crm.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ],
              ),
            ),
            if (price.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(price,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: crm.primary,
                        fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}
