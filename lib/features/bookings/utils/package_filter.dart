import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/models/service_package.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/services/package_service.dart';

/// True when [booking] uses [pkg] on any of its lines — by package id, or by
/// name for imported / older bookings that only carry the service name.
/// Same rule as the server's `packageId` filter (getPaginatedBookings).
bool bookingUsesPackage(Booking booking, ServicePackage pkg) {
  final name = pkg.name.trim().toLowerCase();
  bool sameName(String s) => name.isNotEmpty && s.trim().toLowerCase() == name;
  if (booking.packageId == pkg.id || sameName(booking.service)) return true;
  return booking.bookingItems
      .any((i) => i.packageId == pkg.id || sameName(i.service));
}

bool _lineIsPackage(String packageId, String service, ServicePackage pkg) {
  final name = pkg.name.trim().toLowerCase();
  return packageId == pkg.id ||
      (name.isNotEmpty && service.trim().toLowerCase() == name);
}

/// How many times [booking] uses [pkg]: one per matching line (a customer can
/// take the same package on several dates). Older single-package bookings
/// without lines count as 1. 0 when the booking doesn't use it at all.
int bookingPackageCount(Booking booking, ServicePackage pkg) {
  final lines = booking.bookingItems
      .where((i) => _lineIsPackage(i.packageId, i.service, pkg))
      .length;
  if (lines > 0) return lines;
  return bookingUsesPackage(booking, pkg) ? 1 : 0;
}

/// Total number of [pkg] packages across [bookings] (sum of per-booking counts).
int totalPackageCount(Iterable<Booking> bookings, ServicePackage pkg) =>
    bookings.fold(0, (sum, b) => sum + bookingPackageCount(b, pkg));

/// What a booking row shows while filtering by [pkg]: only that package, with
/// "× n" when the customer took it more than once — never the whole
/// "A + B + C" list.
String packageLabelFor(Booking booking, ServicePackage pkg) {
  final line = booking.bookingItems
      .where((i) => _lineIsPackage(i.packageId, i.service, pkg))
      .map((i) => i.service.trim())
      .where((s) => s.isNotEmpty)
      .firstOrNull;
  final name = line ?? pkg.name.trim();
  final n = bookingPackageCount(booking, pkg);
  return n > 1 ? '$name × $n' : name;
}

/// A copy of [booking] whose `service` reads as [packageLabelFor] — for report
/// tables, which print `booking.service`. Amounts stay the full booking totals.
Booking withOnlyPackage(Booking booking, ServicePackage pkg) =>
    booking.copyWith(service: packageLabelFor(booking, pkg));

/// "Package: All" dropdown listing the packages already added in the CRM.
/// [value] is a package id ('' = all).
class PackageFilterDropdown extends ConsumerWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const PackageFilterDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final packages = [...(ref.watch(packagesProvider).value ?? const <ServicePackage>[])]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final known = packages.any((p) => p.id == value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: DropdownButton<String>(
        value: value.isEmpty || !known ? '' : value,
        menuMaxHeight: 420,
        onChanged: (v) => onChanged(v ?? ''),
        items: [
          const DropdownMenuItem(
            value: '',
            child: Text('Package: All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final p in packages)
            DropdownMenuItem(
              value: p.id,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(p.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
        style: TextStyle(color: crm.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
        underline: const SizedBox(),
        icon: const Icon(Icons.inventory_2_outlined, size: 18),
      ),
    );
  }
}
