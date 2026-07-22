import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/models/district.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/booking_print_service.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/models/addon_service.dart';
import '../../core/models/employee.dart';
import '../../core/models/service_package.dart';
import '../../services/addon_service_service.dart';

import '../../services/employee_service.dart';
import '../../services/package_service.dart';
import '../../services/district_service.dart';
import '../../services/vehicle_service.dart';
import '../../core/models/vehicle.dart';
import '../../core/utils/whatsapp_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final asyncSingleBooking = bookingId != 'new' ? ref.watch(singleBookingProvider(bookingId)) : null;

    if (bookingId != 'new' && (asyncSingleBooking == null || asyncSingleBooking.isLoading)) {
      return Scaffold(
        backgroundColor: crmColors.background,
        appBar: AppBar(
          backgroundColor: crmColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: crmColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: crmColors.primary),
        ),
      );
    }

    final asyncBookings = ref.watch(bookingProvider);
    final allBookings = asyncBookings.value ?? [];
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncAddonServices = ref.watch(addonServicesProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final availableDistricts = asyncDistricts.value ?? const [];
    final asyncPackages = ref.watch(packagesProvider);
    final asyncVehicles = ref.watch(vehiclesProvider);
    final availableVehicles = (asyncVehicles.value ?? const <Vehicle>[])
        .where((v) => v.status.toLowerCase() == 'running')
        .toList();
    final availableStaff = (asyncEmployees.value ?? const <Employee>[])
        .where((employee) => employee.status.toLowerCase() == 'active')
        .toList();
    final availableDrivers = availableStaff
        .where((employee) => employee.artistRole.toLowerCase() == 'driver')
        .toList();
    final availableDriverIdsSignature = availableDrivers
        .map((driver) => driver.id)
        .join(',');
    final availableAddonServices =
        (asyncAddonServices.value ?? const <AddonService>[])
            .where((service) => service.status.toLowerCase() == 'active')
            .toList();
    final availablePackages = asyncPackages.value ?? const <ServicePackage>[];
    final Booking? booking = bookingId != 'new' 
        ? (asyncSingleBooking?.value ?? allBookings.cast<Booking?>().firstWhere(
            (b) => b?.id == bookingId,
            orElse: () => null,
          ))
        : null;
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
        ? selectedDisplayEntry.bookingItemIndex
        : -1;
    final displayBookingNumber = booking?.displayBookingNumber ?? bookingId;
    final canonicalBookingDate = selectedDisplayEntry != null
        ? selectedDisplayEntry.calendarDate
        : booking != null && booking.selectedDates.isNotEmpty
        ? booking.selectedDates.first
        : booking?.bookingDate;
    final isExtraDateEntry =
        selectedDisplayEntry != null &&
        selectedDisplayEntry.allSelectedDates.length > 1 &&
        selectedDisplayEntry.calendarDate !=
            selectedDisplayEntry.allSelectedDates.first;

    // ── Editable state (pre-filled from booking, editable by user) ──────────
    final statusState = useState(booking?.id != null ? 'confirmed' : 'pending');
    final checklistCompleted = useState(false);
    final contentRequired = useState(false);
    final assignments = useState<List<BookingAssignment>>([]);
    final showAllTodayWorks = useState(false);
    final addons = useState<List<BookingAddon>>(
      booking != null ? List<BookingAddon>.from(booking.addons) : [],
    );
    final discountType = useState<String>(booking?.discountType ?? 'inr');
    final selectedRegionId = useState<String>(booking?.regionId ?? '');
    final selectedDistrictId = useState<String>(booking?.districtId ?? '');
    final isDeleting = useState(false);
    final selectedPackageId = useState<String>(
      selectedDisplayEntry != null && selectedBookingItemIndex >= 0
          ? booking?.bookingItems[selectedBookingItemIndex].packageId ?? ''
          : booking?.packageId ?? '',
    );
    // POC = Point of Contact shown on client PDF
    final selectedPocId = useState<String>(booking?.pocId ?? '');
    
    final selectedPrintItemIndices = useState<Set<int>>({});
    useEffect(() {
      if (booking != null) {
        selectedPrintItemIndices.value = List.generate(booking.bookingItems.length, (i) => i).toSet();
      }
      return null;
    }, [booking?.bookingItems.length]);

    // Controllers pre-filled from real booking data
    final assignArtistId = useState<String?>(null);
    final assignRoleCtrl = useTextEditingController();
    final assignmentType = useState<String>(
      allBookings.any(
            (b) =>
                b.id == bookingId &&
                b.assignedStaff.any((a) => a.roleType == 'lead'),
          )
          ? 'assistant'
          : 'lead',
    );

    // Reset selection when changing between Lead / Driver / Assistant
    useEffect(() {
      assignArtistId.value = null;
      assignRoleCtrl.clear();
      return null;
    }, [assignmentType.value]);

    final nameCtrl = useTextEditingController(
      text: booking?.customerName ?? '',
    );
    final phoneCtrl = useTextEditingController(text: booking?.phone ?? '');
    final addressCtrl = useTextEditingController(text: booking?.address ?? '');
    final pincodeCtrl = useTextEditingController(text: booking?.pincode ?? '');
    final emailCtrl = useTextEditingController(text: booking?.email ?? '');
    final bookingDateCtrl = useTextEditingController(
      text: canonicalBookingDate == null
          ? ''
          : _formatDateOnly(canonicalBookingDate),
    );

    final bookedDateCtrl = useTextEditingController(
      text: booking?.createdAt == null
          ? ''
          : _formatDateOnly(booking!.createdAt!),
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
    final districtCtrl = useTextEditingController(
      text: booking?.district ?? '',
    );

    // CRM-only fields (empty until filled by user)
    final mapUrlCtrl = useTextEditingController();
    useListenable(mapUrlCtrl);
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
    // Multi-look outfit state: each look has a label, outfit text, and map URL
    final outfitLooks = useState<List<OutfitLook>>(_migrateOutfitLooks(booking));
    final captureStaffCtrl = useTextEditingController();
    final temporaryStaffCtrl = useTextEditingController(
      text: booking?.temporaryStaffDetails ?? '',
    );
    final staffNeedsCtrl = useTextEditingController();
    final remarksCtrl = useTextEditingController();
    final initialBasePackageAmount = (() {
      // For bookingItems entries, item.totalPrice is stored as BASE price only.
      // Do NOT subtract savedAddonTotal again — that would undercount the base.
      // For regular bookings, booking.totalPrice is the grand total (base + addons).
      if (selectedBookingItemIndex >= 0) {
        return (selectedDisplayEntry?.totalPrice ?? 0.0).clamp(0.0, double.infinity);
      }
      final savedAddonTotal =
          booking?.addons.fold(
            0.0,
            (sum, addon) => sum + (addon.amount * addon.persons),
          ) ??
          0;
      final entryTotalPrice = selectedDisplayEntry?.totalPrice ?? booking?.totalPrice ?? 0.0;
      final baseAmount = entryTotalPrice - savedAddonTotal;
      return baseAmount < 0 ? 0.0 : baseAmount;
    })();
    final basePackageAmount = useState<double>(initialBasePackageAmount);
    final customPackagePriceCtrl = useTextEditingController(
      text: initialBasePackageAmount.toStringAsFixed(0),
    );

    useEffect(
      () {
        if (booking != null) {
          nameCtrl.text = booking.customerName;
          phoneCtrl.text = booking.phone;
          addressCtrl.text = booking.address;
          pincodeCtrl.text = booking.pincode;
          emailCtrl.text = booking.email;
          bookingDateCtrl.text = canonicalBookingDate == null
              ? ''
              : _formatDateOnly(canonicalBookingDate);
          bookedDateCtrl.text = booking.createdAt == null
              ? ''
              : _formatDateOnly(booking.createdAt!);
          startTimeCtrl.text = _fmt(
            selectedDisplayEntry?.serviceStart ?? booking.serviceStart,
          );
          endTimeCtrl.text = _fmt(
            selectedDisplayEntry?.serviceEnd ?? booking.serviceEnd,
          );
          // For bookingItems, item.totalPrice is BASE only; for regular bookings
          // booking.totalPrice is the grand total. Compute the correct subtotal
          // to display so it always reflects base + addons.
          booking.addons.fold(
            0.0,
            (sum, addon) => sum + (addon.amount * addon.persons),
          );
          advanceCtrl.text =
              (selectedDisplayEntry?.advanceAmount ?? booking.advanceAmount)
                  .toStringAsFixed(0);
          discountType.value = booking.discountType;
          discountCtrl.text =
              ((booking.discountValue == 0
                      ? booking.discountAmount
                      : booking.discountValue))
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
          basePackageAmount.value = (() {
            // For bookingItems entries, selectedDisplayEntry.totalPrice stores
            // the BASE price only (addons are NOT included in item.totalPrice).
            // So do NOT subtract savedAddonTotal — it would make the base negative.
            // For regular (non-item) bookings, booking.totalPrice is the grand
            // total (base + addons), so we subtract addons to isolate the base.
            if (selectedBookingItemIndex >= 0) {
              return (selectedDisplayEntry?.totalPrice ?? 0.0).clamp(0.0, double.infinity);
            }
            final savedAddonTotal = booking.addons.fold(
              0.0,
              (sum, addon) => sum + (addon.amount * addon.persons),
            );
            final entryTotalPrice = selectedDisplayEntry?.totalPrice ?? booking.totalPrice;
            final baseAmount = entryTotalPrice - savedAddonTotal;
            return baseAmount < 0 ? 0.0 : baseAmount;
          })();
          customPackagePriceCtrl.text = basePackageAmount.value.toStringAsFixed(0);
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
          outfitLooks.value = _migrateOutfitLooks(booking);
          captureStaffCtrl.text = booking.captureStaffDetails;
          temporaryStaffCtrl.text = booking.temporaryStaffDetails;
          staffNeedsCtrl.text = booking.staffInstructions;
          remarksCtrl.text = booking.internalRemarks;
          contentRequired.value = booking.contentCreationRequired;
          statusState.value = booking.status;
          selectedRegionId.value = booking.regionId;
          selectedDistrictId.value = booking.districtId;
        }
        return null;
      },
      [
        booking?.id,
        booking?.customerName,
        booking?.phone,
        booking?.address,
        booking?.pincode,
        booking?.email,
        booking?.regionId,
        booking?.districtId,
        booking?.status,
        booking?.mapUrl,
        booking?.travelMode,
        booking?.travelTime,
        booking?.travelDistanceKm,
        booking?.eventSlot,
        booking?.requiredRoomDetail,
        booking?.secondaryContact,
        booking?.outfitLooks.length,
        booking?.captureStaffDetails,
        booking?.temporaryStaffDetails,
        booking?.staffInstructions,
        booking?.internalRemarks,
        booking?.contentCreationRequired,
        booking?.totalPrice,
        booking?.advanceAmount,
        booking?.addons.length,
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
      return items.fold(
        0.0,
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
        totalAmountCtrl.text = subtotal.toStringAsFixed(0);
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

    useEffect(
      () {
        if (booking != null) {
          final initialAssignments = List<BookingAssignment>.from(
            selectedDisplayEntry != null
                ? selectedDisplayEntry.assignedStaff
                : booking.bookingItems.isNotEmpty
                ? const <BookingAssignment>[]
                : booking.assignedStaff,
          );

          // Migrate legacy driverId if not already in assignments
          if (booking.driverId.isNotEmpty &&
              !initialAssignments.any(
                (a) => a.employeeId == booking.driverId,
              )) {
            final driver = availableDrivers.cast<Employee?>().firstWhere(
              (d) => d?.id == booking.driverId,
              orElse: () => null,
            );
            if (driver != null) {
              initialAssignments.add(
                BookingAssignment(
                  employeeId: driver.id,
                  artistName: driver.name,
                  role: 'Driver',
                  type: driver.type,
                  phone: driver.phone,
                  roleType: 'driver',
                  works: driver.works.isNotEmpty ? driver.works : ['Driver'],
                  specialization: driver.specialization,
                ),
              );
            }
          }

          assignments.value = initialAssignments;
          addons.value = List<BookingAddon>.from(booking.addons);
        }
        return null;
      },
      [
        booking?.id,
        booking?.driverId,
        selectedDisplayEntry?.id,
        availableDriverIdsSignature,
        booking?.addons.length,
        booking?.totalPrice,
      ],
    );

    // Clear POC if the chosen staff member is removed from assignments
    useEffect(() {
      if (selectedPocId.value.isNotEmpty &&
          !assignments.value.any(
            (a) => a.employeeId == selectedPocId.value,
          )) {
        selectedPocId.value = '';
      }
      return null;
    }, [assignments.value]);

    ServicePackage? findPackageById(String? id) {
      if (id == null || id.isEmpty) return null;
      return availablePackages.cast<ServicePackage?>().firstWhere(
        (package) => package?.id == id,
        orElse: () => null,
      );
    }

    double effectivePackagePrice(ServicePackage package) {
      return package.effectivePriceForDistrict(selectedDistrictId.value);
    }

    void applySelectedPackage(String packageId) {
      if (packageId.isEmpty) {
        selectedPackageId.value = '';
        return;
      }

      if (isExtraDateEntry) {
        return;
      }

      final package = findPackageById(packageId);
      if (package == null) return;

      selectedPackageId.value = package.id;
      packageCtrl.text = package.name;
      basePackageAmount.value = effectivePackagePrice(package);
      advanceCtrl.text = package.advanceAmount.toStringAsFixed(0);
    }

    useEffect(
      () {
        final selectedPackage = findPackageById(selectedPackageId.value);
        if (selectedPackage != null) {
          packageCtrl.text = selectedPackage.name;
          basePackageAmount.value = effectivePackagePrice(selectedPackage);
          customPackagePriceCtrl.text = basePackageAmount.value.toStringAsFixed(0);
        }
        return null;
      },
      [
        selectedPackageId.value,
        selectedDistrictId.value,
        availablePackages,
        isExtraDateEntry,
      ],
    );

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
                  item.status.toLowerCase() != 'cancelled' &&
                  item.status.toLowerCase() != 'postponed';
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
                      entry.booking.status.toLowerCase() != 'cancelled' &&
                      entry.booking.status.toLowerCase() != 'postponed';
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

    District? findDistrictById(String? id) {
      if (id == null || id.isEmpty) return null;
      return availableDistricts.cast<District?>().firstWhere(
        (district) => district?.id == id,
        orElse: () => null,
      );
    }

    useEffect(() {
      final selectedDistrict = findDistrictById(selectedDistrictId.value);
      if (selectedDistrict != null) {
        districtCtrl.text = selectedDistrict.name;
        regionCtrl.text = selectedDistrict.regionName;
      } else if (selectedDistrictId.value.isEmpty && booking != null) {
        districtCtrl.text = booking.district;
        regionCtrl.text = booking.region;
      }
      return null;
    }, [selectedDistrictId.value, availableDistricts, booking?.id]);

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
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop('whatsapp'),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      if (action == 'whatsapp') {
        await WhatsAppService.sendInvoiceMessage(updatedBooking);
      } else if (action == 'client') {
        final filteredItems = updatedBooking.bookingItems
            .asMap()
            .entries
            .where((e) => selectedPrintItemIndices.value.contains(e.key))
            .map((e) => e.value)
            .toList();
            
        final printTotalPrice = filteredItems.fold<double>(
            0.0, (sum, item) => sum + item.totalPrice + (_bookingItemDays(item) * 3000));
        final printAdvanceAmount = filteredItems.fold<double>(
            0.0, (sum, item) => sum + (item.advanceAmount * _bookingItemDays(item)));
            
        final printBooking = updatedBooking.copyWith(
          bookingItems: filteredItems.isNotEmpty ? filteredItems : updatedBooking.bookingItems,
          totalPrice: filteredItems.isNotEmpty ? printTotalPrice : updatedBooking.totalPrice,
          advanceAmount: filteredItems.isNotEmpty ? printAdvanceAmount : updatedBooking.advanceAmount,
        );

        await printBookingDetails(
          printBooking,
          variant: BookingPrintVariant.clientConfirmation,
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

    Future<bool> showDeleteDialog() async {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete Booking'),
          content: Text(
            'This will permanently delete booking #$displayBookingNumber for ${booking.customerName}. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Booking'),
            ),
          ],
        ),
      );

      return result ?? false;
    }

    Booking buildCurrentBookingSnapshot() {
      final parsedBookingDate =
          _parseDateInput(bookingDateCtrl.text.trim()) ??
          canonicalBookingDate ??
          booking.bookingDate;
      final normalizedAddons = _normalizedAddons(addons.value);
      final subtotal =
          basePackageAmount.value +
          normalizedAddons.fold(
            0.0,
            (sum, addon) => sum + (addon.amount * addon.persons),
          );
      final currentItemDates =
          selectedDisplayEntry?.allSelectedDates.isNotEmpty == true
          ? selectedDisplayEntry!.allSelectedDates
          : booking.selectedDates;
      final normalizedBookingDates = _replaceBookingDate(
        currentItemDates,
        selectedDisplayEntry?.calendarDate,
        parsedBookingDate,
      );
      // Mirror backend resolveSchedule(): serviceStart uses first date,
      // serviceEnd uses last date (important for multi-day bookings).
      final lastBookingDate = normalizedBookingDates.isNotEmpty
          ? normalizedBookingDates.last
          : parsedBookingDate;
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
                selectedDates: _replaceBookingDate(
                  entry.value.selectedDates,
                  selectedDisplayEntry?.calendarDate,
                  parsedBookingDate,
                ),
                totalPrice: basePackageAmount.value,
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

      // ── Multi-item aggregation (mirrors backend bookingController) ────────
      // A booking can hold several packages / days but is ONE invoice. The
      // booking-level totals, service, slots and dates must be derived from
      // ALL items — never from just the item currently being edited —
      // otherwise saving one package corrupts the price/dates of the whole
      // booking. For a single-item booking we keep the existing behaviour.
      const double extraDateChargePerPackage = 3000;
      // Roll totals up from the items whenever the booking is item-based —
      // even a single package spanning several days needs the extra-date
      // charge and per-day advance aggregated. Only packageId keeps a distinct
      // "multiple packages" special-case (see copyWith below).
      final bool useItemAggregates = updatedBookingItems.isNotEmpty;
      final bool isMultiItem = updatedBookingItems.length > 1;

      final double addonsTotal = normalizedAddons.fold(
        0.0,
        (sum, addon) => sum + (addon.amount * addon.persons),
      );

      // Distinct, chronologically-sorted union of every item's dates.
      final List<DateTime> mergedItemDates;
      if (useItemAggregates) {
        final seen = <String>{};
        final merged = <DateTime>[];
        for (final item in updatedBookingItems) {
          for (final d in item.selectedDates) {
            if (seen.add('${d.year}-${d.month}-${d.day}')) {
              merged.add(DateTime(d.year, d.month, d.day));
            }
          }
        }
        merged.sort((a, b) => a.compareTo(b));
        mergedItemDates = merged;
      } else {
        mergedItemDates = normalizedBookingDates;
      }

      // Day charge: ₹3000 for every day each package runs (mirrors backend).
      final double aggregateDayCharge = updatedBookingItems.fold(
        0.0,
        (sum, item) =>
            sum + (_bookingItemDays(item) * extraDateChargePerPackage),
      );
      final double aggregateTotalPrice =
          updatedBookingItems.fold(0.0, (sum, item) => sum + item.totalPrice) +
          addonsTotal +
          aggregateDayCharge;

      // Advance: each package's advance, once per day it runs (mirrors backend).
      final double aggregateAdvance = updatedBookingItems.fold(
        0.0,
        (sum, item) => sum + (item.advanceAmount * _bookingItemDays(item)),
      );

      final String aggregateService = <String>{
        for (final item in updatedBookingItems)
          if (item.service.trim().isNotEmpty) item.service.trim(),
      }.join(' + ');

      final String aggregateEventSlot = <String>{
        for (final item in updatedBookingItems)
          if (item.eventSlot.trim().isNotEmpty) item.eventSlot.trim(),
      }.join(' | ');

      // Discount applies against whichever total actually bills.
      final double discountBase =
          useItemAggregates ? aggregateTotalPrice : subtotal;
      final rawDiscountValue = double.tryParse(discountCtrl.text.trim()) ?? 0;
      final appliedDiscount = discountType.value == 'percent'
          ? discountBase * (rawDiscountValue.clamp(0.0, 100.0) / 100)
          : rawDiscountValue.clamp(0.0, discountBase);

      final selectedDistrictModel = findDistrictById(selectedDistrictId.value);
      final currentBookingSnapshot = booking.copyWith(
        customerName: nameCtrl.text.trim(),
        // For a multi-item booking, keep the booking-level packageId intact —
        // don't overwrite it with the single item currently being edited.
        packageId: isMultiItem
            ? booking.packageId
            : selectedPackageId.value.trim(),
        phone: normalizePhone(phoneCtrl.text),
        address: addressCtrl.text.trim(),
        pincode: pincodeCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        service: isMultiItem
            ? (aggregateService.isEmpty ? booking.service : aggregateService)
            : (packageCtrl.text.trim().isEmpty
                  ? booking.service
                  : packageCtrl.text.trim()),
        regionId: selectedDistrictModel?.regionId ?? selectedRegionId.value,
        districtId: selectedDistrictId.value,
        driverId:
            assignments.value
                .where((a) => a.roleType == 'driver')
                .firstOrNull
                ?.employeeId ??
            '',
        region: selectedDistrictModel?.regionName ?? regionCtrl.text.trim(),
        district: districtCtrl.text.trim(),
        driverName:
            assignments.value
                .where((a) => a.roleType == 'driver')
                .firstOrNull
                ?.artistName ??
            '',
        status: statusState.value,
        mapUrl: mapUrlCtrl.text.trim(),
        travelMode: travelModeCtrl.text.trim(),
        travelTime: travelTimeCtrl.text.trim(),
        travelDistanceKm: travelDistanceCtrl.text.trim().isEmpty
            ? 0.0
            : (double.tryParse(travelDistanceCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), '')) ??
                booking.travelDistanceKm),
        eventSlot: isMultiItem
            ? (aggregateEventSlot.isEmpty
                  ? booking.eventSlot
                  : aggregateEventSlot)
            : eventSlots.value.join(' | '),
        requiredRoomDetail: roomCtrl.text.trim(),
        secondaryContact: secondaryPhoneCtrl.text.trim(),
        outfitLooks: outfitLooks.value,
        captureStaffDetails: captureStaffCtrl.text.trim(),
        temporaryStaffDetails: temporaryStaffCtrl.text.trim(),
        staffInstructions: staffNeedsCtrl.text.trim(),
        internalRemarks: remarksCtrl.text.trim(),
        contentCreationRequired: contentRequired.value,
        createdAt:
            _parseDateInput(bookedDateCtrl.text.trim()) ?? booking.createdAt,
        bookingDate: parsedBookingDate,
        selectedDates:
            useItemAggregates ? mergedItemDates : normalizedBookingDates,
        serviceStart: _mergeDateAndTime(
          useItemAggregates && mergedItemDates.isNotEmpty
              ? mergedItemDates.first
              : parsedBookingDate,
          startTimeCtrl.text.trim(),
          booking.serviceStart,
        ),
        serviceEnd: _mergeDateAndTime(
          useItemAggregates && mergedItemDates.isNotEmpty
              ? mergedItemDates.last
              : lastBookingDate,
          endTimeCtrl.text.trim(),
          booking.serviceEnd,
        ),
        totalPrice: useItemAggregates ? aggregateTotalPrice : subtotal,
        advanceAmount: useItemAggregates
            ? aggregateAdvance
            : (double.tryParse(advanceCtrl.text.trim()) ??
                  booking.advanceAmount),
        discountAmount: appliedDiscount,
        discountType: discountType.value,
        discountValue: rawDiscountValue,
        assignedStaff: summarizedAssignments,
        addons: normalizedAddons,
        bookingItems: updatedBookingItems,
        pocId: selectedPocId.value,
        pocName: () {
          if (selectedPocId.value.isEmpty) return '';
          // Prefer live employee data
          final emp = availableStaff
              .cast<Employee?>()
              .firstWhere(
                (e) => e?.id == selectedPocId.value,
                orElse: () => null,
              );
          if (emp != null) return emp.name.trim();
          // Fall back to stored assignment name
          return assignments.value
                  .cast<BookingAssignment?>()
                  .firstWhere(
                    (a) => a?.employeeId == selectedPocId.value,
                    orElse: () => null,
                  )
                  ?.artistName
                  .trim() ??
              '';
        }(),
        pocPhone: () {
          if (selectedPocId.value.isEmpty) return '';
          // Prefer live employee phone (always current)
          final emp = availableStaff
              .cast<Employee?>()
              .firstWhere(
                (e) => e?.id == selectedPocId.value,
                orElse: () => null,
              );
          if (emp != null && emp.phone.trim().isNotEmpty) return emp.phone.trim();
          // Fall back to stored assignment phone
          return assignments.value
                  .cast<BookingAssignment?>()
                  .firstWhere(
                    (a) => a?.employeeId == selectedPocId.value,
                    orElse: () => null,
                  )
                  ?.phone
                  .trim() ??
              '';
        }(),
      );
      return currentBookingSnapshot;
    }

    return SelectionArea(
      child: SingleChildScrollView(
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
                  12.w,
                  OutlinedButton.icon(
                    onPressed: () async {
                      await WhatsAppService.sendInvoiceMessage(booking);
                    },
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                  12.w,
                  OutlinedButton.icon(
                    onPressed: isDeleting.value
                        ? null
                        : () async {
                            final shouldDelete = await showDeleteDialog();
                            if (!shouldDelete || !context.mounted) return;

                            isDeleting.value = true;
                            try {
                              await ref
                                  .read(bookingProvider.notifier)
                                  .removeBooking(booking.id);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Booking deleted successfully.',
                                    ),
                                  ),
                                );
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/calendar');
                                }
                              }
                            } catch (error) {
                              if (context.mounted) {
                                isDeleting.value = false;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to delete booking: $error',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    icon: isDeleting.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 18),
                    label: Text(isDeleting.value ? 'Deleting...' : 'Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
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
                // ── Packages/slots in this booking (item-based bookings) ──
                if (booking.bookingItems.isNotEmpty) ...[
                  _buildBookingItemsOverview(
                      context, ref, crmColors, booking, selectedBookingItemIndex, selectedPrintItemIndices),
                  24.h,
                ],
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
                                  'postponed',
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
                              _buildField(context, 'ADDRESS', addressCtrl),
                              _buildField(
                                context,
                                'PINCODE',
                                pincodeCtrl,
                                keyboardType: TextInputType.number,
                              ),
                              _buildField(
                                context,
                                'EVENT DATE',
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
                              _buildField(
                                context,
                                'BOOKED DATE',
                                bookedDateCtrl,
                                readOnly: true,
                                onTap: () async {
                                  final initialDate =
                                      _parseDateInput(
                                        bookedDateCtrl.text.trim(),
                                      ) ??
                                      booking.createdAt ??
                                      DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initialDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    bookedDateCtrl.text = _formatDateOnly(
                                      picked,
                                    );
                                  }
                                },
                                suffixIcon: const Icon(
                                  Icons.bookmark_added_outlined,
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
                                isExtraDateEntry: isExtraDateEntry,
                                onPackageChanged: applySelectedPackage,
                              ),
                              _buildCurrencyField(
                                context,
                                'TOTAL AMOUNT',
                                totalAmountCtrl,
                                crmColors,
                                readOnly: true,
                                onChanged: null,
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
                        16.h,
                        _buildCurrencyField(
                          context,
                          'CUSTOM PACKAGE PRICE',
                          customPackagePriceCtrl,
                          crmColors,
                          onChanged: (value) {
                            final typedVal = double.tryParse(value.trim()) ?? 0.0;
                            basePackageAmount.value = typedVal;
                          },
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
                    asyncDistricts,
                    availableDistricts,
                    selectedDistrictId,
                    availableDrivers,
                    availableVehicles,
                    districtCtrl,
                    regionCtrl,
                    mapUrlCtrl,
                    travelModeCtrl,
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
                          asyncDistricts,
                          availableDistricts,
                          selectedDistrictId,
                          availableDrivers,
                          availableVehicles,
                          districtCtrl,
                          regionCtrl,
                          mapUrlCtrl,
                          travelModeCtrl,
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
                  availableVehicles,
                  temporaryStaffCtrl,
                  assignArtistId,
                  assignRoleCtrl,
                  assignmentType,
                  selectedPocId,
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
                                _OutfitLooksEditor(
                                  looks: outfitLooks.value,
                                  onChanged: (updated) =>
                                      outfitLooks.value = updated,
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTextArea(
                                      context,
                                      'STAFF INSTRUCTIONS / NEEDS',
                                      staffNeedsCtrl,
                                    ),
                                    8.h,
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        ActionChip(
                                          label: const Text('Add List Item', style: TextStyle(fontSize: 10)),
                                          onPressed: () {
                                            final text = staffNeedsCtrl.text;
                                            final lines = text.split('\n');
                                            int nextNum = 1;
                                            for (final line in lines.reversed) {
                                              final match = RegExp(r'^(\d+)\.').firstMatch(line.trim());
                                              if (match != null) {
                                                nextNum = int.parse(match.group(1)!) + 1;
                                                break;
                                              }
                                            }
                                            final prefix = text.isEmpty || text.endsWith('\n') ? '' : '\n';
                                            staffNeedsCtrl.text = '$text$prefix$nextNum. ';
                                            staffNeedsCtrl.selection = TextSelection.fromPosition(TextPosition(offset: staffNeedsCtrl.text.length));
                                          },
                                        ),
                                        ActionChip(
                                          label: const Text('Paste Map Link', style: TextStyle(fontSize: 10)),
                                          onPressed: () async {
                                            final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                                            final pastedText = clipboardData?.text?.trim() ?? '';
                                            
                                            final text = staffNeedsCtrl.text;
                                            final prefix = text.isEmpty || text.endsWith('\n') ? '' : '\n';
                                            
                                            if (pastedText.isNotEmpty && (pastedText.startsWith('http://') || pastedText.startsWith('https://'))) {
                                              staffNeedsCtrl.text = '$text${prefix}Location Map: $pastedText\n';
                                            } else if (pastedText.isNotEmpty) {
                                              staffNeedsCtrl.text = '$text${prefix}Location: $pastedText\n';
                                            } else {
                                              staffNeedsCtrl.text = '$text${prefix}Location Map: [Paste Link Here]\n';
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Clipboard is empty or does not contain text.')),
                                                );
                                              }
                                            }
                                            
                                            staffNeedsCtrl.selection = TextSelection.fromPosition(TextPosition(offset: staffNeedsCtrl.text.length));
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
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

                            // DEBUG: print what is being sent to the server
                            debugPrint(
                              '[SAVE] totalPrice=${updatedBooking.totalPrice}, '
                              'addons=${updatedBooking.addons.map((a) => "${a.service}:${a.amount}x${a.persons}").toList()}',
                            );

                            Booking? savedBooking;
                            try {
                              savedBooking = await ref
                                  .read(bookingProvider.notifier)
                                  .updateBooking(updatedBooking);
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
                              return;
                            }

                            if (!context.mounted) {
                              return;
                            }

                            try {
                              await showPrintDialog(savedBooking);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Booking saved, but WhatsApp action failed: $error',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }

                            if (context.mounted) {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/calendar');
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
    final activeBookings = bookings.where((e) => e.booking.status != 'completed' && e.booking.status != 'postponed' && e.booking.status != 'cancelled').toList();
    final visibleBookings = showAll.value
        ? activeBookings
        : activeBookings.take(3).toList();

    return _SectionCard(
      title: "Today's Works",
      subtitle: '$artistName has ${activeBookings.length} active booking(s) today',
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
                            if (entry.booking.district.trim().isNotEmpty ||
                                entry.booking.region.trim().isNotEmpty) ...[
                              4.h,
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: crmColors.textSecondary,
                                  ),
                                  4.w,
                                  Expanded(
                                    child: Text(
                                      [
                                        if (entry.booking.district
                                            .trim()
                                            .isNotEmpty)
                                          entry.booking.district.trim(),
                                        if (entry.booking.region
                                            .trim()
                                            .isNotEmpty)
                                          entry.booking.region.trim(),
                                      ].join(', '),
                                      style: TextStyle(
                                        color: crmColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
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
    AsyncValue<List<District>> asyncDistricts,
    List<District> availableDistricts,
    ValueNotifier<String> selectedDistrictId,
    List<Employee> availableDrivers,
    List<Vehicle> availableVehicles,
    TextEditingController districtCtrl,
    TextEditingController regionCtrl,
    TextEditingController mapUrlCtrl,
    TextEditingController travelModeCtrl,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  _buildDistrictDropdown(
                    ctx,
                    crmColors,
                    asyncDistricts,
                    availableDistricts,
                    selectedDistrictId,
                    districtCtrl,
                    regionCtrl,
                  ),
                  _buildField(
                    ctx,
                    'MAP URL / COORDINATES',
                    mapUrlCtrl,
                    hint: 'Google Maps Link',
                    suffixIcon: mapUrlCtrl.text.trim().isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.open_in_new_rounded, color: crmColors.primary),
                            onPressed: () async {
                              final text = mapUrlCtrl.text.trim();
                              Uri? uri;
                              if (text.startsWith('http://') || text.startsWith('https://')) {
                                uri = Uri.tryParse(text);
                              } else {
                                uri = Uri.tryParse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(text)}');
                              }
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Could not open map URL.')),
                                  );
                                }
                              }
                            },
                          )
                        : null,
                  ),
                  _buildField(
                    ctx,
                    'TRAVEL MODE',
                    travelModeCtrl,
                    hint: 'Car / Flight / Self',
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
          if (availableVehicles.isNotEmpty) ...[
            24.h,
            Text(
              'QUICK FLEET SELECT (TRAVEL)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: crmColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            12.h,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableVehicles.map((vehicle) {
                  final vehicleName = vehicle.name.isNotEmpty
                      ? vehicle.name
                      : vehicle.brand;
                  final isSelected = travelModeCtrl.text == vehicleName;
                  return GestureDetector(
                    onTap: () {
                      travelModeCtrl.text = vehicleName;
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.indigo.withValues(alpha: 0.1)
                            : crmColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.indigo : crmColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_car_rounded,
                            size: 16,
                            color: isSelected
                                ? Colors.indigo
                                : crmColors.textSecondary,
                          ),
                          10.w,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vehicleName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.indigo
                                      : crmColors.textPrimary,
                                ),
                              ),
                              if (vehicle.registrationNumber.isNotEmpty)
                                Text(
                                  vehicle.registrationNumber,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: crmColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Previous slot for this artist: ${previousArtistWork.booking.customerName} (${previousArtistWork.service.trim().isEmpty ? 'Work' : previousArtistWork.service}) at ${_fmt(previousArtistWork.serviceStart)}. Distance from previous work to this booking: ${previousWorkDistanceKm.toStringAsFixed(1)} km.',
                    style: TextStyle(
                      color: crmColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (previousArtistWork.booking.mapUrl.trim().isNotEmpty && mapUrlCtrl.text.trim().isNotEmpty) ...[
                    8.h,
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: crmColors.primary,
                        side: BorderSide(color: crmColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.directions, size: 14),
                      label: const Text('Open Route in Maps to Calculate Distance'),
                      onPressed: () async {
                        final origin = previousArtistWork.booking.mapUrl.trim();
                        final destination = mapUrlCtrl.text.trim();
                        final url = 'https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeComponent(origin)}&destination=${Uri.encodeComponent(destination)}';
                        final uri = Uri.tryParse(url);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open directions link.')),
                          );
                        }
                      },
                    ),
                  ],
                ],
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
  // Overview of every package/day/slot that belongs to this ONE booking.
  // Tap an entry to switch which one you're editing (they share one invoice).
  Widget _buildBookingItemsOverview(
    BuildContext context,
    WidgetRef ref,
    CrmTheme crm,
    Booking booking,
    int currentItemIndex,
    ValueNotifier<Set<int>> selectedPrintItemIndices,
  ) {
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final items = booking.bookingItems;

    String datesLabel(BookingItem item) {
      final ds = [...item.selectedDates]..sort((a, b) => a.compareTo(b));
      if (ds.isEmpty) return '';
      return ds.map((d) => '${d.day} ${mo[d.month - 1]}').join(', ');
    }

    return _SectionCard(
      title: 'Packages & Slots in this Booking',
      subtitle:
          '${items.length} package${items.length == 1 ? '' : 's'} · billed as one invoice',
      titleColor: Colors.indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in items.asMap().entries)
            Builder(builder: (context) {
              final index = entry.key;
              final item = entry.value;
              final isCurrent = index == currentItemIndex;
              final slot = item.eventSlot.trim();
              final dates = datesLabel(item);
              final isSelectedForPrint = selectedPrintItemIndices.value.contains(index);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? crm.primary.withValues(alpha: 0.08)
                        : crm.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isCurrent ? crm.primary : crm.border,
                        width: isCurrent ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSelectedForPrint,
                        activeColor: crm.primary,
                        onChanged: (bool? checked) {
                          final newSelection = Set<int>.from(selectedPrintItemIndices.value);
                          if (checked == true) {
                            newSelection.add(index);
                          } else {
                            newSelection.remove(index);
                          }
                          selectedPrintItemIndices.value = newSelection;
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                item.service.trim().isEmpty
                                    ? 'Package ${index + 1}'
                                    : item.service.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            2.h,
                            Text(
                                [
                                  if (dates.isNotEmpty) dates,
                                  if (slot.isNotEmpty) slot,
                                ].join(' · '),
                                style: TextStyle(
                                    fontSize: 12, color: crm.textSecondary)),
                          ],
                        ),
                      ),
                      8.w,
                      Text('₹${item.totalPrice.toStringAsFixed(0)}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w800)),
                      6.w,
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: crm.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('EDITING',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                        )
                      else
                        IconButton(
                          tooltip: 'Edit this package',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.edit_outlined,
                              size: 18, color: crm.textSecondary),
                          onPressed: () => context.go(
                              '/booking/manage/${booking.id}?entry=${Uri.encodeComponent('${booking.id}::$index::0')}'),
                        ),
                      IconButton(
                        tooltip: 'Print single PDF',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.picture_as_pdf_outlined,
                            size: 18, color: Colors.blueGrey),
                        onPressed: () async {
                          final singleItemBooking = booking.copyWith(
                            bookingItems: [item],
                            totalPrice: item.totalPrice + (_bookingItemDays(item) * 3000),
                            advanceAmount: item.advanceAmount * _bookingItemDays(item),
                          );
                          await printBookingDetails(
                            singleItemBooking,
                            variant: BookingPrintVariant.clientConfirmation,
                          );
                        },
                      ),
                      if (items.length > 1)
                        IconButton(
                          tooltip: 'Remove this package',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: crm.destructive),
                          onPressed: () => _removeBookingItem(
                              context, ref, booking, index, currentItemIndex),
                        ),
                    ],
                  ),
                ),
              );
            }),
          6.h,
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _addBookingItem(context, ref, booking),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add package'),
              style: OutlinedButton.styleFrom(
                foregroundColor: crm.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          8.h,
          Text(
            'Each row is a package of this booking. Edit, remove, or add a '
            'package — they all share a single invoice.',
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistAssignment(
    BuildContext context,
    CrmTheme crmColors,
    bool isNarrow,
    ValueNotifier<List<BookingAssignment>> assignments,
    List<Employee> availableStaff,
    AsyncValue<List<Employee>> asyncEmployees,
    List<Vehicle> availableVehicles,
    TextEditingController temporaryStaffCtrl,
    ValueNotifier<String?> assignArtistId,
    TextEditingController assignRoleCtrl,
    ValueNotifier<String> assignmentType,
    ValueNotifier<String> selectedPocId,
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
                // ── POC Selector ──────────────────────────────────────────
                if (assignments.value
                    .any(
                      (a) =>
                          a.roleType.toLowerCase() == 'lead' ||
                          a.roleType.toLowerCase() == 'assistant',
                    )
                ) ...[
                  24.h,
                  Text(
                    'POINT OF CONTACT (CLIENT PDF)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: crmColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  8.h,
                  Text(
                    'Select who the client should contact. Their name & number will appear on the client PDF.',
                    style: TextStyle(
                      fontSize: 11,
                      color: crmColors.textSecondary,
                    ),
                  ),
                  12.h,
                  _buildPocSelector(
                    context,
                    crmColors,
                    assignments,
                    selectedPocId,
                  ),
                ],
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
                    availableVehicles,
                    assignArtistId,
                    assignRoleCtrl,
                    assignmentType,
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

  // ── POC picker ──────────────────────────────────────────────────────────
  Widget _buildPocSelector(
    BuildContext context,
    CrmTheme crmColors,
    ValueNotifier<List<BookingAssignment>> assignments,
    ValueNotifier<String> selectedPocId,
  ) {
    final pocCandidates = assignments.value
        .where(
          (a) =>
              (a.roleType.toLowerCase() == 'lead' ||
                  a.roleType.toLowerCase() == 'assistant') &&
              a.artistName.trim().isNotEmpty,
        )
        .toList();

    final currentPoc = pocCandidates
        .cast<BookingAssignment?>()
        .firstWhere(
          (a) => a?.employeeId == selectedPocId.value,
          orElse: () => null,
        );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: currentPoc != null
              ? Colors.teal.withValues(alpha: 0.5)
              : crmColors.border,
          width: currentPoc != null ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: currentPoc != null
            ? Colors.teal.withValues(alpha: 0.04)
            : crmColors.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            isExpanded: true,
            value: currentPoc != null ? selectedPocId.value : '',
            icon: Icon(
              Icons.contact_phone_outlined,
              size: 18,
              color:
                  currentPoc != null ? Colors.teal : crmColors.textSecondary,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            borderRadius: BorderRadius.circular(12),
            items: [
              DropdownMenuItem<String>(
                value: '',
                child: Text(
                  'No POC selected',
                  style: TextStyle(
                    fontSize: 13,
                    color: crmColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              ...pocCandidates.map(
                (a) => DropdownMenuItem<String>(
                  value: a.employeeId,
                  child: Row(
                    children: [
                      Icon(
                        a.roleType.toLowerCase() == 'lead'
                            ? Icons.star_rounded
                            : Icons.person_outline,
                        size: 15,
                        color: a.roleType.toLowerCase() == 'lead'
                            ? Colors.amber.shade700
                            : Colors.indigo,
                      ),
                      8.w,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a.artistName.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (a.phone.trim().isNotEmpty)
                              Text(
                                a.phone.trim(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: crmColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              selectedPocId.value = value ?? '';
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentBlock(
    BookingAssignment lead,
    CrmTheme crmColors,
    ValueNotifier<List<BookingAssignment>> assignments,
  ) {
    final roleTypeValue = lead.roleType.toLowerCase();
    final isLead = roleTypeValue == 'lead';
    final isDriver = roleTypeValue == 'driver';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: crmColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isLead
                    ? Colors.amber
                    : isDriver
                    ? Colors.green
                    : Colors.indigo,
                width: 4,
              ),
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
                          isLead
                              ? 'LEAD'
                              : isDriver
                              ? 'DRIVER'
                              : 'ASSISTANT',
                          style: TextStyle(
                            fontSize: 9,
                            color: isLead
                                ? Colors.amber
                                : isDriver
                                ? Colors.green
                                : Colors.indigo,
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
    List<Vehicle> availableVehicles,
    ValueNotifier<String?> selectedArtistId,
    TextEditingController roleCtrl,
    ValueNotifier<String> assignmentType,
  ) {
    final hasLead = assignments.value.any((a) => a.roleType == 'lead');

    final currentType = assignmentType.value;
    final isTypeLead = currentType == 'lead';
    final isTypeDriver = currentType == 'driver';

    final selectableStaff = availableStaff
        .where((employee) {
          final role = employee.artistRole.toLowerCase();
          if (isTypeLead) return role == 'artist';
          if (isTypeDriver) return role == 'driver';
          return role == 'assistant' || role == 'artist';
        })
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
      'assign-$currentType-${selectableStaff.map((employee) => employee.id).join(',')}',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTypeLead
            ? Colors.amber.withValues(alpha: 0.05)
            : isTypeDriver
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTypeLead
              ? Colors.amber.withValues(alpha: 0.2)
              : isTypeDriver
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.indigo.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTypeLead
                    ? 'ASSIGN LEAD ARTIST'
                    : isTypeDriver
                    ? 'ADD DRIVER'
                    : 'ADD ASSISTANT',
                style: TextStyle(
                  fontSize: 9,
                  color: isTypeLead
                      ? Colors.amber
                      : isTypeDriver
                      ? Colors.green
                      : Colors.indigoAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: [
                  _typeChip(
                    'LEAD',
                    'lead',
                    assignmentType,
                    Colors.amber,
                    hasLead ? false : true,
                  ),
                  8.w,
                  _typeChip('DRIVER', 'driver', assignmentType, Colors.green),
                  8.w,
                  _typeChip('ASST', 'assistant', assignmentType, Colors.indigo),
                ],
              ),
            ],
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
                isTypeLead
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
                isTypeLead
                    ? 'Select lead artist…'
                    : isTypeDriver
                    ? 'Select driver…'
                    : 'Select assistant…',
                crmColors,
              ).copyWith(isDense: true),
            ),
          if (!isTypeLead && !isTypeDriver) ...[
            12.h,
            TextField(
              controller: roleCtrl,
              decoration: _inputDeco(
                'Role, e.g. Hair / Draping',
                crmColors,
              ).copyWith(isDense: true),
            ),
          ],
          // ── Driver mode: show available cars ─────────────────────────
          if (isTypeDriver && availableVehicles.isNotEmpty) ...[
            12.h,
            Text(
              'AVAILABLE CARS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
                letterSpacing: 1.2,
              ),
            ),
            8.h,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableVehicles.map((vehicle) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_car_outlined,
                        size: 14,
                        color: Colors.green,
                      ),
                      6.w,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.name.isNotEmpty
                                ? vehicle.name
                                : vehicle.brand,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (vehicle.registrationNumber.isNotEmpty)
                            Text(
                              vehicle.registrationNumber,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          12.h,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (selectedArtistId.value == null) return;
                final artist = selectableStaff.cast<Employee?>().firstWhere(
                  (employee) => employee?.id == selectedArtistId.value,
                  orElse: () => null,
                );
                if (artist == null) return;

                assignments.value = [
                  ...assignments.value,
                  BookingAssignment(
                    employeeId: artist.id,
                    artistName: artist.name,
                    role: isTypeLead
                        ? 'Lead Artist'
                        : isTypeDriver
                        ? 'Driver'
                        : (roleCtrl.text.trim().isEmpty
                              ? 'Assistant'
                              : roleCtrl.text.trim()),
                    specialization: artist.specialization,
                    works: artist.works.isNotEmpty
                        ? artist.works
                        : [
                            if (artist.specialization.trim().isNotEmpty)
                              artist.specialization.trim()
                            else if (isTypeDriver)
                              'Driver',
                          ],
                    phone: artist.phone,
                    type: artist.type,
                    roleType: currentType,
                  ),
                ];

                // After adding a lead → auto-switch to assistant mode
                if (isTypeLead) {
                  assignmentType.value = 'assistant';
                }

                // Clear selection after adding
                selectedArtistId.value = null;
                roleCtrl.clear();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isTypeLead
                    ? Colors.amber
                    : isTypeDriver
                    ? Colors.green
                    : Colors.indigo,
                foregroundColor: isTypeLead ? Colors.black : Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: Text(
                isTypeLead
                    ? 'ASSIGN LEAD ARTIST'
                    : isTypeDriver
                    ? 'ASSIGN DRIVER'
                    : 'ADD ASSISTANT',
              ),
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

  Widget _buildTimeField(
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
    required bool isExtraDateEntry,
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
        if (isExtraDateEntry)
          TextFormField(
            controller: packageCtrl,
            readOnly: true,
            decoration: _inputDeco(
              '',
              crmColors,
            ).copyWith(helperText: 'Same package on this selected date.'),
          )
        else
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
                  description: selected.description,
                ),
              );
            },
            decoration: _inputDeco('Select add-on service', crmColors),
          ),
          12.h,
          Row(
            children: [
              Expanded(
                child: _AddonField(
                  label: 'PRICE',
                  initialValue: addon.amount == 0 ? '' : addon.amount.toStringAsFixed(0),
                  onChanged: (value) => onChanged(
                    addon.copyWith(amount: double.tryParse(value) ?? 0),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              12.w,
              Expanded(
                child: _AddonField(
                  label: 'NUMBER OF PERSONS',
                  initialValue: addon.persons.toString(),
                  onChanged: (value) => onChanged(
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
    FocusNode? focusNode,
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
          focusNode: focusNode,
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

  static Widget _buildDistrictDropdown(
    BuildContext context,
    CrmTheme crmColors,
    AsyncValue<List<District>> asyncDistricts,
    List<District> availableDistricts,
    ValueNotifier<String> selectedDistrictId,
    TextEditingController districtCtrl,
    TextEditingController regionCtrl,
  ) {
    final currentValue =
        availableDistricts.any(
          (district) => district.id == selectedDistrictId.value,
        )
        ? selectedDistrictId.value
        : null;

    final selectedDistrict = availableDistricts.cast<District?>().firstWhere(
      (d) => d?.id == selectedDistrictId.value,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOCATION / DISTRICT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        if (asyncDistricts.isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else if (asyncDistricts.hasError)
          TextFormField(
            controller: districtCtrl,
            decoration: _inputDeco('District', crmColors),
          )
        else ...[
          DropdownButtonFormField<String>(
            key: ValueKey(
              'booking-district-${currentValue ?? 'none'}-${availableDistricts.map((d) => d.id).join(',')}',
            ),
            initialValue: currentValue,
            items: availableDistricts
                .map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text('${d.name} (${d.regionName})'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              selectedDistrictId.value = value ?? '';
              final selected = availableDistricts.cast<District?>().firstWhere(
                (d) => d?.id == value,
                orElse: () => null,
              );
              districtCtrl.text = selected?.name ?? '';
              regionCtrl.text = selected?.regionName ?? '';
            },
            decoration: _inputDeco(
              districtCtrl.text.isEmpty ? 'Select district' : districtCtrl.text,
              crmColors,
            ),
          ),
          if (selectedDistrict != null) ...[
            6.h,
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                'Region: ${selectedDistrict.regionName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: crmColors.primary,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  static Widget _typeChip(
    String label,
    String value,
    ValueNotifier<String> state,
    Color color, [
    bool enabled = true,
  ]) {
    final isSelected = state.value == value;
    return InkWell(
      onTap: enabled ? () => state.value = value : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black : color,
            ),
          ),
        ),
      ),
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

  static List<DateTime> _replaceBookingDate(
    List<DateTime> dates,
    DateTime? originalDate,
    DateTime replacementDate,
  ) {
    if (dates.isEmpty) {
      return <DateTime>[replacementDate];
    }

    if (originalDate == null) {
      return <DateTime>[replacementDate];
    }

    final updatedDates = dates.map((date) {
      final matchesOriginal =
          date.year == originalDate.year &&
          date.month == originalDate.month &&
          date.day == originalDate.day;
      return matchesOriginal ? replacementDate : date;
    }).toList()..sort((a, b) => a.compareTo(b));

    final uniqueDates = <DateTime>[];
    for (final date in updatedDates) {
      final exists = uniqueDates.any(
        (item) =>
            item.year == date.year &&
            item.month == date.month &&
            item.day == date.day,
      );
      if (!exists) {
        uniqueDates.add(DateTime(date.year, date.month, date.day));
      }
    }
    return uniqueDates;
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

  /// Number of days a package runs. ₹3000 is charged for each of them, and the
  /// package's advance is due once per day — mirrors the backend.
  static int _bookingItemDays(BookingItem item) =>
      item.selectedDates.isEmpty ? 1 : item.selectedDates.length;

  /// Rebuilds the booking-level aggregates (total, advance, service, slots,
  /// dates, staff) from [items] so removing or editing one package never
  /// corrupts the whole booking. Mirrors the backend bookingController
  /// aggregation so local and server state stay identical.
  static Booking _withRecomputedAggregates(
    Booking booking,
    List<BookingItem> items,
  ) {
    const double extraDateChargePerPackage = 3000;

    // Distinct, chronologically-sorted union of every item's dates.
    final seen = <String>{};
    final merged = <DateTime>[];
    for (final item in items) {
      for (final d in item.selectedDates) {
        if (seen.add('${d.year}-${d.month}-${d.day}')) {
          merged.add(DateTime(d.year, d.month, d.day));
        }
      }
    }
    merged.sort((a, b) => a.compareTo(b));

    final addonsTotal = booking.addons.fold<double>(
      0.0,
      (sum, a) => sum + (a.amount * a.persons),
    );
    final dayCharge = items.fold<double>(
      0.0,
      (s, i) => s + (_bookingItemDays(i) * extraDateChargePerPackage),
    );
    final total =
        items.fold<double>(0.0, (s, i) => s + i.totalPrice) +
        addonsTotal +
        dayCharge;
    final advance = items.fold<double>(
      0.0,
      (s, i) => s + (i.advanceAmount * _bookingItemDays(i)),
    );

    final service = <String>{
      for (final i in items)
        if (i.service.trim().isNotEmpty) i.service.trim(),
    }.join(' + ');
    final slot = <String>{
      for (final i in items)
        if (i.eventSlot.trim().isNotEmpty) i.eventSlot.trim(),
    }.join(' | ');

    final discount = booking.discountType == 'percent'
        ? total * (booking.discountValue.clamp(0.0, 100.0) / 100)
        : booking.discountValue.clamp(0.0, total);

    return booking.copyWith(
      bookingItems: items,
      totalPrice: total,
      advanceAmount: advance,
      discountAmount: discount,
      service: service.isEmpty ? booking.service : service,
      eventSlot: slot.isEmpty ? booking.eventSlot : slot,
      selectedDates: merged.isEmpty ? booking.selectedDates : merged,
      serviceStart: merged.isEmpty ? booking.serviceStart : merged.first,
      serviceEnd: merged.isEmpty ? booking.serviceEnd : merged.last,
      assignedStaff: _summarizeBookingItemAssignments(items),
    );
  }

  /// Removes one package (booking item) from a multi-item booking and
  /// persists the recalculated booking. The remaining packages stay as a
  /// single invoice.
  Future<void> _removeBookingItem(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
    int index,
    int currentItemIndex,
  ) async {
    if (index < 0 || index >= booking.bookingItems.length) return;
    final item = booking.bookingItems[index];
    final name = item.service.trim().isEmpty
        ? 'Package ${index + 1}'
        : item.service.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove package?'),
        content: Text(
          'Remove "$name" from this booking? The remaining packages stay as '
          'one invoice and the total is recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final newItems = [...booking.bookingItems]..removeAt(index);
    final updated = _withRecomputedAggregates(booking, newItems);

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(bookingProvider.notifier).updateBooking(updated);
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to remove package: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Package removed.')));

    // Invalidate singleBookingProvider so that when we navigate back to the
    // booking detail the page fetches fresh data and doesn't show the removed
    // package from the stale local cache.
    ref.invalidate(singleBookingProvider(booking.id));

    // Indices shift after removal, so any `?entry=` in the URL may now point
    // at the wrong package. Reset to the booking's default (first) entry.
    context.go('/booking/manage/${booking.id}');
  }

  /// Adds a new package (booking item) to an existing booking. The new
  /// package joins the same invoice and appears as its own calendar slot.
  Future<void> _addBookingItem(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final packages =
        ref.read(packagesProvider).value ?? const <ServicePackage>[];
    final messenger = ScaffoldMessenger.of(context);
    if (packages.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No service packages available.')),
      );
      return;
    }

    final slotCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final advanceCtrl = TextEditingController();
    String? pkgId;
    DateTime date = booking.selectedDates.isNotEmpty
        ? booking.selectedDates.first
        : booking.bookingDate;

    final result = await showDialog<BookingItem>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Add package to booking'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: pkgId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Package'),
                      items: [
                        for (final p in packages)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        pkgId = v;
                        final p = packages.firstWhere((e) => e.id == v);
                        priceCtrl.text = p
                            .effectivePriceForDistrict(booking.districtId)
                            .toStringAsFixed(0);
                        advanceCtrl.text =
                            p.advanceAmount.toStringAsFixed(0);
                      }),
                    ),
                    12.h,
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => date = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date'),
                        child: Text('${date.day}/${date.month}/${date.year}'),
                      ),
                    ),
                    12.h,
                    TextField(
                      controller: slotCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Slot (optional, e.g. Morning)'),
                    ),
                    12.h,
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (₹)'),
                    ),
                    12.h,
                    TextField(
                      controller: advanceCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Advance (₹)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (pkgId == null) return;
                    final p = packages.firstWhere((e) => e.id == pkgId);
                    final price = double.tryParse(priceCtrl.text.trim()) ??
                        p.effectivePriceForDistrict(booking.districtId);
                    final adv = double.tryParse(advanceCtrl.text.trim()) ??
                        p.advanceAmount;
                    Navigator.of(ctx).pop(
                      BookingItem(
                        packageId: p.id,
                        service: p.name,
                        eventSlot: slotCtrl.text.trim(),
                        selectedDates: [
                          DateTime(date.year, date.month, date.day),
                        ],
                        totalPrice: price,
                        advanceAmount: adv,
                        assignedStaff: const [],
                      ),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    slotCtrl.dispose();
    priceCtrl.dispose();
    advanceCtrl.dispose();
    if (result == null || !context.mounted) return;

    final newItems = [...booking.bookingItems, result];
    final updated = _withRecomputedAggregates(booking, newItems);
    try {
      await ref.read(bookingProvider.notifier).updateBooking(updated);
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to add package: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Package added.')));
    context.go('/booking/manage/${booking.id}');
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

class _AddonField extends StatefulWidget {
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  const _AddonField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.keyboardType,
  });

  @override
  State<_AddonField> createState() => _AddonFieldState();
}

class _AddonFieldState extends State<_AddonField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _AddonField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        4.h,
        TextFormField(
          controller: _controller,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          decoration: ManageBookingScreen._inputDeco('', crmColors),
        ),
      ],
    );
  }
}

// ── Migration helper ──────────────────────────────────────────────────────────
/// Converts a booking's existing outfit data into a [List<OutfitLook>].
/// If the booking already has structured looks, uses those directly.
/// Otherwise, migrates the legacy `outfitDetails` string into a single look.
List<OutfitLook> _migrateOutfitLooks(Booking? booking) {
  if (booking == null) return [const OutfitLook()];
  if (booking.outfitLooks.isNotEmpty) {
    return List<OutfitLook>.from(booking.outfitLooks);
  }
  if (booking.outfitDetails.isNotEmpty) {
    return [OutfitLook(outfitDetails: booking.outfitDetails)];
  }
  return [const OutfitLook()];
}

// ── Outfit Looks Editor ───────────────────────────────────────────────────────
/// A self-contained widget that manages a list of [OutfitLook] entries.
/// Each look shows a label, outfit description textarea, and a Google Maps URL
/// field with a paste-from-clipboard button and a launch button.
/// An "＋ Add Look" button appends a new empty look.
class _OutfitLooksEditor extends StatefulWidget {
  final List<OutfitLook> looks;
  final ValueChanged<List<OutfitLook>> onChanged;

  const _OutfitLooksEditor({
    required this.looks,
    required this.onChanged,
  });

  @override
  State<_OutfitLooksEditor> createState() => _OutfitLooksEditorState();
}

class _OutfitLooksEditorState extends State<_OutfitLooksEditor> {
  // Persistent controllers per look, keyed by index. Rebuilt when looks change.
  final List<TextEditingController> _labelCtrls = [];
  final List<TextEditingController> _detailsCtrls = [];
  final List<TextEditingController> _mapUrlCtrls = [];

  @override
  void initState() {
    super.initState();
    _syncControllers(widget.looks);
  }

  @override
  void didUpdateWidget(_OutfitLooksEditor old) {
    super.didUpdateWidget(old);
    if (old.looks.length != widget.looks.length) {
      _syncControllers(widget.looks);
    }
  }

  void _syncControllers(List<OutfitLook> looks) {
    // Dispose extras
    while (_labelCtrls.length > looks.length) {
      _labelCtrls.removeLast().dispose();
      _detailsCtrls.removeLast().dispose();
      _mapUrlCtrls.removeLast().dispose();
    }
    // Add missing
    for (int i = _labelCtrls.length; i < looks.length; i++) {
      _labelCtrls.add(TextEditingController(text: looks[i].lookLabel));
      _detailsCtrls.add(TextEditingController(text: looks[i].outfitDetails));
      _mapUrlCtrls.add(TextEditingController(text: looks[i].mapUrl));
    }
  }

  @override
  void dispose() {
    for (final c in _labelCtrls) { c.dispose(); }
    for (final c in _detailsCtrls) { c.dispose(); }
    for (final c in _mapUrlCtrls) { c.dispose(); }
    super.dispose();
  }

  List<OutfitLook> _buildLooks() {
    final updated = <OutfitLook>[];
    for (int i = 0; i < _labelCtrls.length; i++) {
      updated.add(OutfitLook(
        lookLabel: _labelCtrls[i].text.trim(),
        outfitDetails: _detailsCtrls[i].text.trim(),
        mapUrl: _mapUrlCtrls[i].text.trim(),
      ));
    }
    return updated;
  }

  void _notify() => widget.onChanged(_buildLooks());

  void _addLook() {
    _labelCtrls.add(TextEditingController());
    _detailsCtrls.add(TextEditingController());
    _mapUrlCtrls.add(TextEditingController());
    setState(() {});
    _notify();
  }

  void _removeLook(int index) {
    _labelCtrls[index].dispose();
    _detailsCtrls[index].dispose();
    _mapUrlCtrls[index].dispose();
    _labelCtrls.removeAt(index);
    _detailsCtrls.removeAt(index);
    _mapUrlCtrls.removeAt(index);
    setState(() {});
    _notify();
  }

  Future<void> _pasteMapUrl(int index) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _mapUrlCtrls[index].text = text;
      _notify();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty.')),
      );
    }
  }

  Future<void> _openMapUrl(int index) async {
    final url = _mapUrlCtrls[index].text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || url.isEmpty) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final looks = _labelCtrls.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          'OUTFIT LOOKS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        8.h,

        // Look cards
        for (int i = 0; i < looks; i++) ...[
          _LookCard(
            index: i,
            totalLooks: looks,
            labelCtrl: _labelCtrls[i],
            detailsCtrl: _detailsCtrls[i],
            mapUrlCtrl: _mapUrlCtrls[i],
            crmColors: crmColors,
            onChanged: _notify,
            onRemove: looks > 1 ? () => _removeLook(i) : null,
            onPasteMap: () => _pasteMapUrl(i),
            onOpenMap: _mapUrlCtrls[i].text.isNotEmpty
                ? () => _openMapUrl(i)
                : null,
          ),
          if (i < looks - 1) 10.h,
        ],

        12.h,

        // Add Look button
        OutlinedButton.icon(
          onPressed: _addLook,
          icon: const Icon(Icons.add, size: 16),
          label: const Text(
            '+ Add Look',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8B5CF6),
            side: const BorderSide(color: Color(0xFF8B5CF6)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single look card shown inside [_OutfitLooksEditor].
class _LookCard extends StatelessWidget {
  final int index;
  final int totalLooks;
  final TextEditingController labelCtrl;
  final TextEditingController detailsCtrl;
  final TextEditingController mapUrlCtrl;
  final CrmTheme crmColors;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final VoidCallback onPasteMap;
  final VoidCallback? onOpenMap;

  const _LookCard({
    required this.index,
    required this.totalLooks,
    required this.labelCtrl,
    required this.detailsCtrl,
    required this.mapUrlCtrl,
    required this.crmColors,
    required this.onChanged,
    required this.onRemove,
    required this.onPasteMap,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final lookNumber = index + 1;
    return Container(
      decoration: BoxDecoration(
        color: crmColors.surface,
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: "Look N" label + editable name + remove button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Look $lookNumber',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                8.w,
                Expanded(
                  child: TextField(
                    controller: labelCtrl,
                    onChanged: (_) => onChanged(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: crmColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Bridal Look, Reception...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: crmColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: Colors.red.shade400,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onRemove,
                    tooltip: 'Remove this look',
                  ),
              ],
            ),
          ),

          // Body: outfit details + map URL
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Outfit details text area
                Text(
                  'OUTFIT DETAILS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: crmColors.textSecondary,
                    letterSpacing: 1.1,
                  ),
                ),
                4.h,
                TextFormField(
                  controller: detailsCtrl,
                  onChanged: (_) => onChanged(),
                  maxLines: 3,
                  minLines: 2,
                  style: TextStyle(fontSize: 12, color: crmColors.textPrimary),
                  decoration: ManageBookingScreen._inputDeco(
                    'Describe the outfit for this look...',
                    crmColors,
                  ),
                ),

                12.h,

                // Location map URL row
                Text(
                  'LOCATION (GOOGLE MAPS LINK)',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: crmColors.textSecondary,
                    letterSpacing: 1.1,
                  ),
                ),
                4.h,
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: mapUrlCtrl,
                        onChanged: (_) => onChanged(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2563EB),
                        ),
                        decoration: ManageBookingScreen._inputDeco(
                          'Paste Google Maps link for this look\'s location',
                          crmColors,
                        ).copyWith(
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ),
                    8.w,
                    // Paste button
                    Tooltip(
                      message: 'Paste from clipboard',
                      child: InkWell(
                        onTap: onPasteMap,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.content_paste_rounded,
                            size: 16,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ),
                    // Open link button (only if URL is set)
                    if (onOpenMap != null) ...[
                      6.w,
                      Tooltip(
                        message: 'Open in Maps',
                        child: InkWell(
                          onTap: onOpenMap,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

