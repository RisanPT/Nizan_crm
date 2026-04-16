import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/models/service_region.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/booking_print_service.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/models/addon_service.dart';
import '../../core/models/employee.dart';
import '../../core/models/service_package.dart';
import '../../services/addon_service_service.dart';
import '../../services/employee_service.dart';
import '../../services/package_service.dart';
import '../../services/region_service.dart';

class ManageBookingScreen extends HookConsumerWidget {
  final String bookingId;
  final String? bookingEntryId;

  const ManageBookingScreen({
    super.key,
    required this.bookingId,
    this.bookingEntryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isTablet = ResponsiveBuilder.isTablet(context);

    // Look up the booking from the provider by id
    final asyncBookings = ref.watch(bookingProvider);
    final allBookings = asyncBookings.value ?? [];
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncAddonServices = ref.watch(addonServicesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final asyncPackages = ref.watch(packagesProvider);
    final availableStaff = (asyncEmployees.value ?? const <Employee>[])
        .where((employee) => employee.status.toLowerCase() == 'active')
        .toList();
    final availableDrivers = availableStaff
        .where((employee) => employee.artistRole == 'driver')
        .toList();
    final availableAddonServices =
        (asyncAddonServices.value ?? const <AddonService>[])
            .where((service) => service.status.toLowerCase() == 'active')
            .toList();
    final availableRegions = asyncRegions.value ?? const <ServiceRegion>[];
    final availablePackages = asyncPackages.value ?? const <ServicePackage>[];
    final Booking? booking = allBookings.cast<Booking?>().firstWhere(
      (b) => b?.id == bookingId,
      orElse: () => null,
    );
    final bookingEntries =
        booking?.displayEntries ?? const <BookingDisplayEntry>[];
    final selectedDisplayEntry = bookingEntries
        .cast<BookingDisplayEntry?>()
        .firstWhere(
          (entry) => entry?.id == bookingEntryId,
          orElse: () => bookingEntries.isNotEmpty ? bookingEntries.first : null,
        );
    final selectedBookingItemIndex =
        booking != null &&
            booking.bookingItems.isNotEmpty &&
            selectedDisplayEntry != null
        ? booking.displayEntries.indexWhere(
            (entry) => entry.id == selectedDisplayEntry.id,
          )
        : -1;
    final displayBookingNumber = booking?.displayBookingNumber ?? bookingId;
    final canonicalBookingDate =
        selectedDisplayEntry != null &&
            selectedDisplayEntry.selectedDates.isNotEmpty
        ? selectedDisplayEntry.selectedDates.first
        : booking != null && booking.selectedDates.isNotEmpty
        ? booking.selectedDates.first
        : booking?.bookingDate;

    // ── Editable state (pre-filled from booking, editable by user) ──────────
    final statusState = useState(booking?.id != null ? 'confirmed' : 'pending');
    final checklistCompleted = useState(false);
    final contentRequired = useState(false);
    final assignments = useState<List<BookingAssignment>>([]);
    final showAllTodayWorks = useState(false);
    final addons = useState<List<BookingAddon>>([]);
    final discountType = useState<String>(booking?.discountType ?? 'inr');
    final selectedRegionId = useState<String>(booking?.regionId ?? '');
    final selectedDriverId = useState<String>(booking?.driverId ?? '');
    final selectedPackageId = useState<String>(
      selectedDisplayEntry != null && selectedBookingItemIndex >= 0
          ? booking?.bookingItems[selectedBookingItemIndex].packageId ?? ''
          : booking?.packageId ?? '',
    );

    // Controllers pre-filled from real booking data
    final nameCtrl = useTextEditingController(
      text: booking?.customerName ?? '',
    );
    final phoneCtrl = useTextEditingController(text: booking?.phone ?? '');
    final emailCtrl = useTextEditingController(text: booking?.email ?? '');
    final bookingDateCtrl = useTextEditingController(
      text: canonicalBookingDate == null
          ? ''
          : _formatDateOnly(canonicalBookingDate),
    );
    final startTimeCtrl = useTextEditingController(
      text: selectedDisplayEntry != null
          ? _fmt(selectedDisplayEntry.serviceStart)
          : booking != null
          ? _fmt(booking.serviceStart)
          : '',
    );
    final endTimeCtrl = useTextEditingController(
      text: selectedDisplayEntry != null
          ? _fmt(selectedDisplayEntry.serviceEnd)
          : booking != null
          ? _fmt(booking.serviceEnd)
          : '',
    );
    final totalAmountCtrl = useTextEditingController(
      text:
          selectedDisplayEntry?.totalPrice.toStringAsFixed(0) ??
          booking?.totalPrice.toStringAsFixed(0) ??
          '',
    );
    final advanceCtrl = useTextEditingController(
      text:
          selectedDisplayEntry?.advanceAmount.toStringAsFixed(0) ??
          booking?.advanceAmount.toStringAsFixed(0) ??
          '',
    );
    final discountCtrl = useTextEditingController(
      text:
          ((booking?.discountValue ?? 0) == 0
                  ? booking?.discountAmount ?? 0
                  : booking?.discountValue ?? 0)
              .toStringAsFixed(0),
    );
    final advanceValue = useValueListenable(advanceCtrl);
    final discountValueListenable = useValueListenable(discountCtrl);
    final balanceCtrl = useTextEditingController(
      text: booking != null
          ? (booking.totalPrice -
                    booking.advanceAmount -
                    booking.discountAmount)
                .toStringAsFixed(0)
          : '',
    );
    final packageCtrl = useTextEditingController(text: booking?.service ?? '');
    final regionCtrl = useTextEditingController(text: booking?.region ?? '');
    final driverCtrl = useTextEditingController(
      text: booking?.driverName ?? '',
    );

    // CRM-only fields (empty until filled by user)
    final mapUrlCtrl = useTextEditingController();
    final travelModeCtrl = useTextEditingController();
    final travelTimeCtrl = useTextEditingController();
    final travelDistanceCtrl = useTextEditingController(
      text: booking?.travelDistanceKm.toStringAsFixed(0) ?? '',
    );
    final eventSlotInputCtrl = useTextEditingController();
    final eventSlots = useState<List<String>>(
      _parseEventSlots(booking?.eventSlot ?? ''),
    );
    final roomCtrl = useTextEditingController();
    final secondaryPhoneCtrl = useTextEditingController();
    final outfitCtrl = useTextEditingController();
    final captureStaffCtrl = useTextEditingController();
    final temporaryStaffCtrl = useTextEditingController(
      text: booking?.temporaryStaffDetails ?? '',
    );
    final staffNeedsCtrl = useTextEditingController();
    final remarksCtrl = useTextEditingController();
    final initialBasePackageAmount = (() {
      if (selectedDisplayEntry != null) {
        return selectedDisplayEntry.totalPrice;
      }

      final savedAddonTotal =
          booking?.addons.fold<double>(
            0,
            (sum, addon) => sum + (addon.amount * addon.persons),
          ) ??
          0;
      final baseAmount = (booking?.totalPrice ?? 0) - savedAddonTotal;
      return baseAmount < 0 ? 0.0 : baseAmount;
    })();
    final basePackageAmount = useState<double>(initialBasePackageAmount);

    useEffect(
      () {
        if (booking != null) {
          nameCtrl.text = booking.customerName;
          phoneCtrl.text = booking.phone;
          emailCtrl.text = booking.email;
          bookingDateCtrl.text = canonicalBookingDate == null
              ? ''
              : _formatDateOnly(canonicalBookingDate);
          startTimeCtrl.text = _fmt(
            selectedDisplayEntry?.serviceStart ?? booking.serviceStart,
          );
          endTimeCtrl.text = _fmt(
            selectedDisplayEntry?.serviceEnd ?? booking.serviceEnd,
          );
          totalAmountCtrl.text =
              (selectedDisplayEntry?.totalPrice ?? booking.totalPrice)
                  .toStringAsFixed(0);
          advanceCtrl.text =
              (selectedDisplayEntry?.advanceAmount ?? booking.advanceAmount)
                  .toStringAsFixed(0);
          discountType.value = booking.discountType;
          discountCtrl.text =
              ((booking.discountValue == 0
                      ? booking.discountAmount
                      : booking.discountValue))
                  .toStringAsFixed(0);
          balanceCtrl.text =
              ((selectedDisplayEntry?.totalPrice ?? booking.totalPrice) -
                      (selectedDisplayEntry?.advanceAmount ??
                          booking.advanceAmount) -
                      booking.discountAmount)
                  .toStringAsFixed(0);
          final initialService =
              selectedDisplayEntry?.service ?? booking.service;
          packageCtrl.text =
              booking.legacyBooking &&
                  initialService.trim().toLowerCase() == 'legacy sale import'
              ? 'Custom Package'
              : initialService;
          selectedPackageId.value =
              selectedDisplayEntry != null && selectedBookingItemIndex >= 0
              ? booking.bookingItems[selectedBookingItemIndex].packageId
              : booking.packageId;
          basePackageAmount.value =
              selectedDisplayEntry?.totalPrice ??
              (() {
                final savedAddonTotal = booking.addons.fold<double>(
                  0,
                  (sum, addon) => sum + (addon.amount * addon.persons),
                );
                final baseAmount = booking.totalPrice - savedAddonTotal;
                return baseAmount < 0 ? 0.0 : baseAmount;
              })();
          mapUrlCtrl.text = booking.mapUrl;
          travelModeCtrl.text = booking.travelMode;
          travelTimeCtrl.text = booking.travelTime;
          travelDistanceCtrl.text = booking.travelDistanceKm == 0
              ? ''
              : booking.travelDistanceKm.toStringAsFixed(0);
          eventSlots.value = _parseEventSlots(
            selectedDisplayEntry?.eventSlot ?? booking.eventSlot,
          );
          roomCtrl.text = booking.requiredRoomDetail;
          secondaryPhoneCtrl.text = booking.secondaryContact;
          outfitCtrl.text = booking.outfitDetails;
          captureStaffCtrl.text = booking.captureStaffDetails;
          temporaryStaffCtrl.text = booking.temporaryStaffDetails;
          staffNeedsCtrl.text = booking.staffInstructions;
          remarksCtrl.text = booking.internalRemarks;
          contentRequired.value = booking.contentCreationRequired;
          statusState.value = booking.status;
          selectedRegionId.value = booking.regionId;
          selectedDriverId.value = booking.driverId;
        }
        return null;
      },
      [
        booking?.id,
        booking?.customerName,
        booking?.phone,
        booking?.email,
        booking?.regionId,
        booking?.driverId,
        booking?.status,
        booking?.mapUrl,
        booking?.travelMode,
        booking?.travelTime,
        booking?.travelDistanceKm,
        booking?.eventSlot,
        booking?.requiredRoomDetail,
        booking?.secondaryContact,
        booking?.outfitDetails,
        booking?.captureStaffDetails,
        booking?.temporaryStaffDetails,
        booking?.staffInstructions,
        booking?.internalRemarks,
        booking?.contentCreationRequired,
        booking?.totalPrice,
        booking?.advanceAmount,
        selectedDisplayEntry?.id,
        selectedDisplayEntry?.service,
        selectedDisplayEntry?.eventSlot,
        selectedDisplayEntry?.totalPrice,
        selectedDisplayEntry?.advanceAmount,
        selectedDisplayEntry?.serviceStart,
        selectedDisplayEntry?.serviceEnd,
        booking?.discountAmount,
        booking?.discountType,
        booking?.discountValue,
        canonicalBookingDate,
        booking?.serviceStart,
        booking?.serviceEnd,
        booking?.service,
        booking?.packageId,
        selectedBookingItemIndex,
      ],
    );

    double parseMoney(String value) => double.tryParse(value.trim()) ?? 0;

    double addonTotal(List<BookingAddon> items) {
      return items.fold<double>(
        0,
        (sum, addon) => sum + (addon.amount * addon.persons),
      );
    }

    double appliedDiscountAmount(double subtotal) {
      final inputValue = parseMoney(discountCtrl.text);
      if (discountType.value == 'percent') {
        final percent = inputValue.clamp(0, 100);
        return subtotal * (percent / 100);
      }
      return inputValue.clamp(0, subtotal);
    }

    useEffect(
      () {
        final subtotal = basePackageAmount.value + addonTotal(addons.value);
        final discountAmount = appliedDiscountAmount(subtotal);
        final advanceAmount = parseMoney(advanceCtrl.text);
        final forecast = (subtotal - advanceAmount - discountAmount).clamp(
          0,
          double.infinity,
        );
        if (selectedPackageId.value.isNotEmpty) {
          totalAmountCtrl.text = subtotal.toStringAsFixed(0);
        }
        balanceCtrl.text = forecast.toStringAsFixed(0);
        return null;
      },
      [
        basePackageAmount.value,
        addons.value,
        advanceValue.text,
        discountValueListenable.text,
        discountType.value,
        selectedPackageId.value,
      ],
    );

    useEffect(() {
      if (booking != null) {
        assignments.value = List<BookingAssignment>.from(
          selectedDisplayEntry != null
              ? selectedDisplayEntry.assignedStaff
              : booking.bookingItems.isNotEmpty
              ? const <BookingAssignment>[]
              : booking.assignedStaff,
        );
        addons.value = List<BookingAddon>.from(booking.addons);
      }
      return null;
    }, [booking?.id, selectedDisplayEntry?.id]);

    ServicePackage? findPackageById(String? id) {
      if (id == null || id.isEmpty) return null;
      return availablePackages.cast<ServicePackage?>().firstWhere(
        (package) => package?.id == id,
        orElse: () => null,
      );
    }

    double effectivePackagePrice(ServicePackage package) {
      return package.effectivePriceForRegion(selectedRegionId.value);
    }

    void applySelectedPackage(String packageId) {
      if (packageId.isEmpty) {
        selectedPackageId.value = '';
        return;
      }

      final package = findPackageById(packageId);
      if (package == null) return;

      selectedPackageId.value = package.id;
      packageCtrl.text = package.name;
      basePackageAmount.value = effectivePackagePrice(package);
      advanceCtrl.text = package.advanceAmount.toStringAsFixed(0);
    }

    useEffect(() {
      final selectedPackage = findPackageById(selectedPackageId.value);
      if (selectedPackage != null) {
        packageCtrl.text = selectedPackage.name;
        basePackageAmount.value = effectivePackagePrice(selectedPackage);
      }
      return null;
    }, [selectedPackageId.value, selectedRegionId.value, availablePackages]);

    String activeArtistName() {
      final primaryArtist = assignments.value
          .cast<BookingAssignment?>()
          .firstWhere(
            (assignment) =>
                assignment != null &&
                assignment.artistName.trim().isNotEmpty &&
                assignment.roleType.toLowerCase() == 'lead',
            orElse: () => null,
          );
      if (primaryArtist != null) return primaryArtist.artistName.trim();

      final fallbackArtist = assignments.value
          .cast<BookingAssignment?>()
          .firstWhere(
            (assignment) =>
                assignment != null && assignment.artistName.trim().isNotEmpty,
            orElse: () => null,
          );
      return fallbackArtist?.artistName.trim() ?? '';
    }

    final currentArtistName = activeArtistName();
    final currentLeadAssignment = assignments.value
        .cast<BookingAssignment?>()
        .firstWhere(
          (assignment) =>
              assignment != null &&
              assignment.employeeId.trim().isNotEmpty &&
              assignment.roleType.toLowerCase() == 'lead',
          orElse: () => null,
        );
    final currentArtistId = currentLeadAssignment?.employeeId.trim() ?? '';
    final currentBookingDate =
        _parseDateInput(bookingDateCtrl.text.trim()) ??
        canonicalBookingDate ??
        DateTime.now();
    final todayArtistWorks = currentArtistName.isEmpty
        ? const <Booking>[]
        : (() {
            final items = allBookings.where((item) {
              final sameDay = item.isOnDate(currentBookingDate);
              final activeStatus =
                  item.status.toLowerCase() != 'rejected' &&
                  item.status.toLowerCase() != 'cancelled';
              final containsArtist = item.assignedStaff.any(
                (assignment) =>
                    (currentArtistId.isNotEmpty &&
                        assignment.employeeId.trim() == currentArtistId) ||
                    assignment.artistName.trim().toLowerCase() ==
                        currentArtistName.toLowerCase(),
              );
              return sameDay && activeStatus && containsArtist;
            }).toList();
            items.sort((a, b) => a.serviceStart.compareTo(b.serviceStart));
            return items;
          })();
    final todayArtistEntries = currentArtistName.isEmpty
        ? const <BookingDisplayEntry>[]
        : (() {
            final items = allBookings
                .expand((item) => item.displayEntries)
                .where((entry) {
                  final sameDay = entry.isOnDate(currentBookingDate);
                  final activeStatus =
                      entry.booking.status.toLowerCase() != 'rejected' &&
                      entry.booking.status.toLowerCase() != 'cancelled';
                  final containsArtist = entry.assignedStaff.any(
                    (assignment) =>
                        (currentArtistId.isNotEmpty &&
                            assignment.employeeId.trim() == currentArtistId) ||
                        assignment.artistName.trim().toLowerCase() ==
                            currentArtistName.toLowerCase(),
                  );
                  return sameDay && activeStatus && containsArtist;
                })
                .toList();
            items.sort((a, b) => a.serviceStart.compareTo(b.serviceStart));
            return items;
          })();
    final currentWorkIndex = todayArtistEntries.indexWhere(
      (item) => item.id == selectedDisplayEntry?.id,
    );
    final previousArtistWork = currentWorkIndex > 0
        ? todayArtistEntries[currentWorkIndex - 1]
        : null;
    final previousWorkDistanceKm = previousArtistWork == null
        ? null
        : (booking == null
              ? null
              : _distanceBetweenBookings(previousArtistWork.booking, booking));

    useEffect(() {
      final selectedRegion = availableRegions.cast<ServiceRegion?>().firstWhere(
        (region) => region?.id == selectedRegionId.value,
        orElse: () => null,
      );
      if (selectedRegion != null) {
        regionCtrl.text = selectedRegion.name;
      } else if (selectedRegionId.value.isEmpty && booking != null) {
        regionCtrl.text = booking.region;
      }
      return null;
    }, [selectedRegionId.value, availableRegions, booking?.id]);

    useEffect(() {
      final selectedDriver = availableDrivers.cast<Employee?>().firstWhere(
        (driver) => driver?.id == selectedDriverId.value,
        orElse: () => null,
      );
      if (selectedDriver != null) {
        driverCtrl.text = selectedDriver.name;
      } else if (selectedDriverId.value.isEmpty && booking != null) {
        driverCtrl.text = booking.driverName;
      }
      return null;
    }, [selectedDriverId.value, availableDrivers, booking?.id]);

    if (booking == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: crmColors.border),
            24.h,
            Text(
              'Booking #$bookingId not found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: crmColors.textSecondary,
              ),
            ),
            16.h,
            ElevatedButton.icon(
              onPressed: () => context.go('/calendar'),
              icon: const Icon(Icons.calendar_today),
              label: const Text('Back to Calendar'),
            ),
          ],
        ),
      );
    }

    Future<void> showPrintDialog(Booking updatedBooking) async {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Booking Updated'),
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
        await printBookingDetails(
          updatedBooking,
          variant: BookingPrintVariant.client,
        );
      } else if (action == 'artist') {
        await printBookingDetails(
          updatedBooking,
          variant: BookingPrintVariant.artist,
          relatedArtistBookings: todayArtistWorks,
          relatedArtistEntries: todayArtistEntries,
          selectedArtistEntry: selectedDisplayEntry,
          artistName: currentArtistName,
        );
      }
    }

    Booking buildCurrentBookingSnapshot() {
      final parsedBookingDate =
          _parseDateInput(bookingDateCtrl.text.trim()) ??
          canonicalBookingDate ??
          booking.bookingDate;
      final normalizedAddons = _normalizedAddons(addons.value);
      final subtotal =
          basePackageAmount.value +
          normalizedAddons.fold<double>(
            0,
            (sum, addon) => sum + (addon.amount * addon.persons),
          );
      final rawDiscountValue = double.tryParse(discountCtrl.text.trim()) ?? 0;
      final appliedDiscount = discountType.value == 'percent'
          ? subtotal * (rawDiscountValue.clamp(0.0, 100.0) / 100)
          : rawDiscountValue.clamp(0.0, subtotal);
      final currentItemDates =
          selectedDisplayEntry?.selectedDates.isNotEmpty == true
          ? selectedDisplayEntry!.selectedDates
          : booking.selectedDates;
      final normalizedBookingDates = currentItemDates.length <= 1
          ? <DateTime>[parsedBookingDate]
          : currentItemDates;
      final updatedBookingItems =
          selectedBookingItemIndex >= 0 &&
              selectedBookingItemIndex < booking.bookingItems.length
          ? booking.bookingItems.asMap().entries.map((entry) {
              if (entry.key != selectedBookingItemIndex) {
                return entry.value;
              }

              return entry.value.copyWith(
                packageId: selectedPackageId.value.trim(),
                service: packageCtrl.text.trim().isEmpty
                    ? entry.value.service
                    : packageCtrl.text.trim(),
                eventSlot: eventSlots.value.join(' | '),
                selectedDates: entry.value.selectedDates.length <= 1
                    ? <DateTime>[parsedBookingDate]
                    : entry.value.selectedDates,
                totalPrice: subtotal,
                advanceAmount:
                    double.tryParse(advanceCtrl.text.trim()) ??
                    entry.value.advanceAmount,
                assignedStaff: assignments.value,
              );
            }).toList()
          : booking.bookingItems;
      final summarizedAssignments = updatedBookingItems.isNotEmpty
          ? _summarizeBookingItemAssignments(updatedBookingItems)
          : assignments.value;

      return booking.copyWith(
        customerName: nameCtrl.text.trim(),
        packageId: selectedPackageId.value.trim(),
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        service: packageCtrl.text.trim().isEmpty
            ? booking.service
            : packageCtrl.text.trim(),
        regionId: selectedRegionId.value,
        driverId: selectedDriverId.value,
        region: regionCtrl.text.trim(),
        driverName: driverCtrl.text.trim(),
        status: statusState.value,
        mapUrl: mapUrlCtrl.text.trim(),
        travelMode: travelModeCtrl.text.trim(),
        travelTime: travelTimeCtrl.text.trim(),
        travelDistanceKm:
            double.tryParse(travelDistanceCtrl.text.trim()) ??
            booking.travelDistanceKm,
        eventSlot: eventSlots.value.join(' | '),
        requiredRoomDetail: roomCtrl.text.trim(),
        secondaryContact: secondaryPhoneCtrl.text.trim(),
        outfitDetails: outfitCtrl.text.trim(),
        captureStaffDetails: captureStaffCtrl.text.trim(),
        temporaryStaffDetails: temporaryStaffCtrl.text.trim(),
        staffInstructions: staffNeedsCtrl.text.trim(),
        internalRemarks: remarksCtrl.text.trim(),
        contentCreationRequired: contentRequired.value,
        bookingDate: parsedBookingDate,
        selectedDates: normalizedBookingDates,
        serviceStart: _mergeDateAndTime(
          parsedBookingDate,
          startTimeCtrl.text.trim(),
          booking.serviceStart,
        ),
        serviceEnd: _mergeDateAndTime(
          parsedBookingDate,
          endTimeCtrl.text.trim(),
          booking.serviceEnd,
        ),
        totalPrice: subtotal,
        advanceAmount:
            double.tryParse(advanceCtrl.text.trim()) ?? booking.advanceAmount,
        discountAmount: appliedDiscount,
        discountType: discountType.value,
        discountValue: rawDiscountValue,
        assignedStaff: summarizedAssignments,
        addons: normalizedAddons,
        bookingItems: updatedBookingItems,
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  8.w,
                  Text(
                    'Manage Booking #$displayBookingNumber',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  12.w,
                  OutlinedButton.icon(
                    onPressed: () async {
                      await showPrintDialog(buildCurrentBookingSnapshot());
                    },
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print'),
                  ),
                ],
              ),
              if (!isMobile)
                TextButton.icon(
                  onPressed: () => context.go('/calendar'),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to Calendar'),
                  style: TextButton.styleFrom(
                    foregroundColor: crmColors.textSecondary,
                  ),
                ),
            ],
          ),
          24.h,

          if (todayArtistEntries.length > 1) ...[
            _buildTodayWorksSection(
              context,
              crmColors,
              currentArtistName,
              todayArtistEntries,
              showAllTodayWorks,
            ),
            24.h,
          ],

          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Core details ──────────────────────────────────────────
                _SectionCard(
                  title: 'Core Booking Management',
                  subtitle: 'Status, Customer & Financials',
                  titleColor: Colors.amber,
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final narrow = constraints.maxWidth < 600;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: narrow ? 1 : 5,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: narrow ? 5 : 2.5,
                            children: [
                              _buildDropdown(
                                context,
                                'STATUS',
                                [
                                  'pending',
                                  'confirmed',
                                  'completed',
                                  'cancelled',
                                ],
                                statusState.value,
                                (v) =>
                                    statusState.value = v ?? statusState.value,
                              ),
                              _buildField(context, 'CUSTOMER NAME', nameCtrl),
                              _buildField(
                                context,
                                'CONTACT NUMBER',
                                phoneCtrl,
                                keyboardType: TextInputType.phone,
                              ),
                              _buildField(
                                context,
                                'EMAIL',
                                emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              _buildField(
                                context,
                                'BOOKING DATE',
                                bookingDateCtrl,
                                readOnly: true,
                                onTap: () async {
                                  final initialDate =
                                      _parseDateInput(
                                        bookingDateCtrl.text.trim(),
                                      ) ??
                                      canonicalBookingDate ??
                                      booking.bookingDate;
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initialDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    bookingDateCtrl.text = _formatDateOnly(
                                      picked,
                                    );
                                  }
                                },
                                suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      24.h,
                      const Divider(),
                      24.h,
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final narrow = constraints.maxWidth < 600;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: narrow ? 1 : 5,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: narrow ? 5 : 2.7,
                            children: [
                              _buildPackageSelector(
                                context,
                                crmColors,
                                asyncPackages,
                                availablePackages,
                                selectedPackageId,
                                packageCtrl,
                                onPackageChanged: applySelectedPackage,
                              ),
                              _buildCurrencyField(
                                context,
                                'TOTAL AMOUNT',
                                totalAmountCtrl,
                                crmColors,
                                readOnly: selectedPackageId.value.isNotEmpty,
                                onChanged: (value) {
                                  if (selectedPackageId.value.isNotEmpty) {
                                    return;
                                  }
                                  basePackageAmount.value =
                                      double.tryParse(value.trim()) ??
                                      basePackageAmount.value;
                                },
                              ),
                              _buildCurrencyField(
                                context,
                                'ADVANCE PAID',
                                advanceCtrl,
                                crmColors,
                                textColor: Colors.green,
                              ),
                              _buildDiscountField(
                                context,
                                crmColors,
                                discountCtrl,
                                discountType,
                              ),
                              _buildCurrencyField(
                                context,
                                'FORECAST BALANCE',
                                balanceCtrl,
                                crmColors,
                                textColor: Colors.amber,
                                readOnly: true,
                              ),
                            ],
                          );
                        },
                      ),
                      if (selectedPackageId.value.isEmpty) ...[
                        16.h,
                        _buildField(
                          context,
                          'CUSTOM PACKAGE NAME',
                          packageCtrl,
                          hint: 'Enter custom package name',
                        ),
                      ],
                    ],
                  ),
                ),
                24.h,

                // ── Logistics + Scheduled Dates ──────────────────────────
                if (isMobile) ...[
                  _buildLogistics(
                    context,
                    crmColors,
                    asyncRegions,
                    availableRegions,
                    selectedRegionId,
                    availableDrivers,
                    selectedDriverId,
                    regionCtrl,
                    mapUrlCtrl,
                    travelModeCtrl,
                    driverCtrl,
                    travelTimeCtrl,
                    travelDistanceCtrl,
                    eventSlots,
                    eventSlotInputCtrl,
                    roomCtrl,
                    startTimeCtrl,
                    endTimeCtrl,
                    previousArtistWork,
                    previousWorkDistanceKm,
                  ),
                  24.h,
                  _buildScheduledDates(
                    context,
                    crmColors,
                    booking,
                    secondaryPhoneCtrl,
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildLogistics(
                          context,
                          crmColors,
                          asyncRegions,
                          availableRegions,
                          selectedRegionId,
                          availableDrivers,
                          selectedDriverId,
                          regionCtrl,
                          mapUrlCtrl,
                          travelModeCtrl,
                          driverCtrl,
                          travelTimeCtrl,
                          travelDistanceCtrl,
                          eventSlots,
                          eventSlotInputCtrl,
                          roomCtrl,
                          startTimeCtrl,
                          endTimeCtrl,
                          previousArtistWork,
                          previousWorkDistanceKm,
                        ),
                      ),
                      24.w,
                      Expanded(
                        flex: 1,
                        child: _buildScheduledDates(
                          context,
                          crmColors,
                          booking,
                          secondaryPhoneCtrl,
                        ),
                      ),
                    ],
                  ),
                ],
                24.h,

                // ── Artist Assignment ─────────────────────────────────────
                _buildArtistAssignment(
                  context,
                  crmColors,
                  isTablet || isMobile,
                  assignments,
                  availableStaff,
                  asyncEmployees,
                  temporaryStaffCtrl,
                ),
                24.h,

                // ── Service Specifics ─────────────────────────────────────
                _SectionCard(
                  title: 'Service Specifics & Media',
                  child: Column(
                    children: [
                      Flex(
                        direction: isMobile ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: isMobile ? 0 : 1,
                            child: Column(
                              children: [
                                _buildField(
                                  context,
                                  'OUTFIT DETAILS',
                                  outfitCtrl,
                                ),
                                16.h,
                                _buildField(
                                  context,
                                  'CAPTURE STAFF (PHOTO/VIDEO)',
                                  captureStaffCtrl,
                                ),
                                16.h,
                                _buildField(
                                  context,
                                  'TEMPORARY STAFF FOR THIS BOOKING',
                                  temporaryStaffCtrl,
                                  hint: 'Temporary hires for this event only',
                                ),
                                16.h,
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: crmColors.surface,
                                    border: Border.all(color: crmColors.border),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: contentRequired.value,
                                        onChanged: (v) =>
                                            contentRequired.value = v!,
                                        activeColor: Colors.amber,
                                      ),
                                      Flexible(
                                        child: Text(
                                          'CONTENT CREATION REQUIRED (SOCIAL MEDIA)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: crmColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMobile) 16.h else 32.w,
                          Expanded(
                            flex: isMobile ? 0 : 1,
                            child: Column(
                              children: [
                                _buildAddonEditor(
                                  context,
                                  crmColors,
                                  addons,
                                  availableAddonServices,
                                  asyncAddonServices,
                                ),
                                16.h,
                                _buildTextArea(
                                  context,
                                  'STAFF INSTRUCTIONS / NEEDS',
                                  staffNeedsCtrl,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      24.h,
                      const Divider(),
                      24.h,
                      _buildTextArea(
                        context,
                        'CRM INTERNAL REMARKS',
                        remarksCtrl,
                        hint: 'Any private notes...',
                      ),
                    ],
                  ),
                ),
                24.h,

                // ── Completion Action ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: crmColors.surface,
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Transform.scale(
                            scale: 1.5,
                            child: Checkbox(
                              value: checklistCompleted.value,
                              onChanged: (v) => checklistCompleted.value = v!,
                              activeColor: Colors.green,
                            ),
                          ),
                          16.w,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MARK CHECKLIST COMPLETE',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'Verifies all logistics and staffing for export',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: crmColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (isMobile) 24.h,
                      SizedBox(
                        width: isMobile ? double.infinity : 250,
                        child: ElevatedButton(
                          onPressed: () async {
                            final updatedBooking =
                                buildCurrentBookingSnapshot();

                            try {
                              final savedBooking = await ref
                                  .read(bookingProvider.notifier)
                                  .updateBooking(updatedBooking);
                              if (context.mounted) {
                                await showPrintDialog(savedBooking);
                                if (context.mounted) {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/calendar');
                                  }
                                }
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to save changes: $error',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'SAVE CHANGES',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                48.h,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayWorksSection(
    BuildContext context,
    CrmTheme crmColors,
    String artistName,
    List<BookingDisplayEntry> bookings,
    ValueNotifier<bool> showAll,
  ) {
    final visibleBookings = showAll.value
        ? bookings
        : bookings.take(3).toList();

    return _SectionCard(
      title: "Today's Works",
      subtitle: '$artistName has ${bookings.length} booking(s) today',
      child: Column(
        children: [
          ...visibleBookings.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => context.go(
                  '/booking/manage/${entry.booking.id}?entry=${Uri.encodeComponent(entry.id)}',
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: crmColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: crmColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: crmColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _fmt(entry.serviceStart),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: crmColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      16.w,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.booking.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            4.h,
                            Text(
                              entry.service,
                              style: TextStyle(
                                color: crmColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (entry.eventSlot.trim().isNotEmpty) ...[
                              4.h,
                              Text(
                                entry.eventSlot,
                                style: TextStyle(
                                  color: crmColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      12.w,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              entry.booking.status.toLowerCase() == 'confirmed'
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          entry.booking.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                entry.booking.status.toLowerCase() ==
                                    'confirmed'
                                ? Colors.green.shade700
                                : Colors.amber.shade800,
                          ),
                        ),
                      ),
                      12.w,
                      Icon(Icons.chevron_right, color: crmColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (bookings.length > 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showAll.value = !showAll.value,
                icon: Icon(
                  showAll.value ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(showAll.value ? 'Show Less' : 'Show All Works'),
              ),
            ),
        ],
      ),
    );
  }

  // ── Logistics section ────────────────────────────────────────────────────
  Widget _buildLogistics(
    BuildContext context,
    CrmTheme crmColors,
    AsyncValue<List<ServiceRegion>> asyncRegions,
    List<ServiceRegion> availableRegions,
    ValueNotifier<String> selectedRegionId,
    List<Employee> availableDrivers,
    ValueNotifier<String> selectedDriverId,
    TextEditingController regionCtrl,
    TextEditingController mapUrlCtrl,
    TextEditingController travelModeCtrl,
    TextEditingController driverCtrl,
    TextEditingController travelTimeCtrl,
    TextEditingController travelDistanceCtrl,
    ValueNotifier<List<String>> eventSlots,
    TextEditingController eventSlotInputCtrl,
    TextEditingController roomCtrl,
    TextEditingController startCtrl,
    TextEditingController endCtrl,
    BookingDisplayEntry? previousArtistWork,
    double? previousWorkDistanceKm,
  ) {
    return _SectionCard(
      title: 'Logistics & Location',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (ctx, constraints) {
              final narrow = constraints.maxWidth < 400;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: narrow ? 1 : 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: narrow ? 4 : 3,
                children: [
                  _buildRegionDropdown(
                    ctx,
                    crmColors,
                    asyncRegions,
                    availableRegions,
                    selectedRegionId,
                    regionCtrl,
                  ),
                  _buildField(
                    ctx,
                    'MAP URL / COORDINATES',
                    mapUrlCtrl,
                    hint: 'Google Maps Link',
                  ),
                  _buildField(ctx, 'TRAVEL MODE', travelModeCtrl),
                  _buildDriverDropdown(
                    ctx,
                    crmColors,
                    availableDrivers,
                    selectedDriverId,
                    driverCtrl,
                  ),
                  _buildField(ctx, 'TRAVEL TIME', travelTimeCtrl),
                  _buildField(
                    ctx,
                    'TRAVEL DISTANCE (KM)',
                    travelDistanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _buildSlotEditor(ctx, eventSlots, eventSlotInputCtrl),
                ],
              );
            },
          ),
          if (previousArtistWork != null && previousWorkDistanceKm != null) ...[
            16.h,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: crmColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: crmColors.border),
              ),
              child: Text(
                'Previous slot for this artist: ${previousArtistWork.booking.customerName} (${previousArtistWork.service.trim().isEmpty ? 'Work' : previousArtistWork.service}) at ${_fmt(previousArtistWork.serviceStart)}. Distance from previous work to this booking: ${previousWorkDistanceKm.toStringAsFixed(1)} km.',
                style: TextStyle(
                  color: crmColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
          16.h,
          _buildField(
            context,
            'REQUIRED ROOM DETAIL',
            roomCtrl,
            hint: 'e.g. NIL or Room 202',
          ),
          24.h,
          const Divider(),
          24.h,
          Row(
            children: [
              Expanded(
                child: _buildTimeField(
                  context,
                  'SERVICE START TIME',
                  startCtrl,
                  textColor: Colors.amber,
                ),
              ),
              16.w,
              Expanded(
                child: _buildTimeField(
                  context,
                  'REQUIRED COMPLETION',
                  endCtrl,
                  textColor: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Scheduled Dates section ────────────────────────────────────────────
  Widget _buildScheduledDates(
    BuildContext context,
    CrmTheme crmColors,
    Booking booking,
    TextEditingController secondaryCtrl,
  ) {
    final selectedDates = booking.selectedDates.isNotEmpty
        ? booking.selectedDates
        : [booking.bookingDate, booking.serviceEnd].fold<List<DateTime>>(
            <DateTime>[],
            (items, date) {
              final exists = items.any(
                (item) =>
                    item.year == date.year &&
                    item.month == date.month &&
                    item.day == date.day,
              );
              if (!exists) items.add(date);
              return items;
            },
          );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.05),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCHEDULED DATES',
            style: TextStyle(
              color: Colors.indigo.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const Divider(color: Colors.indigoAccent),
          16.h,
          Wrap(
            spacing: 0,
            runSpacing: 8,
            children: [
              for (var index = 0; index < selectedDates.length; index++)
                _dateBadge(
                  context,
                  selectedDates[index].toString().split(' ')[0],
                  index == 0 ? 'primary' : 'extra',
                  crmColors,
                ),
            ],
          ),
          24.h,
          const Divider(color: Colors.indigoAccent),
          16.h,
          _buildField(
            context,
            'SECONDARY CONTACT',
            secondaryCtrl,
            hint: 'Alternative Phone',
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _dateBadge(
    BuildContext context,
    String date,
    String status,
    CrmTheme crmColors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.indigo.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Artist Assignment section ──────────────────────────────────────────
  Widget _buildArtistAssignment(
    BuildContext context,
    CrmTheme crmColors,
    bool isNarrow,
    ValueNotifier<List<BookingAssignment>> assignments,
    List<Employee> availableStaff,
    AsyncValue<List<Employee>> asyncEmployees,
    TextEditingController temporaryStaffCtrl,
  ) {
    return _SectionCard(
      title: 'Artist Assignment Flow',
      child: Flex(
        direction: isNarrow ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT ASSIGNED TEAM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: crmColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                16.h,
                if (assignments.value.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: crmColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'NO ARTISTS ASSIGNED YET',
                        style: TextStyle(
                          color: crmColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else
                  ...assignments.value.map(
                    (a) => _buildAssignmentBlock(a, crmColors, assignments),
                  ),
              ],
            ),
          ),
          if (isNarrow) 24.h else 32.w,
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: crmColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: crmColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 16, color: Colors.indigo),
                      8.w,
                      Text(
                        'ASSIGN TEAM MEMBER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  24.h,
                  _buildAssignForm(
                    context,
                    crmColors,
                    availableStaff,
                    assignments,
                    asyncEmployees,
                  ),
                  16.h,
                  _buildTextArea(
                    context,
                    'TEMPORARY STAFF FOR THIS BOOKING',
                    temporaryStaffCtrl,
                    hint:
                        'Add temporary hires without storing them in staff management',
                  ),
                  24.h,
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: crmColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: crmColors.border),
                    ),
                    child: Text(
                      'Note: A booking must have one Lead Artist before Assistants can be added.',
                      style: TextStyle(
                        fontSize: 10,
                        color: crmColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentBlock(
    BookingAssignment lead,
    CrmTheme crmColors,
    ValueNotifier<List<BookingAssignment>> assignments,
  ) {
    final isLead = lead.roleType == 'lead';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: crmColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: Colors.amber, width: 4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        lead.artistName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      8.w,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isLead ? Colors.amber : Colors.indigo)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isLead ? 'LEAD' : 'ASSISTANT',
                          style: TextStyle(
                            fontSize: 9,
                            color: isLead ? Colors.amber : Colors.indigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  4.h,
                  Text(
                    '${lead.works.isNotEmpty ? lead.works.join(', ') : lead.role} • ${lead.type}',
                    style: TextStyle(
                      fontSize: 10,
                      color: crmColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  assignments.value = assignments.value
                      .where((a) => a.employeeId != lead.employeeId)
                      .toList();
                },
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
        ),
        8.h,
      ],
    );
  }

  Widget _buildAssignForm(
    BuildContext context,
    CrmTheme crmColors,
    List<Employee> availableStaff,
    ValueNotifier<List<BookingAssignment>> assignments,
    AsyncValue<List<Employee>> asyncEmployees,
  ) {
    final selectedArtistId = ValueNotifier<String?>(null);
    final roleCtrl = TextEditingController();
    final hasLead = assignments.value.any((a) => a.roleType == 'lead');
    final isLead = !hasLead;
    final selectableStaff = availableStaff
        .where(
          (employee) =>
              employee.artistRole == (isLead ? 'artist' : 'assistant'),
        )
        .where(
          (employee) => !assignments.value.any(
            (assignment) => assignment.employeeId == employee.id,
          ),
        )
        .fold<List<Employee>>([], (items, employee) {
          final alreadyAdded = items.any((item) => item.id == employee.id);
          if (!alreadyAdded) {
            items.add(employee);
          }
          return items;
        });
    final assignDropdownKey = ValueKey(
      'assign-${isLead ? 'lead' : 'assistant'}-${selectableStaff.map((employee) => employee.id).join(',')}',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLead
            ? Colors.amber.withValues(alpha: 0.05)
            : Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLead
              ? Colors.amber.withValues(alpha: 0.2)
              : Colors.indigo.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLead ? 'ASSIGN LEAD ARTIST' : 'ADD ASSISTANT',
            style: TextStyle(
              fontSize: 9,
              color: isLead ? Colors.amber : Colors.indigoAccent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          12.h,
          if (asyncEmployees.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (asyncEmployees.hasError)
            Text(
              'Unable to load staff right now.',
              style: TextStyle(color: Colors.red.shade400),
            )
          else if (selectableStaff.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: crmColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: crmColors.border),
              ),
              child: Text(
                isLead
                    ? 'No active artists available to assign as lead.'
                    : 'No active assistants available to add.',
                style: TextStyle(color: crmColors.textSecondary, fontSize: 12),
              ),
            )
          else
            DropdownButtonFormField<String>(
              key: assignDropdownKey,
              initialValue: null,
              items: selectableStaff
                  .map(
                    (employee) => DropdownMenuItem(
                      value: employee.id,
                      child: Text(
                        '${employee.name} (${employee.type}${employee.specialization.isNotEmpty ? ' • ${employee.specialization}' : ''})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => selectedArtistId.value = v,
              decoration: _inputDeco(
                isLead ? 'Select lead artist…' : 'Select assistant…',
                crmColors,
              ).copyWith(isDense: true),
            ),
          if (!isLead) ...[
            12.h,
            TextField(
              controller: roleCtrl,
              decoration: _inputDeco(
                'Role, e.g. Hair / Draping',
                crmColors,
              ).copyWith(isDense: true),
            ),
          ],
          12.h,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (selectedArtistId.value == null) return;
                final artist = selectableStaff.firstWhere(
                  (employee) => employee.id == selectedArtistId.value,
                );
                assignments.value = [
                  ...assignments.value,
                  BookingAssignment(
                    employeeId: artist.id,
                    artistName: artist.name,
                    role: isLead
                        ? 'Lead Artist'
                        : (roleCtrl.text.trim().isEmpty
                              ? 'Assistant'
                              : roleCtrl.text.trim()),
                    specialization: artist.specialization,
                    works: artist.works.isNotEmpty
                        ? artist.works
                        : [
                            if (artist.specialization.trim().isNotEmpty)
                              artist.specialization.trim(),
                          ],
                    phone: artist.phone,
                    type: artist.type,
                    roleType: isLead ? 'lead' : 'assistant',
                  ),
                ];
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isLead ? Colors.amber : Colors.indigo,
                foregroundColor: isLead ? Colors.black : Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: Text(isLead ? 'ASSIGN LEAD' : 'ADD ASSISTANT'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Generic field helpers ─────────────────────────────────────────────
  static Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController ctrl, {
    String? hint,
    Color? textColor,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          style: TextStyle(
            color: textColor,
            fontWeight: textColor != null ? FontWeight.bold : FontWeight.normal,
          ),
          decoration: _inputDeco(
            hint ?? '',
            crmColors,
          ).copyWith(suffixIcon: suffixIcon),
        ),
      ],
    );
  }

  static Widget _buildTimeField(
    BuildContext context,
    String label,
    TextEditingController ctrl, {
    Color? textColor,
  }) {
    Future<void> pickTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: _parseTime(ctrl.text.trim()) ?? TimeOfDay.now(),
        builder: (dialogContext, child) {
          return Theme(
            data: Theme.of(dialogContext).copyWith(
              colorScheme: Theme.of(
                dialogContext,
              ).colorScheme.copyWith(primary: Colors.amber),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );

      if (picked != null) {
        final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
        final minute = picked.minute.toString().padLeft(2, '0');
        final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
        ctrl.text = '$hour:$minute $period';
      }
    }

    return _buildField(
      context,
      label,
      ctrl,
      textColor: textColor,
      readOnly: true,
      onTap: pickTime,
      suffixIcon: IconButton(
        onPressed: pickTime,
        icon: const Icon(Icons.access_time_rounded, size: 18),
        splashRadius: 18,
      ),
    );
  }

  static Widget _buildPackageSelector(
    BuildContext context,
    CrmTheme crmColors,
    AsyncValue<List<ServicePackage>> asyncPackages,
    List<ServicePackage> availablePackages,
    ValueNotifier<String> selectedPackageId,
    TextEditingController packageCtrl, {
    required ValueChanged<String> onPackageChanged,
  }) {
    final currentValue =
        availablePackages.any(
          (package) => package.id == selectedPackageId.value,
        )
        ? selectedPackageId.value
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PACKAGE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        DropdownButtonFormField<String>(
          initialValue: currentValue,
          items: [
            const DropdownMenuItem(value: '', child: Text('Custom Package')),
            ...availablePackages.map(
              (package) => DropdownMenuItem(
                value: package.id,
                child: Text(package.name),
              ),
            ),
          ],
          onChanged: (value) => onPackageChanged(value ?? ''),
          decoration: _inputDeco('', crmColors),
        ),
        if (asyncPackages.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (asyncPackages.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Could not load packages.',
              style: TextStyle(color: Colors.red.shade400, fontSize: 12),
            ),
          ),
      ],
    );
  }

  static Widget _buildSlotEditor(
    BuildContext context,
    ValueNotifier<List<String>> eventSlots,
    TextEditingController inputCtrl,
  ) {
    final crmColors = context.crmColors;

    void addSlot() {
      final value = inputCtrl.text.trim();
      if (value.isEmpty) return;

      final normalizedValue = value.replaceAll(RegExp(r'\s+'), ' ');
      final existing = eventSlots.value.map((slot) => slot.toLowerCase());
      if (existing.contains(normalizedValue.toLowerCase())) {
        inputCtrl.clear();
        return;
      }

      eventSlots.value = [...eventSlots.value, normalizedValue];
      inputCtrl.clear();
    }

    void removeSlot(String slot) {
      eventSlots.value = eventSlots.value
          .where((item) => item != slot)
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EVENT SLOT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: inputCtrl,
                onFieldSubmitted: (_) => addSlot(),
                decoration: _inputDeco(
                  'Add slot e.g. Morning wedding',
                  crmColors,
                ),
              ),
            ),
            8.w,
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: addSlot,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        if (eventSlots.value.isNotEmpty) ...[
          10.h,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: eventSlots.value
                .map(
                  (slot) => Chip(
                    label: Text(
                      slot,
                      style: TextStyle(
                        color: crmColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: crmColors.surface,
                    side: BorderSide(color: crmColors.border),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => removeSlot(slot),
                  ),
                )
                .toList(),
          ),
        ] else ...[
          10.h,
          Text(
            'Add one or more slots like Morning wedding, Muhurtham, Evening reception, or Night event.',
            style: TextStyle(
              fontSize: 11,
              color: crmColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  static Widget _buildTextArea(
    BuildContext context,
    String label,
    TextEditingController ctrl, {
    String? hint,
  }) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        TextFormField(
          controller: ctrl,
          maxLines: 2,
          decoration: _inputDeco(hint ?? '', crmColors),
        ),
      ],
    );
  }

  static Widget _buildAddonEditor(
    BuildContext context,
    CrmTheme crmColors,
    ValueNotifier<List<BookingAddon>> addons,
    List<AddonService> availableAddonServices,
    AsyncValue<List<AddonService>> asyncAddonServices,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PACKAGE / ADD-ON DETAILS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: crmColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                addons.value = [
                  ...addons.value,
                  const BookingAddon(
                    addonServiceId: '',
                    service: '',
                    amount: 0,
                    persons: 1,
                  ),
                ];
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Row'),
            ),
          ],
        ),
        8.h,
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crmColors.border),
            ),
            child: Text(
              'No add-ons added yet. Add service, amount, and number of persons.',
              style: TextStyle(color: crmColors.textSecondary, fontSize: 12),
            ),
          )
        else
          ...List.generate(
            addons.value.length,
            (index) => _buildAddonRow(
              context,
              crmColors,
              index,
              availableAddonServices,
              addons.value[index],
              onChanged: (updatedAddon) {
                final next = [...addons.value];
                next[index] = updatedAddon;
                addons.value = next;
              },
              onRemove: () {
                final next = [...addons.value]..removeAt(index);
                addons.value = next;
              },
            ),
          ),
      ],
    );
  }

  static Widget _buildAddonRow(
    BuildContext context,
    CrmTheme crmColors,
    int index,
    List<AddonService> availableAddonServices,
    BookingAddon addon, {
    required ValueChanged<BookingAddon> onChanged,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: crmColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ADD-ON ${index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: crmColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: onRemove,
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
          Text(
            'SERVICE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: crmColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          4.h,
          DropdownButtonFormField<String>(
            initialValue:
                availableAddonServices.any(
                  (service) => service.id == addon.addonServiceId,
                )
                ? addon.addonServiceId
                : null,
            items: availableAddonServices
                .map(
                  (service) => DropdownMenuItem(
                    value: service.id,
                    child: Text(
                      '${service.name} - ₹ ${service.price.toStringAsFixed(0)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final selected = availableAddonServices.firstWhere(
                (service) => service.id == value,
              );
              onChanged(
                addon.copyWith(
                  addonServiceId: selected.id,
                  service: selected.name,
                  amount: selected.price,
                ),
              );
            },
            decoration: _inputDeco('Select add-on service', crmColors),
          ),
          12.h,
          Row(
            children: [
              Expanded(
                child: _buildAddonField(
                  context,
                  'PRICE',
                  addon.amount == 0 ? '' : addon.amount.toStringAsFixed(0),
                  (value) => onChanged(
                    addon.copyWith(amount: double.tryParse(value) ?? 0),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              12.w,
              Expanded(
                child: _buildAddonField(
                  context,
                  'NUMBER OF PERSONS',
                  addon.persons.toString(),
                  (value) => onChanged(
                    addon.copyWith(persons: int.tryParse(value) ?? 1),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildAddonField(
    BuildContext context,
    String label,
    String initialValue,
    ValueChanged<String> onChanged, {
    TextInputType? keyboardType,
  }) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        TextFormField(
          key: ValueKey('$label-$initialValue'),
          initialValue: initialValue,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: _inputDeco('', crmColors),
        ),
      ],
    );
  }

  static Widget _buildDropdown(
    BuildContext context,
    String label,
    List<String> items,
    String value,
    void Function(String?) onChanged,
  ) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e[0].toUpperCase() + e.substring(1)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: _inputDeco('', crmColors),
        ),
      ],
    );
  }

  static Widget _buildCurrencyField(
    BuildContext context,
    String label,
    TextEditingController ctrl,
    CrmTheme crmColors, {
    Color? textColor,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        TextFormField(
          controller: ctrl,
          readOnly: readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          style: TextStyle(
            color: textColor ?? crmColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          decoration: _inputDeco('', crmColors).copyWith(
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12.0, top: 12, bottom: 12),
              child: Text(
                '₹ ',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildRegionDropdown(
    BuildContext context,
    CrmTheme crmColors,
    AsyncValue<List<ServiceRegion>> asyncRegions,
    List<ServiceRegion> availableRegions,
    ValueNotifier<String> selectedRegionId,
    TextEditingController regionCtrl,
  ) {
    final currentValue =
        availableRegions.any((region) => region.id == selectedRegionId.value)
        ? selectedRegionId.value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOCATION / REGION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        if (asyncRegions.isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else if (asyncRegions.hasError)
          TextFormField(
            controller: regionCtrl,
            decoration: _inputDeco('Region', crmColors),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey(
              'booking-region-${currentValue ?? 'none'}-${availableRegions.map((region) => region.id).join(',')}',
            ),
            initialValue: currentValue,
            items: availableRegions
                .map(
                  (region) => DropdownMenuItem(
                    value: region.id,
                    child: Text(region.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              selectedRegionId.value = value ?? '';
              final selected = availableRegions
                  .cast<ServiceRegion?>()
                  .firstWhere(
                    (region) => region?.id == value,
                    orElse: () => null,
                  );
              regionCtrl.text = selected?.name ?? '';
            },
            decoration: _inputDeco(
              regionCtrl.text.isEmpty ? 'Select region' : regionCtrl.text,
              crmColors,
            ),
          ),
      ],
    );
  }

  static Widget _buildDriverDropdown(
    BuildContext context,
    CrmTheme crmColors,
    List<Employee> availableDrivers,
    ValueNotifier<String> selectedDriverId,
    TextEditingController driverCtrl,
  ) {
    final currentValue =
        availableDrivers.any((driver) => driver.id == selectedDriverId.value)
        ? selectedDriverId.value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRIVER',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        DropdownButtonFormField<String>(
          key: ValueKey(
            'booking-driver-${currentValue ?? 'none'}-${availableDrivers.map((driver) => driver.id).join(',')}',
          ),
          initialValue: currentValue,
          items: availableDrivers
              .map(
                (driver) => DropdownMenuItem(
                  value: driver.id,
                  child: Text(
                    driver.phone.isEmpty
                        ? driver.name
                        : '${driver.name} (${driver.phone})',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            selectedDriverId.value = value ?? '';
            final selected = availableDrivers.cast<Employee?>().firstWhere(
              (driver) => driver?.id == value,
              orElse: () => null,
            );
            driverCtrl.text = selected?.name ?? '';
          },
          decoration: _inputDeco(
            driverCtrl.text.isEmpty ? 'Select driver' : driverCtrl.text,
            crmColors,
          ),
        ),
      ],
    );
  }

  static Widget _buildDiscountField(
    BuildContext context,
    CrmTheme crmColors,
    TextEditingController ctrl,
    ValueNotifier<String> discountType,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISCOUNT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        Row(
          children: [
            SizedBox(
              width: 96,
              child: DropdownButtonFormField<String>(
                initialValue: discountType.value,
                items: const [
                  DropdownMenuItem(value: 'inr', child: Text('INR')),
                  DropdownMenuItem(value: 'percent', child: Text('%')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    discountType.value = value;
                  }
                },
                decoration: _inputDeco('', crmColors),
              ),
            ),
            12.w,
            Expanded(
              child: TextFormField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDeco('', crmColors).copyWith(
                  prefixText: discountType.value == 'inr' ? '₹ ' : null,
                  suffixText: discountType.value == 'percent' ? '%' : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static InputDecoration _inputDeco(String hint, CrmTheme crmColors) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: crmColors.textSecondary, fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: crmColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: crmColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.amber, width: 1.5),
      ),
      filled: true,
      fillColor: crmColors.surface,
    );
  }

  static String _fmt(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  static String _formatDateOnly(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime? _parseDateInput(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;

    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static DateTime _mergeDateAndTime(
    DateTime date,
    String timeText,
    DateTime fallback,
  ) {
    final parsed = _parseTime(timeText);
    if (parsed == null) return fallback;

    return DateTime(
      date.year,
      date.month,
      date.day,
      parsed.hour,
      parsed.minute,
    );
  }

  static TimeOfDay? _parseTime(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;

    final rawHour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final meridiem = (match.group(3) ?? '').toUpperCase();
    if (rawHour == null || minute == null) return null;

    var hour = rawHour % 12;
    if (meridiem == 'PM') {
      hour += 12;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  static List<BookingAddon> _normalizedAddons(List<BookingAddon> addons) {
    return addons
        .where((addon) => addon.service.trim().isNotEmpty)
        .map(
          (addon) => addon.copyWith(
            service: addon.service.trim(),
            amount: addon.amount < 0 ? 0 : addon.amount,
            persons: addon.persons < 1 ? 1 : addon.persons,
          ),
        )
        .toList();
  }

  static List<BookingAssignment> _summarizeBookingItemAssignments(
    List<BookingItem> items,
  ) {
    final mergedAssignments = <BookingAssignment>[];
    final seen = <String>{};

    for (final item in items) {
      for (final assignment in item.assignedStaff) {
        final key = assignment.employeeId.trim().isNotEmpty
            ? assignment.employeeId.trim()
            : '${assignment.artistName.trim()}::${assignment.roleType.trim()}';
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        mergedAssignments.add(assignment);
      }
    }

    return mergedAssignments;
  }

  static double? _distanceBetweenBookings(Booking from, Booking to) {
    final fromCoords = _extractCoordinates(from.mapUrl);
    final toCoords = _extractCoordinates(to.mapUrl);
    if (fromCoords == null || toCoords == null) return null;

    const earthRadiusKm = 6371.0;
    final lat1 = fromCoords.$1 * 3.141592653589793 / 180;
    final lat2 = toCoords.$1 * 3.141592653589793 / 180;
    final dLat = (toCoords.$1 - fromCoords.$1) * 3.141592653589793 / 180;
    final dLng = (toCoords.$2 - fromCoords.$2) * 3.141592653589793 / 180;

    final a =
        _sinSquared(dLat / 2) +
        (math.cos(lat1) * math.cos(lat2) * _sinSquared(dLng / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static (double, double)? _extractCoordinates(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final patterns = [
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'q=(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'(-?\d+\.\d+),\s*(-?\d+\.\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final lat = double.tryParse(match.group(1) ?? '');
      final lng = double.tryParse(match.group(2) ?? '');
      if (lat != null && lng != null) {
        return (lat, lng);
      }
    }
    return null;
  }

  static double _sinSquared(double value) {
    final sine = math.sin(value);
    return sine * sine;
  }

  static List<String> _parseEventSlots(String value) {
    return value
        .split(RegExp(r'\s*\|\s*|\s*,\s*|\n+'))
        .map((slot) => slot.trim())
        .where((slot) => slot.isNotEmpty)
        .toList();
  }
}

// ── Section Card widget ────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color? titleColor;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Container(
      padding: EdgeInsets.all(ResponsiveBuilder.isMobile(context) ? 16 : 24),
      decoration: BoxDecoration(
        color: crmColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crmColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor ?? crmColors.textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      4.h,
                      Text(
                        subtitle!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textSecondary,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
