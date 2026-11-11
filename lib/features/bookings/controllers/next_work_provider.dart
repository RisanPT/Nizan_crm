import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/bookings/data/next_work_hint.dart';
import 'package:nizan_crm/features/bookings/services/booking_service.dart';

/// The artist's "next work" hints for the works on screen. Keyed by the comma-joined,
/// sorted booking ids so the same list is one cached request. A failure here must never
/// break the works list — callers read it with `.value` and show nothing when it is absent.
final nextWorkHintsProvider = FutureProvider.autoDispose.family<NextWorkHints, String>((ref, idsKey) {
  final ids = idsKey.split(',').where((s) => s.isNotEmpty).toList();
  return ref.watch(bookingServiceProvider).getNextWorkHints(ids);
});

/// The family key for [bookingIds].
String nextWorkKey(Iterable<String> bookingIds) => (bookingIds.toSet().toList()..sort()).join(',');
