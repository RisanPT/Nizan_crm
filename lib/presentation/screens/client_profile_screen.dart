import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/add_booking_mode_sheet.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import '../../core/utils/kerala_pincodes.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';

/// Last 10 digits of a phone number, ignoring spaces/dashes/country codes —
/// the reliable key for matching a booking to a client.
String clientPhoneKey(String? p) {
  final digits = (p ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

/// Whether [b] belongs to the client identified by [phoneKey]/[nameLower].
/// Phone is authoritative; name is a fallback for records without a phone.
bool bookingMatchesClient(
  Booking b, {
  required String phoneKey,
  required String nameLower,
}) {
  final byPhone = phoneKey.length >= 10 && clientPhoneKey(b.phone) == phoneKey;
  final byName =
      nameLower.isNotEmpty && b.customerName.trim().toLowerCase() == nameLower;
  return byPhone || byName;
}

class ClientProfileScreen extends HookConsumerWidget {
  final String clientId;

  const ClientProfileScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isDesktop = ResponsiveBuilder.isDesktop(context);
    final isMobile = ResponsiveBuilder.isMobile(context);

    // ── Load Customer from provider ─────────────────────────────────────────
    final asyncCustomers = ref.watch(customersProvider);
    final customer = asyncCustomers.value?.cast<Customer?>().firstWhere(
          (c) => c?.id == clientId,
          orElse: () => null,
        );

    // ── Load bookings for this customer ─────────────────────────────────────
    // Match on the last 10 phone digits (reliable across formatting), falling
    // back to an exact name match for clients created before phones were saved.
    final custPhoneKey = clientPhoneKey(customer?.phone);
    final custName = (customer?.name ?? '').trim().toLowerCase();
    final asyncBookings = ref.watch(bookingProvider);
    final bookings =
        (asyncBookings.value ?? [])
            .where((b) =>
                customer != null &&
                bookingMatchesClient(b,
                    phoneKey: custPhoneKey, nameLower: custName))
            .toList()
          ..sort((a, b) => b.serviceStart.compareTo(a.serviceStart));

    // Financial rollup + geography derived from this client's bookings.
    final totalSpend = bookings.fold<double>(0, (s, b) => s + b.totalPrice);
    final totalAdvance = bookings.fold<double>(0, (s, b) => s + b.advanceAmount);
    final totalBalance = bookings.fold<double>(0, (s, b) => s + b.balanceDue);
    // Newest booking that carries geography (bookings are sorted newest-first).
    Booking? latestWithGeo;
    for (final b in bookings) {
      if (b.address.trim().isNotEmpty || b.district.trim().isNotEmpty) {
        latestWithGeo = b;
        break;
      }
    }
    final clientAddress = (customer?.address ?? '').trim().isNotEmpty
        ? customer!.address!.trim()
        : (latestWithGeo?.address ?? '').trim();
    final clientPincode = (customer?.pincode ?? '').trim().isNotEmpty
        ? customer!.pincode!.trim()
        : (latestWithGeo?.pincode ?? '').trim();
    // The district is derived from the client's PINCODE (authoritative), falling
    // back to whatever the booking recorded when the pincode can't be resolved.
    final pinDistrict = keralaDistrict(clientPincode);
    final effectiveDistrict = (pinDistrict != null && pinDistrict.isNotEmpty)
        ? pinDistrict
        : (latestWithGeo?.district ?? '').trim();
    final bookingRegion = (latestWithGeo?.region ?? '').trim();
    final locationParts = <String>[
      if (effectiveDistrict.isNotEmpty) effectiveDistrict,
      // Skip the region when it just repeats the district.
      if (bookingRegion.isNotEmpty &&
          bookingRegion.toLowerCase() != effectiveDistrict.toLowerCase())
        bookingRegion,
    ];
    final clientLocation = locationParts.join(', ');

    // ── Edit dialog state ───────────────────────────────────────────────────
    Future<void> showEditDialog(Customer current) async {
      final nameCtrl = TextEditingController(text: current.name);
      final phoneCtrl = TextEditingController(text: current.phone ?? '');
      final emailCtrl = TextEditingController(
          text: current.email.contains('@placeholder') ? '' : current.email);
      String selectedStatus = current.status;
      const statuses = ['Active', 'Inactive', 'Prospect'];

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Edit Client'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  16.h,
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  16.h,
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    items: statuses
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedStatus = v!),
                    decoration: const InputDecoration(labelText: 'Status'),
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
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final updated = Customer(
                      id: current.id,
                      name: nameCtrl.text.trim().isEmpty
                          ? current.name
                          : nameCtrl.text.trim(),
                      email: emailCtrl.text.trim().isEmpty
                          ? current.email
                          : emailCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty
                          ? current.phone
                          : phoneCtrl.text.trim(),
                      status: selectedStatus,
                    );
                    await ref
                        .read(customerServiceProvider)
                        .updateCustomer(current.id!, updated);
                    ref.invalidate(customersProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Client updated successfully.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> confirmDelete(Customer current) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Client'),
          content: Text(
              'Are you sure you want to permanently delete ${current.name}? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          await ref.read(customerServiceProvider).deleteCustomer(current.id!);
          ref.invalidate(customersProvider);
          if (context.mounted) context.go('/clients');
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete: $e')),
            );
          }
        }
      }
    }

    // ── Loading / Error / Not-found states ──────────────────────────────────
    if (asyncCustomers.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (asyncCustomers.hasError || customer == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off, size: 64, color: crmColors.border),
            24.h,
            Text('Client not found.',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: crmColors.textSecondary)),
            16.h,
            ElevatedButton.icon(
              onPressed: () => context.go('/clients'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Clients'),
            ),
          ],
        ),
      );
    }

    // ── Status badge colour ─────────────────────────────────────────────────
    Color statusColor;
    switch (customer.status) {
      case 'Active':
        statusColor = crmColors.success;
        break;
      case 'Inactive':
        statusColor = crmColors.warning;
        break;
      default:
        statusColor = crmColors.textSecondary;
    }

    final displayEmail =
        customer.email.contains('@placeholder') ? '—' : customer.email;

    // ── Left column (profile card) ──────────────────────────────────────────
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: 24.p,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: crmColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    customer.name.isNotEmpty
                        ? customer.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: crmColors.primary),
                  ),
                ),
                16.h,
                Text(customer.name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                8.h,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    customer.status,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                24.h,
                const Divider(),
                16.h,
                _buildInfoRow(context, Icons.phone, 'PHONE',
                    customer.phone?.isEmpty == true || customer.phone == null
                        ? '—'
                        : customer.phone!),
                16.h,
                _buildInfoRow(context, Icons.email, 'EMAIL', displayEmail),
                16.h,
                _buildInfoRow(context, Icons.location_on_outlined, 'ADDRESS',
                    clientAddress.isEmpty ? '—' : clientAddress),
                16.h,
                _buildInfoRow(context, Icons.markunread_mailbox_outlined,
                    'PINCODE', clientPincode.isEmpty ? '—' : clientPincode),
                if (clientLocation.isNotEmpty) ...[
                  16.h,
                  _buildInfoRow(
                      context, Icons.public, 'LOCATION', clientLocation),
                ],
                if (customer.company != null &&
                    customer.company!.isNotEmpty) ...[
                  16.h,
                  _buildInfoRow(
                      context, Icons.business, 'COMPANY', customer.company!),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    String money(double v) => '₹${v.toStringAsFixed(0)}';

    // ── Right column (summary + bookings) ────────────────────────────────────
    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Financial rollup across all of this client's bookings.
        Card(
          child: Padding(
            padding: 20.p,
            child: Row(
              children: [
                _buildStat(context, 'Bookings', '${bookings.length}',
                    crmColors.primary),
                _statDivider(crmColors),
                _buildStat(context, 'Total Spend', money(totalSpend),
                    crmColors.success),
                _statDivider(crmColors),
                _buildStat(context, 'Advance', money(totalAdvance),
                    crmColors.accent),
                _statDivider(crmColors),
                _buildStat(context, 'Balance Due', money(totalBalance),
                    totalBalance > 0 ? crmColors.warning : crmColors.textSecondary),
              ],
            ),
          ),
        ),
        16.h,
        Card(
          child: Padding(
            padding: 24.p,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Booking History',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('${bookings.length} total',
                        style: TextStyle(
                            color: crmColors.textSecondary, fontSize: 13)),
                  ],
                ),
                16.h,
                if (asyncBookings.isLoading)
                  const CircularProgressIndicator()
                else if (bookings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No bookings found for this client.',
                        style: TextStyle(color: crmColors.textSecondary)),
                  )
                else
                  ...bookings.map((b) {
                    // Show the actual EVENT date (service date), not when the
                    // booking was placed.
                    final event = b.serviceStart.toLocal();
                    const mon = [
                      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                    ];
                    return _buildAppointmentCard(
                      context,
                      mon[event.month - 1],
                      event.day.toString().padLeft(2, '0'),
                      b.service,
                      '${event.day} ${mon[event.month - 1]} ${event.year}'
                      '  ·  ${_fmtTime(b.serviceStart)} — ${_fmtTime(b.serviceEnd)}',
                      b.serviceEnd.isBefore(DateTime.now())
                          ? 'Completed'
                          : 'Upcoming',
                      isUpcoming:
                          b.serviceEnd.isAfter(DateTime.now()),
                      amount: '₹${b.totalPrice.toStringAsFixed(0)}'
                          '${b.balanceDue > 0 ? '  ·  ₹${b.balanceDue.toStringAsFixed(0)} due' : ''}',
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/clients')),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client Profile',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('View and manage details for ${customer.name}.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: crmColors.textSecondary)),
                  ],
                ),
              ),
              if (!isMobile) ...[
                OutlinedButton.icon(
                  onPressed: () => showEditDialog(customer),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Profile'),
                ),
                16.w,
                OutlinedButton.icon(
                  onPressed: () => confirmDelete(customer),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
                16.w,
                ElevatedButton.icon(
                  onPressed: () => showAddBookingModeChooser(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: crmColors.primary,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Book Appointment'),
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            16.h,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showEditDialog(customer),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                12.w,
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => confirmDelete(customer),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                12.w,
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => showAddBookingModeChooser(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: crmColors.primary,
                        foregroundColor: Colors.white),
                    child: const Text('Book'),
                  ),
                ),
              ],
            ),
          ],
          24.h,
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: leftColumn),
                24.w,
                Expanded(flex: 2, child: rightColumn),
              ],
            )
          else
            Column(children: [leftColumn, 16.h, rightColumn]),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    final crmColors = context.crmColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: crmColors.textSecondary),
        16.w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: crmColors.textSecondary,
                      letterSpacing: 1.2)),
              4.h,
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w500, color: crmColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(
      BuildContext context, String label, String value, Color color) {
    final crmColors = context.crmColors;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          4.h,
          Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: crmColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _statDivider(CrmTheme crmColors) =>
      Container(width: 1, height: 34, color: crmColors.border);

  Widget _buildAppointmentCard(
    BuildContext context,
    String month,
    String day,
    String title,
    String time,
    String status, {
    bool isUpcoming = false,
    String amount = '',
  }) {
    final crmColors = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: crmColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: 16.p,
          child: Row(
            children: [
              Column(
                children: [
                  Text(month,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textSecondary)),
                  Text(day,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: crmColors.primary)),
                ],
              ),
              16.w,
              Container(width: 1, height: 40, color: crmColors.border),
              16.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(time,
                        style: TextStyle(
                            color: crmColors.textSecondary, fontSize: 13)),
                    if (amount.isNotEmpty) ...[
                      2.h,
                      Text(amount,
                          style: TextStyle(
                              color: crmColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isUpcoming
                      ? crmColors.warning.withValues(alpha: 0.1)
                      : crmColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isUpcoming ? crmColors.warning : crmColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
