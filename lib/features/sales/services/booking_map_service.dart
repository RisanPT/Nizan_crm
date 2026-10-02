import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/sales/data/booking_map.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Query for the Booking Map: an inclusive date range (null = open) and which
/// date it's measured on — the event date or the day the booking was added.
typedef BookingMapQuery = ({DateTime? from, DateTime? to, String basis});

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final bookingMapProvider = FutureProvider.autoDispose
    .family<BookingMapData, BookingMapQuery>((ref, q) async {
  try {
    final res = await ref.watch(dioProvider).get(
      '/bookings/map',
      queryParameters: {
        'basis': q.basis,
        if (q.from != null) 'from': _ymd(q.from!),
        if (q.to != null) 'to': _ymd(q.to!),
      },
    );
    return BookingMapData.fromJson((res.data as Map).cast<String, dynamic>());
  } catch (e) {
    throw AppException(e, action: 'load the booking map');
  }
});
