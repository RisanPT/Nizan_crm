import 'package:intl/intl.dart';

import 'package:nizan_crm/core/utils/export_utils.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

// "Second look" = the extra-look add-ons: Hindu extra look 1-3 and Christian
// Manthrakodi look 1-3. Add-ons are admin-managed records, so they are
// recognised by name; adjust this pattern if those add-ons are ever renamed.
final RegExp _secondLookRx = RegExp(
  r'manthra?\s*kodi|mantra\s*kodi|(hindu|extra|second|2nd)\W+(\w+\W+){0,3}look',
  caseSensitive: false,
);

bool isSecondLookAddon(BookingAddon a) => _secondLookRx.hasMatch(a.service);

/// Every add-on on the booking: booking-level plus those inside each package
/// (multi-package bookings), without exact duplicates.
List<BookingAddon> bookingAddons(Booking b) {
  final seen = <String>{};
  final out = <BookingAddon>[];
  void add(BookingAddon a) {
    final key = '${a.service}|${a.amount}|${a.persons}|${a.description}';
    if (seen.add(key)) out.add(a);
  }

  for (final a in b.addons) {
    add(a);
  }
  for (final item in b.bookingItems) {
    for (final a in item.addons) {
      add(a);
    }
  }
  return out;
}

bool tookSecondLook(Booking b) => bookingAddons(b).any(isSecondLookAddon);

/// One package taken in a booking.
class PackageLine {
  const PackageLine({
    required this.name,
    required this.slot,
    required this.dates,
    required this.price,
  });
  final String name;
  final String slot;
  final List<DateTime> dates;
  final double price;
}

List<PackageLine> bookingPackages(Booking b) {
  if (b.bookingItems.isNotEmpty) {
    return [
      for (final i in b.bookingItems)
        PackageLine(name: i.service, slot: i.eventSlot, dates: i.selectedDates, price: i.totalPrice),
    ];
  }
  return [
    PackageLine(name: b.service, slot: b.eventSlot, dates: b.selectedDates, price: b.totalPrice),
  ];
}

final DateFormat _day = DateFormat('d MMM yyyy');

String _dates(List<DateTime> d) => d.map(_day.format).join(', ');

String addonLabel(BookingAddon a) =>
    '${a.service} (₹${a.amount.toStringAsFixed(0)} × ${a.persons} ${a.persons == 1 ? 'person' : 'people'})';

String packageLabel(PackageLine p) {
  final parts = <String>[
    p.name.isEmpty ? 'Package' : p.name,
    if (p.slot.isNotEmpty) p.slot,
    if (p.dates.isNotEmpty) _dates(p.dates),
    if (p.price > 0) '₹${p.price.toStringAsFixed(0)}',
  ];
  return parts.join(' · ');
}

/// Downloads the given bookings as a CSV with package and add-on details.
Future<void> exportBookingsCsv(
  List<Booking> bookings, {
  required String periodLabel,
  required bool secondLookOnly,
}) async {
  double balanceOf(Booking b) {
    final v = b.totalPrice - b.advanceAmount - b.discountAmount;
    return v > 0 ? v : 0.0;
  }

  final rows = <List<dynamic>>[
    [
      'Booking No',
      'Customer',
      'Phone',
      'Email',
      'Culture',
      'Status',
      'Event date',
      'Booked on',
      'Packages (name · slot · dates · price)',
      'Second-look add-ons',
      'Other add-ons',
      'Total (₹)',
      'Advance (₹)',
      'Discount (₹)',
      'Balance (₹)',
      'District',
      'Address',
      'Created by',
    ],
    for (final b in bookings)
      () {
        final addons = bookingAddons(b);
        return [
          b.displayBookingNumber,
          b.customerName,
          b.phone,
          b.email,
          b.culture,
          b.status,
          _day.format(b.bookingDate),
          b.createdAt == null ? '' : _day.format(b.createdAt!),
          bookingPackages(b).map(packageLabel).join(' | '),
          addons.where(isSecondLookAddon).map(addonLabel).join(' | '),
          addons.where((a) => !isSecondLookAddon(a)).map(addonLabel).join(' | '),
          b.totalPrice,
          b.advanceAmount,
          b.discountAmount,
          balanceOf(b),
          b.district,
          b.address,
          b.createdByName,
        ];
      }(),
  ];

  final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
  final safePeriod = periodLabel.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
  final kind = secondLookOnly ? 'second-look-bookings' : 'bookings';
  await ExportUtils.exportCsv('$kind-$safePeriod-$stamp.csv', rows);
}
