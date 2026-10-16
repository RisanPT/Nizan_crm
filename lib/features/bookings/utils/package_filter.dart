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
