import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/providers/booking_provider.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';

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
    final asyncBookings = ref.watch(bookingProvider);
    final bookings = asyncBookings.value
            ?.where((b) => b.customerName == customer?.name)
            .toList() ??
        [];

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

    // ── Right column (bookings) ─────────────────────────────────────────────
    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    final date = b.bookingDate.toString().split(' ')[0];
                    return _buildAppointmentCard(
                      context,
                      date.substring(5, 7), // MM
                      date.substring(8, 10), // DD
                      b.service,
                      '${_fmtTime(b.serviceStart)} — ${_fmtTime(b.serviceEnd)}',
                      b.serviceEnd.isBefore(DateTime.now())
                          ? 'Completed'
                          : 'Upcoming',
                      isUpcoming:
                          b.serviceEnd.isAfter(DateTime.now()),
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
                  onPressed: () => context.go('/booking/add'),
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
                    onPressed: () => context.go('/booking/add'),
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

  Widget _buildAppointmentCard(
    BuildContext context,
    String month,
    String day,
    String title,
    String time,
    String status, {
    bool isUpcoming = false,
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
