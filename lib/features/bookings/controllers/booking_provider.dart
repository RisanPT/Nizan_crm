import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nizan_crm/features/bookings/services/booking_service.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/finance/controllers/sales_report_provider.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';

part 'booking_provider.g.dart';

class PaginatedBookingsParams {
  final int page;
  final int limit;
  final String search;
  final bool duplicatesOnly;
  final String? financialYear;
  final String? employeeId;
  final String? zoneId;
  final String? stateId;
  final String? regionId;
  final String? districtId;
  final String? pincodeId;
  final String? dateBasis;
  final String? month;
  final bool onlyWithMapLink;
  final String? status;
  // Explicit event/booking date range (yyyy-MM-dd) for the date search filter.
  final String? from;
  final String? to;
  // Filter by the salesperson credited with the booking (Booking.salesPersonId).
  final String? salesPersonId;
  // Filter by the user who ENTERED the booking (Booking.createdBy) — the
  // "Added By" filter (sales / CRM / managers / admin all enter bookings).
  final String? createdBy;

  const PaginatedBookingsParams({
    required this.page,
    required this.limit,
    this.search = '',
    this.duplicatesOnly = false,
    this.financialYear,
    this.employeeId,
    this.zoneId,
    this.stateId,
    this.regionId,
    this.districtId,
    this.pincodeId,
    this.dateBasis,
    this.month,
    this.onlyWithMapLink = false,
    this.status,
    this.from,
    this.to,
    this.salesPersonId,
    this.createdBy,
  });

  @override
  bool operator ==(Object other) {
    return other is PaginatedBookingsParams &&
        other.page == page &&
        other.limit == limit &&
        other.search == search &&
        other.duplicatesOnly == duplicatesOnly &&
        other.financialYear == financialYear &&
        other.employeeId == employeeId &&
        other.zoneId == zoneId &&
        other.stateId == stateId &&
        other.regionId == regionId &&
        other.districtId == districtId &&
        other.pincodeId == pincodeId &&
        other.dateBasis == dateBasis &&
        other.month == month &&
        other.onlyWithMapLink == onlyWithMapLink &&
        other.status == status &&
        other.from == from &&
        other.to == to &&
        other.salesPersonId == salesPersonId &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode => Object.hash(
    page,
    limit,
    search,
    duplicatesOnly,
    financialYear,
    employeeId,
    zoneId,
    stateId,
    regionId,
    districtId,
    pincodeId,
    dateBasis,
    month,
    onlyWithMapLink,
    status,
    from,
    to,
    salesPersonId,
    createdBy,
  );
}

final bookingsRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final paginatedBookingsProvider =
    FutureProvider.family<PaginatedBookingsResponse, PaginatedBookingsParams>((
      ref,
      params,
    ) async {
      ref.watch(bookingsRefreshTriggerProvider);
      final authSession = ref.watch(authSessionProvider);
      final role = AppRole.fromString(authSession?.role);

      var zoneId = params.zoneId;
      var stateId = params.stateId;
      var regionId = params.regionId;
      var districtId = params.districtId;
      var pincodeId = params.pincodeId;

      if (!role.isFullAccess && role != AppRole.artist) {
        if (authSession != null) {
          if (authSession.zoneId.isNotEmpty) zoneId = authSession.zoneId;
          if (authSession.stateId.isNotEmpty) stateId = authSession.stateId;
          if (authSession.regionId.isNotEmpty) regionId = authSession.regionId;
          if (authSession.districtId.isNotEmpty) districtId = authSession.districtId;
          if (authSession.pincodeId.isNotEmpty) pincodeId = authSession.pincodeId;
        }
      }

      return ref.watch(bookingServiceProvider).getPaginatedBookings(
            page: params.page,
            limit: params.limit,
            search: params.search,
            duplicatesOnly: params.duplicatesOnly,
            financialYear: params.financialYear,
            employeeId: params.employeeId,
            zoneId: zoneId,
            stateId: stateId,
            regionId: regionId,
            districtId: districtId,
            pincodeId: pincodeId,
            dateBasis: params.dateBasis,
            month: params.month,
            onlyWithMapLink: params.onlyWithMapLink,
            status: params.status,
            from: params.from,
            to: params.to,
            salesPersonId: params.salesPersonId,
            createdBy: params.createdBy,
          );
    });

final artistAssignedWorksProvider =
    FutureProvider.family<PaginatedBookingsResponse, int>((ref, page) async {
      final authSession = ref.watch(authSessionProvider);
      final employeeId = authSession?.employeeId ?? '';

      if (employeeId.isEmpty) {
        return const PaginatedBookingsResponse(
          items: [],
          page: 1,
          limit: 20,
          totalItems: 0,
          totalPages: 1,
          summary: BookingPageSummary(
            totalSales: 0,
            totalAdvance: 0,
            completedCount: 0,
            cancelledCount: 0,
          ),
        );
      }

      return ref.watch(
        paginatedBookingsProvider(
          PaginatedBookingsParams(
            page: page,
            limit: 20,
            employeeId: employeeId,
          ),
        ).future,
      );
    });

final singleBookingProvider = FutureProvider.autoDispose.family<Booking?, String>((ref, id) async {
  if (id.isEmpty || id == 'new') return null;

  // Prefer the in-memory cache — it reflects local optimistic edits and is
  // instant. Watch it so this provider re-runs when the cache updates.
  final cached = (ref.watch(bookingProvider).value ?? const <Booking>[])
      .cast<Booking?>()
      .firstWhere((b) => b?.id == id, orElse: () => null);
  if (cached != null) return cached;

  // Not in the cache — e.g. opened from the server-paginated Sales list, whose
  // rows aren't guaranteed to be in the all-bookings cache. Fetch it directly
  // from the server by id so the manage screen never wrongly says "not found".
  try {
    return await ref.read(bookingServiceProvider).getBookingById(id);
  } catch (e) {
    // Only a real 404 means "no such booking". Anything else (offline, server
    // error, no permission) must surface as an error so the screen can say so
    // and offer a retry, instead of wrongly claiming the booking doesn't exist.
    if (errorKind(e) == 1) return null;
    rethrow;
  }
});

@Riverpod(keepAlive: true)
class BookingNotifier extends _$BookingNotifier {
  @override
  FutureOr<List<Booking>> build() async {
    return _fetchBookings();
  }

  Future<List<Booking>> _fetchBookings() async {
    final service = ref.watch(bookingServiceProvider);
    final bookings = await service.getBookings();
    return _syncAutoCompletedBookings(service, bookings);
  }

  Future<List<Booking>> _syncAutoCompletedBookings(
    BookingService service,
    List<Booking> bookings,
  ) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    final staleConfirmedBookings = bookings
        .where(
          (booking) =>
              booking.status.toLowerCase() == 'confirmed' &&
              DateTime(
                booking.serviceEnd.year,
                booking.serviceEnd.month,
                booking.serviceEnd.day,
              ).isBefore(startOfToday),
        )
        .toList();

    if (staleConfirmedBookings.isEmpty) {
      return bookings;
    }

    final updatedById = <String, Booking>{};

    for (final booking in staleConfirmedBookings) {
      try {
        final updated = await service.updateBooking(
          booking.copyWith(status: 'completed'),
        );
        updatedById[updated.id] = updated;
      } catch (_) {
        updatedById[booking.id] = booking.copyWith(status: 'completed');
      }
    }

    return [for (final booking in bookings) updatedById[booking.id] ?? booking];
  }

  Future<Booking> addBooking(Booking booking) async {
    final service = ref.read(bookingServiceProvider);

    try {
      final createdBooking = await service.createBooking(booking);
      if (ref.mounted) {
        state = AsyncData([...state.value ?? [], createdBooking]);
        _refreshDependents();
      }
      return createdBooking;
    } catch (_) {
      // Leave the cached list untouched: a failed create must not blank out
      // the bookings list on every screen. The caller shows the error.
      rethrow;
    }
  }

  Future<Booking> updateBooking(Booking booking) async {
    final service = ref.read(bookingServiceProvider);
    final previousState = state;
    final currentBookings = state.value ?? [];

    // Optimistic update immediately with user-provided data
    state = AsyncData([
      for (final existing in currentBookings)
        if (existing.id == booking.id) booking else existing,
    ]);

    try {
      // Send to server but keep local data as source of truth.
      // The server may recalculate totalPrice differently (base only),
      // so we don't overwrite local state with server response — except the
      // transient reviewUrl (returned when a booking is saved as completed),
      // which we merge onto the local booking so the completion WhatsApp
      // message can carry the review link.
      final serverBooking = await service.updateBooking(booking);
      final merged = booking.copyWith(reviewUrl: serverBooking.reviewUrl);
      if (ref.mounted) {
        // Re-apply local booking to make sure state is consistent
        state = AsyncData([
          for (final existing in state.value ?? [])
            if (existing.id == booking.id) merged else existing,
        ]);
        _refreshDependents(bookingId: booking.id);
      }
      return merged;
    } catch (_) {
      if (ref.mounted) {
        // Roll the optimistic edit back. Deliberately NOT AsyncError: one
        // failed save must not blank out the bookings list on every screen.
        // The caller shows the error.
        state = previousState;
      }
      rethrow;
    }
  }

  Future<void> removeBooking(String id) async {
    final service = ref.read(bookingServiceProvider);

    // Optimistic update — remove from the non-paginated cache immediately.
    final previousState = state;
    state = AsyncData((state.value ?? []).where((b) => b.id != id).toList());

    try {
      await service.deleteBooking(id);
      if (ref.mounted) {
        // Paginated lists, the deleted id's detail cache, clients, slots…
        _refreshDependents(bookingId: id);
      }
    } catch (err) {
      if (ref.mounted) {
        // Roll the optimistic removal back. Deliberately NOT AsyncError: one
        // failed delete must not blank out the bookings list on every screen.
        state = previousState;
      }
      // Rethrow so the caller can tell the user it failed — swallowing this
      // made the UI report "deleted successfully" while the booking remained.
      rethrow;
    }
  }

  /// Everything `ref.refreshData.bookings()` refreshes EXCEPT this notifier:
  /// its in-memory list was already updated (insert/replace/remove) and is the
  /// source of truth for locally-priced edits, so re-fetching it would discard
  /// that and re-run the auto-complete sync.
  void _refreshDependents({String? bookingId}) {
    ref.read(bookingsRefreshTriggerProvider.notifier).state++;
    // ALL family instances — every list/summary screen (sales invoices,
    // dashboards, accounts, artist works…) refetches.
    ref.invalidate(paginatedBookingsProvider);
    ref.invalidate(artistAssignedWorksProvider);
    if (bookingId != null) ref.invalidate(singleBookingProvider(bookingId));
    ref.invalidate(bookingCalendarProvider);
    ref.invalidate(salesReportProvider);
    ref.refreshData.customers(); // clients auto-created / booking counts
    ref.refreshData.slots(); // slot availability
    ref.refreshData.leads(); // booking a lead converts it
  }

  List<Booking> bookingsForDate(DateTime date) {
    return (state.value ?? []).where((b) => b.isOnDate(date)).toList();
  }
}
