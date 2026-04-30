import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/collection_service.dart';
import '../../services/employee_service.dart';
import '../../providers/collection_filters_provider.dart';
import '../../core/models/artist_collection.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/report_service.dart';

class AccountsCollectionsScreen extends ConsumerWidget {
  const AccountsCollectionsScreen({super.key});

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _currency(double v) => '₹ ${v.toStringAsFixed(0)}';

  Color _statusColor(String s, CrmTheme c) {
    if (s == 'verified') return c.success;
    if (s == 'rejected') return c.destructive;
    return c.warning;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    
    final asyncCollections = ref.watch(filteredCollectionsProvider);
    final filters = ref.watch(collectionFiltersProvider);
    final canVerify = true; // accounts view

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Artist Collections Dashboard',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Comprehensive view of all artist fund collections with advanced filtering.',
                    style: TextStyle(color: crm.textSecondary),
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              ElevatedButton.icon(
                onPressed: () => _showReportDialog(context, ref),
                icon: const Icon(Icons.download),
                label: const Text('Reports'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  foregroundColor: theme.primaryColor,
                ),
              ),
              12.w,
              ElevatedButton.icon(
                onPressed: () => _showFilterSheet(context, ref),
                icon: const Icon(Icons.filter_list),
                label: const Text('Filters'),
              ),
            ],
          ],
        ),
        if (isMobile) ...[
          12.h,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showReportDialog(context, ref),
                  icon: const Icon(Icons.download),
                  label: const Text('Reports'),
                ),
              ),
              12.w,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showFilterSheet(context, ref),
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filters'),
                ),
              ),
            ],
          ),
        ],
        20.h,
        _buildActiveFilters(context, ref, filters),
        20.h,
        Expanded(
          child: asyncCollections.when(
            data: (items) => _buildCollectionsList(context, ref, items, crm, theme, canVerify),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading collections: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilters(BuildContext context, WidgetRef ref, CollectionFilters filters) {
    if (filters.employeeId == null && filters.paymentMode == null && 
        filters.startDate == null && filters.endDate == null && filters.status == null) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (filters.employeeId != null)
          _FilterChip(
            label: 'Artist Selected',
            onDeleted: () => ref.read(collectionFiltersProvider.notifier).state = 
                filters.copyWith(employeeId: null),
          ),
        if (filters.paymentMode != null)
          _FilterChip(
            label: 'Payment: ${filters.paymentMode!.toUpperCase()}',
            onDeleted: () => ref.read(collectionFiltersProvider.notifier).state = 
                filters.copyWith(paymentMode: null),
          ),
        if (filters.startDate != null)
          _FilterChip(
            label: 'From: ${_fmt(filters.startDate!)}',
            onDeleted: () => ref.read(collectionFiltersProvider.notifier).state = 
                filters.copyWith(startDate: null),
          ),
        if (filters.endDate != null)
          _FilterChip(
            label: 'To: ${_fmt(filters.endDate!)}',
            onDeleted: () => ref.read(collectionFiltersProvider.notifier).state = 
                filters.copyWith(endDate: null),
          ),
        if (filters.status != null)
          _FilterChip(
            label: 'Status: ${filters.status!.toUpperCase()}',
            onDeleted: () => ref.read(collectionFiltersProvider.notifier).state = 
                filters.copyWith(status: null),
          ),
        TextButton(
          onPressed: () => ref.read(collectionFiltersProvider.notifier).state = CollectionFilters(),
          child: const Text('Clear All'),
        ),
      ],
    );
  }

  Widget _buildCollectionsList(BuildContext context, WidgetRef ref, List<ArtistCollection> items, CrmTheme crm, ThemeData theme, bool canVerify) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 48, color: crm.textSecondary),
            12.h,
            Text('No collections match your filters', style: TextStyle(color: crm.textSecondary)),
          ],
        ),
      );
    }

    return Card(
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, ___) => Divider(height: 1, color: crm.border),
        itemBuilder: (context, index) {
          final c = items[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: crm.accent.withValues(alpha: 0.15),
              child: Icon(Icons.account_balance_wallet_outlined, color: crm.accent, size: 18),
            ),
            title: Text(
              '${c.booking?.customerName ?? 'Unknown Client'}  •  ${_currency(c.amount)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${_fmt(c.date)}  •  ${c.paymentMode.toUpperCase()}  •  Artist: ${c.employee?.name ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(c.status, crm).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor(c.status, crm).withValues(alpha: 0.4)),
              ),
              child: Text(
                c.status.toUpperCase(),
                style: TextStyle(
                  color: _statusColor(c.status, crm),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () => _showCollectionDetails(context, ref, c),
          );
        },
      ),
    );
  }

  void _showCollectionDetails(BuildContext context, WidgetRef ref, ArtistCollection c) {
    final crm = context.crmColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Collection Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailItem(label: 'Client', value: c.booking?.customerName ?? 'N/A'),
            _DetailItem(label: 'Booking #', value: c.booking?.bookingNumber ?? 'N/A'),
            _DetailItem(label: 'Artist', value: c.employee?.name ?? 'N/A'),
            _DetailItem(label: 'Amount', value: _currency(c.amount)),
            _DetailItem(label: 'Date', value: _fmt(c.date)),
            _DetailItem(label: 'Payment Mode', value: c.paymentMode.toUpperCase()),
            if (c.notes.isNotEmpty) _DetailItem(label: 'Notes', value: c.notes),
            if (c.attachmentUrl != null) ...[
              16.h,
              const Text('Screenshot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              8.h,
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  c.attachmentUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, _, __) => const Center(child: Text('Error loading image')),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (c.status == 'pending') ...[
            TextButton(
              onPressed: () async {
                final session = ref.read(authControllerProvider).session;
                await ref.read(collectionServiceProvider).verifyCollection(
                  id: c.id,
                  status: 'rejected',
                  verifiedBy: session?.userId ?? '',
                );
                ref.invalidate(filteredCollectionsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Reject', style: TextStyle(color: crm.destructive)),
            ),
            ElevatedButton(
              onPressed: () async {
                final session = ref.read(authControllerProvider).session;
                await ref.read(collectionServiceProvider).verifyCollection(
                  id: c.id,
                  status: 'verified',
                  verifiedBy: session?.userId ?? '',
                );
                ref.invalidate(filteredCollectionsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: crm.success, foregroundColor: Colors.white),
              child: const Text('Verify'),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final asyncEmployees = ref.watch(employeesProvider);
    final filters = ref.watch(collectionFiltersProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Advanced Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                24.h,
                // Artist Filter
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Artist', prefixIcon: Icon(Icons.person_outline)),
                  initialValue: filters.employeeId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Artists')),
                    ...(asyncEmployees.value ?? []).map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
                  ],
                  onChanged: (v) => ref.read(collectionFiltersProvider.notifier).state = filters.copyWith(employeeId: v),
                ),
                16.h,
                // Payment Mode
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Payment Mode', prefixIcon: Icon(Icons.payments_outlined)),
                  initialValue: filters.paymentMode,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Modes')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                  ],
                  onChanged: (v) => ref.read(collectionFiltersProvider.notifier).state = filters.copyWith(paymentMode: v),
                ),
                16.h,
                // Date Range
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: filters.startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            ref.read(collectionFiltersProvider.notifier).state = filters.copyWith(startDate: picked);
                            setState(() {});
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Start Date', prefixIcon: Icon(Icons.calendar_today)),
                          child: Text(filters.startDate != null ? _fmt(filters.startDate!) : 'Select'),
                        ),
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: filters.endDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            ref.read(collectionFiltersProvider.notifier).state = filters.copyWith(endDate: picked);
                            setState(() {});
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'End Date', prefixIcon: Icon(Icons.calendar_today)),
                          child: Text(filters.endDate != null ? _fmt(filters.endDate!) : 'Select'),
                        ),
                      ),
                    ),
                  ],
                ),
                16.h,
                // Status
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.check_circle_outline)),
                  initialValue: filters.status,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'verified', child: Text('Verified')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (v) => ref.read(collectionFiltersProvider.notifier).state = filters.copyWith(status: v),
                ),
                32.h,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
                16.h,
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    int selMonth = now.month;
    int selYear = now.year;
    String? selArtist = 'all';
    String selFormat = 'pdf';

    final asyncEmployees = ref.read(employeesProvider);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Download Finance Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select report parameters:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              16.h,
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Month'),
                      initialValue: selMonth,
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_getMonthName(i + 1)))),
                      onChanged: (v) => setState(() => selMonth = v!),
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Year'),
                      initialValue: selYear,
                      items: [now.year - 1, now.year].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (v) => setState(() => selYear = v!),
                    ),
                  ),
                ],
              ),
              16.h,
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Artist (Optional)', prefixIcon: Icon(Icons.person_outline)),
                initialValue: selArtist,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Artists')),
                  ...(asyncEmployees.value ?? []).map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
                ],
                onChanged: (v) => setState(() => selArtist = v),
              ),
              16.h,
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Format'),
                initialValue: selFormat,
                items:  [
                  DropdownMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 18), 8.w, Text('PDF Document')])),
                  DropdownMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_chart, size: 18), 8.w, Text('CSV Spreadsheet')])),
                ],
                onChanged: (v) => setState(() => selFormat = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ref.read(reportServiceProvider).downloadFinanceReport(
                  month: selMonth,
                  year: selYear,
                  employeeId: selArtist,
                  format: selFormat,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Download'),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int m) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[m - 1];
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _FilterChip({required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 14),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
