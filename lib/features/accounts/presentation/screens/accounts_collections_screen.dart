
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/collection_image_view.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import '../../../../services/employee_service.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_filters_provider.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import '../../../../core/models/booking.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../services/report_service.dart';
import '../../../../services/booking_service.dart';
import '../../../../core/utils/export_utils.dart';

// ─── Provider: bookings that have at least one verified collection ────────────
final _bookingInvoiceSummariesProvider =
    FutureProvider<List<_BookingInvoiceSummary>>((ref) async {
  // 1. Fetch all verified collections
  final collections = await ref
      .watch(collectionServiceProvider)
      .getCollections(status: 'verified');

  // 2. Group by bookingId
  final byBooking = <String, List<ArtistCollection>>{};
  for (final c in collections) {
    final id = c.booking?.id ?? '';
    if (id.isEmpty) continue;
    byBooking.putIfAbsent(id, () => []).add(c);
  }

  // 3. Fetch each booking to get the authoritative collectedAmount + totalPrice
  final bookingService = ref.watch(bookingServiceProvider);
  final summaries = <_BookingInvoiceSummary>[];
  for (final entry in byBooking.entries) {
    try {
      final booking = await bookingService.getBookingById(entry.key);
      summaries.add(_BookingInvoiceSummary(
        booking: booking,
        collections: entry.value,
      ));
    } catch (_) {
      // Booking may have been deleted — skip
    }
  }

  summaries.sort((a, b) =>
      b.booking.serviceStart.compareTo(a.booking.serviceStart));
  return summaries;
});

class _BookingInvoiceSummary {
  final Booking booking;
  final List<ArtistCollection> collections;
  const _BookingInvoiceSummary({
    required this.booking,
    required this.collections,
  });
}
// ─────────────────────────────────────────────────────────────────────────────

class AccountsCollectionsScreen extends ConsumerStatefulWidget {
  const AccountsCollectionsScreen({super.key});
  @override
  ConsumerState<AccountsCollectionsScreen> createState() =>
      _AccountsCollectionsScreenState();
}

class _AccountsCollectionsScreenState
    extends ConsumerState<AccountsCollectionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final asyncCollections = ref.watch(filteredCollectionsProvider);
    final filters = ref.watch(collectionFiltersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finance & Invoices',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Artist collections and booking invoice balances.',
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
        16.h,

        // ── Tab Bar ─────────────────────────────────────────────────────────
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Collections'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Invoice Balances'),
          ],
        ),
        16.h,

        // ── Active Filters (collections tab only) ────────────────────────────
        _buildActiveFilters(context, ref, filters),

        // ── Tab Views ────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Collections
              asyncCollections.when(
                data: (items) => _buildCollectionsList(
                  context, ref, items, crm, theme, true,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error loading collections: $e')),
              ),

              // Tab 2: Invoice Balances
              _InvoiceBalancesTab(
                fmt: _fmt,
                currency: _currency,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilters(
    BuildContext context,
    WidgetRef ref,
    CollectionFilters filters,
  ) {
    if (filters.employeeId == null &&
        filters.paymentMode == null &&
        filters.startDate == null &&
        filters.endDate == null &&
        filters.status == null) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (filters.employeeId != null)
          _FilterChip(
            label: 'Artist Selected',
            onDeleted: () =>
                ref.read(collectionFiltersProvider.notifier).state = filters
                    .copyWith(employeeId: null),
          ),
        if (filters.paymentMode != null)
          _FilterChip(
            label: 'Payment: ${filters.paymentMode!.toUpperCase()}',
            onDeleted: () =>
                ref.read(collectionFiltersProvider.notifier).state = filters
                    .copyWith(paymentMode: null),
          ),
        if (filters.startDate != null)
          _FilterChip(
            label: 'From: ${_fmt(filters.startDate!)}',
            onDeleted: () =>
                ref.read(collectionFiltersProvider.notifier).state = filters
                    .copyWith(startDate: null),
          ),
        if (filters.endDate != null)
          _FilterChip(
            label: 'To: ${_fmt(filters.endDate!)}',
            onDeleted: () =>
                ref.read(collectionFiltersProvider.notifier).state = filters
                    .copyWith(endDate: null),
          ),
        if (filters.status != null)
          _FilterChip(
            label: 'Status: ${filters.status!.toUpperCase()}',
            onDeleted: () =>
                ref.read(collectionFiltersProvider.notifier).state = filters
                    .copyWith(status: null),
          ),
        TextButton(
          onPressed: () => ref.read(collectionFiltersProvider.notifier).state =
              CollectionFilters(),
          child: const Text('Clear All'),
        ),
      ],
    );
  }

  Widget _buildCollectionsList(
    BuildContext context,
    WidgetRef ref,
    List<ArtistCollection> items,
    CrmTheme crm,
    ThemeData theme,
    bool canVerify,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: crm.textSecondary,
            ),
            12.h,
            Text(
              'No collections match your filters',
              style: TextStyle(color: crm.textSecondary),
            ),
          ],
        ),
      );
    }

    return Card(
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: crm.border),
        itemBuilder: (context, index) {
          final c = items[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: crm.accent.withValues(alpha: 0.15),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: crm.accent,
                size: 18,
              ),
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
                border: Border.all(
                  color: _statusColor(c.status, crm).withValues(alpha: 0.4),
                ),
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

  void _showCollectionDetails(
    BuildContext context,
    WidgetRef ref,
    ArtistCollection c,
  ) {
    final crm = context.crmColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Collection Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailItem(
              label: 'Client',
              value: c.booking?.customerName ?? 'N/A',
            ),
            _DetailItem(
              label: 'Booking #',
              value: c.booking?.bookingNumber ?? 'N/A',
            ),
            _DetailItem(label: 'Artist', value: c.employee?.name ?? 'N/A'),
            _DetailItem(label: 'Amount', value: _currency(c.amount)),
            _DetailItem(label: 'Date', value: _fmt(c.date)),
            _DetailItem(
              label: 'Payment Mode',
              value: c.paymentMode.toUpperCase(),
            ),
            if (c.notes.isNotEmpty) _DetailItem(label: 'Notes', value: c.notes),
            if (c.attachmentUrl != null) ...[
              16.h,
              const Text(
                'Screenshot:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              8.h,
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) => CollectionImageViewerDialog(
                      url: c.attachmentUrl!,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    c.attachmentUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, _, _) =>
                        const Center(child: Text('Error loading image')),
                  ),
                ),
              ),
              8.h,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (_) => CollectionImageViewerDialog(
                            url: c.attachmentUrl!,
                            autoShare: true,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share'),
                    ),
                  ),
                  8.w,
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (_) => CollectionImageViewerDialog(
                            url: c.attachmentUrl!,
                            autoDownload: true,
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (c.status == 'pending') ...[
            TextButton(
              onPressed: () async {
                final session = ref.read(authSessionProvider);
                await ref
                    .read(collectionServiceProvider)
                    .verifyCollection(
                      id: c.id,
                      status: 'rejected',
                      verifiedBy: session?.userId ?? '',
                    );
                ref.invalidate(filteredCollectionsProvider);
                ref.invalidate(_bookingInvoiceSummariesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Reject', style: TextStyle(color: crm.destructive)),
            ),
            ElevatedButton(
              onPressed: () async {
                final session = ref.read(authSessionProvider);
                await ref
                    .read(collectionServiceProvider)
                    .verifyCollection(
                      id: c.id,
                      status: 'verified',
                      verifiedBy: session?.userId ?? '',
                    );
                ref.invalidate(filteredCollectionsProvider);
                // Also refresh the invoice balances tab
                ref.invalidate(_bookingInvoiceSummariesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: crm.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Verify'),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
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
                    const Text(
                      'Advanced Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                24.h,
                // Artist Filter
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Artist',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  initialValue: filters.employeeId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Artists'),
                    ),
                    ...(asyncEmployees.value ?? []).map(
                      (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
                    ),
                  ],
                  onChanged: (v) =>
                      ref.read(collectionFiltersProvider.notifier).state =
                          filters.copyWith(employeeId: v),
                ),
                16.h,
                // Payment Mode
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  initialValue: filters.paymentMode,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Modes')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Bank Transfer'),
                    ),
                  ],
                  onChanged: (v) =>
                      ref.read(collectionFiltersProvider.notifier).state =
                          filters.copyWith(paymentMode: v),
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
                            ref.read(collectionFiltersProvider.notifier).state =
                                filters.copyWith(startDate: picked);
                            setState(() {});
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            filters.startDate != null
                                ? _fmt(filters.startDate!)
                                : 'Select',
                          ),
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
                            ref.read(collectionFiltersProvider.notifier).state =
                                filters.copyWith(endDate: picked);
                            setState(() {});
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            filters.endDate != null
                                ? _fmt(filters.endDate!)
                                : 'Select',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                16.h,
                // Status
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  initialValue: filters.status,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'verified',
                      child: Text('Verified'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (v) =>
                      ref.read(collectionFiltersProvider.notifier).state =
                          filters.copyWith(status: v),
                ),
                32.h,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
    final crm = context.crmColors;
    final now = DateTime.now();
    int selMonth = now.month;
    int selYear = now.year;
    String? selArtist = 'all';
    String selFormat = 'pdf';
    bool busy = false;

    final asyncEmployees = ref.read(employeesProvider);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> download() async {
            setLocal(() => busy = true);
            try {
              await ref.read(reportServiceProvider).downloadFinanceReport(
                    month: selMonth,
                    year: selYear,
                    employeeId: selArtist,
                    format: selFormat,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              setLocal(() => busy = false);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Could not open report: $e')));
              }
            }
          }

          Widget preset(String label, VoidCallback onTap) => ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                onPressed: busy ? null : onTap,
                visualDensity: VisualDensity.compact,
              );

          Widget formatCard(
              String value, IconData icon, String label, String sub) {
            final sel = selFormat == value;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: busy ? null : () => setLocal(() => selFormat = value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: sel
                        ? crm.primary.withValues(alpha: 0.08)
                        : crm.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? crm.primary : crm.border,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Column(
                    children: [
                      Icon(icon,
                          color: sel ? crm.primary : crm.textSecondary,
                          size: 24),
                      6.h,
                      Text(label,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: sel ? crm.primary : crm.textPrimary)),
                      Text(sub,
                          style: TextStyle(
                              fontSize: 10.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: crm.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.summarize_outlined, color: crm.primary),
                ),
                12.w,
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Finance Report',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Collections & invoice balances for a month.',
                      style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                  14.h,
                  Row(
                    children: [
                      preset('This month', () => setLocal(() {
                            selMonth = now.month;
                            selYear = now.year;
                          })),
                      8.w,
                      preset('Last month', () => setLocal(() {
                            final lm = DateTime(now.year, now.month - 1);
                            selMonth = lm.month;
                            selYear = lm.year;
                          })),
                    ],
                  ),
                  14.h,
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          decoration:
                              const InputDecoration(labelText: 'Month'),
                          initialValue: selMonth,
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(_getMonthName(i + 1)),
                            ),
                          ),
                          onChanged: busy
                              ? null
                              : (v) => setLocal(() => selMonth = v!),
                        ),
                      ),
                      12.w,
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: 'Year'),
                          initialValue: selYear,
                          items: [now.year - 1, now.year]
                              .map((y) => DropdownMenuItem(
                                  value: y, child: Text(y.toString())))
                              .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setLocal(() => selYear = v!),
                        ),
                      ),
                    ],
                  ),
                  14.h,
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Artist',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    initialValue: selArtist,
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('All Artists')),
                      ...(asyncEmployees.value ?? []).map((e) =>
                          DropdownMenuItem(value: e.id, child: Text(e.name))),
                    ],
                    onChanged:
                        busy ? null : (v) => setLocal(() => selArtist = v),
                  ),
                  18.h,
                  Text('FORMAT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: crm.textSecondary)),
                  8.h,
                  Row(
                    children: [
                      formatCard('pdf', Icons.picture_as_pdf_outlined, 'PDF',
                          'Printable'),
                      10.w,
                      formatCard('csv', Icons.table_chart_outlined, 'CSV',
                          'Opens in Excel'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : download,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download, size: 18),
                label: Text(busy ? 'Preparing…' : 'Download'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getMonthName(int m) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[m - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Tab 2: Booking Invoice Balances
/// Shows each booking's payment breakdown: Total → Advance → Collected → Balance
// ─────────────────────────────────────────────────────────────────────────────
class _InvoiceBalancesTab extends ConsumerStatefulWidget {
  final String Function(DateTime) fmt;
  final String Function(double) currency;

  const _InvoiceBalancesTab({required this.fmt, required this.currency});

  @override
  ConsumerState<_InvoiceBalancesTab> createState() =>
      _InvoiceBalancesTabState();
}

class _InvoiceBalancesTabState extends ConsumerState<_InvoiceBalancesTab> {
  static const _rowsPerPage = 12;
  String? _monthKey; // 'yyyy-mm', or null = all months
  int _page = 0;

  // Excel-like columns: (label, base width, right-aligned).
  static const List<(String, double, bool)> _cols = [
    ('Date', 94, false),
    ('Customer', 146, false),
    ('Service', 112, false),
    ('Invoice #', 110, false),
    ('Total', 92, true),
    ('Discount', 90, true),
    ('Advance', 90, true),
    ('Collected', 96, true),
    ('Collected By', 150, false),
    ('Balance', 100, true),
    ('Status', 82, false),
  ];

  static const _mAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  String _mKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
  String _mLabel(DateTime d) => '${_mAbbr[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(_bookingInvoiceSummariesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (all) {
        if (all.isEmpty) {
          return _empty(crm, 'No bookings with verified collections yet.');
        }

        // Months present in the data (newest first).
        final months = <String, DateTime>{};
        for (final s in all) {
          final d = s.booking.serviceStart;
          months.putIfAbsent(_mKey(d), () => DateTime(d.year, d.month));
        }
        final monthList = months.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final filtered = _monthKey == null
            ? all
            : all
                .where((s) => _mKey(s.booking.serviceStart) == _monthKey)
                .toList();

        final totalPages =
            filtered.isEmpty ? 1 : (filtered.length / _rowsPerPage).ceil();
        final page = _page.clamp(0, totalPages - 1);
        final start = page * _rowsPerPage;
        final endI = (start + _rowsPerPage).clamp(0, filtered.length);
        final pageItems =
            filtered.isEmpty ? const [] : filtered.sublist(start, endI);

        // Column totals over the whole filtered set (Excel footer).
        final t = _totals(filtered);
        final baseWidth = _cols.fold<double>(0, (a, c) => a + c.$2);

        return Column(
          children: [
            _toolbar(crm, monthList, filtered),
            10.h,
            Expanded(
              child: filtered.isEmpty
                  ? _empty(crm, 'No invoices for this month.')
                  : LayoutBuilder(
                      builder: (ctx, cons) {
                        final scale = cons.maxWidth > baseWidth
                            ? cons.maxWidth / baseWidth
                            : 1.0;
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: crm.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: baseWidth * scale,
                              child: Column(
                                children: [
                                  _headerRow(crm, scale),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: pageItems.length,
                                      itemBuilder: (c, i) => _dataRow(
                                          crm,
                                          pageItems[i],
                                          start + i,
                                          scale),
                                    ),
                                  ),
                                  _totalsRow(crm, scale, t),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _pagination(crm, page, totalPages, filtered.length),
          ],
        );
      },
    );
  }

  // ── Toolbar: month filter + count + download ────────────────────────────
  Widget _toolbar(CrmTheme crm, List<MapEntry<String, DateTime>> monthList,
      List<_BookingInvoiceSummary> filtered) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: crm.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _monthKey,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              borderRadius: BorderRadius.circular(10),
              items: [
                const DropdownMenuItem(value: null, child: Text('All months')),
                for (final e in monthList)
                  DropdownMenuItem(value: e.key, child: Text(_mLabel(e.value))),
              ],
              onChanged: (v) => setState(() {
                _monthKey = v;
                _page = 0;
              }),
            ),
          ),
        ),
        12.w,
        Text('${filtered.length} invoices',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        const Spacer(),
        FilledButton.tonalIcon(
          onPressed:
              filtered.isEmpty ? null : () => _download(filtered),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Download'),
        ),
      ],
    );
  }

  // ── Rows ────────────────────────────────────────────────────────────────
  Widget _cellBox(double w, bool right, Widget child) => Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      );

  Widget _headerRow(CrmTheme crm, double scale) => Container(
        color: crm.primary.withValues(alpha: 0.08),
        child: Row(
          children: [
            for (final c in _cols)
              _cellBox(
                c.$2 * scale,
                c.$3,
                Text(c.$1,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: crm.primary)),
              ),
          ],
        ),
      );

  String _collectedBy(_BookingInvoiceSummary s) {
    final names = s.collections
        .map((c) => c.employee?.name ?? '')
        .where((n) => n.trim().isNotEmpty)
        .toSet()
        .toList();
    return names.isEmpty ? '—' : names.join(', ');
  }

  Widget _dataRow(
      CrmTheme crm, _BookingInvoiceSummary s, int index, double scale) {
    final b = s.booking;
    final paid = b.isFullyPaid;
    final bal = paid ? 0.0 : b.balanceDue;
    final cur = widget.currency;
    final collectedBy = _collectedBy(s);
    return Container(
      decoration: BoxDecoration(
        color: index.isEven
            ? Colors.transparent
            : crm.primary.withValues(alpha: 0.03),
        border: Border(
            bottom: BorderSide(color: crm.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          _cellBox(_cols[0].$2 * scale, false,
              Text(widget.fmt(b.serviceStart), style: const TextStyle(fontSize: 12))),
          _cellBox(
              _cols[1].$2 * scale,
              false,
              Text(b.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
          _cellBox(
              _cols[2].$2 * scale,
              false,
              Text(b.service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: crm.textSecondary))),
          _cellBox(
              _cols[3].$2 * scale,
              false,
              Text('#${b.displayBookingNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: crm.textSecondary))),
          _cellBox(_cols[4].$2 * scale, true,
              Text(cur(b.totalPrice), style: const TextStyle(fontSize: 12.5))),
          _cellBox(
              _cols[5].$2 * scale,
              true,
              Text(b.discountAmount > 0 ? '− ${cur(b.discountAmount)}' : '—',
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          _cellBox(_cols[6].$2 * scale, true,
              Text(cur(b.advanceAmount), style: const TextStyle(fontSize: 12.5))),
          _cellBox(_cols[7].$2 * scale, true,
              Text(cur(b.collectedAmount), style: const TextStyle(fontSize: 12.5))),
          _cellBox(
              _cols[8].$2 * scale,
              false,
              Row(
                children: [
                  if (collectedBy != '—')
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Icon(Icons.person_outline,
                          size: 13, color: crm.primary),
                    ),
                  Expanded(
                    child: Text(collectedBy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: collectedBy == '—'
                                ? crm.textSecondary
                                : crm.textPrimary)),
                  ),
                ],
              )),
          _cellBox(
              _cols[9].$2 * scale,
              true,
              Text(cur(bal),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: paid ? crm.success : crm.destructive))),
          _cellBox(_cols[10].$2 * scale, false, _statusChip(crm, paid)),
        ],
      ),
    );
  }

  Widget _totalsRow(CrmTheme crm, double scale, _Totals t) {
    final cur = widget.currency;
    Widget num(int i, String s) => _cellBox(_cols[i].$2 * scale, _cols[i].$3,
        Text(s, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)));
    return Container(
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.05),
        border: Border(top: BorderSide(color: crm.primary.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          _cellBox(
              _cols[0].$2 * scale,
              false,
              Text('TOTAL',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: crm.primary))),
          _cellBox(_cols[1].$2 * scale, false, const SizedBox()),
          _cellBox(_cols[2].$2 * scale, false, const SizedBox()),
          _cellBox(_cols[3].$2 * scale, false, const SizedBox()),
          num(4, cur(t.total)),
          num(5, t.discount > 0 ? '− ${cur(t.discount)}' : '—'),
          num(6, cur(t.advance)),
          num(7, cur(t.collected)),
          _cellBox(_cols[8].$2 * scale, false, const SizedBox()),
          _cellBox(
              _cols[9].$2 * scale,
              true,
              Text(cur(t.balance),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: crm.destructive))),
          _cellBox(_cols[10].$2 * scale, false, const SizedBox()),
        ],
      ),
    );
  }

  Widget _statusChip(CrmTheme crm, bool paid) {
    final color = paid ? crm.success : crm.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(paid ? 'PAID' : 'DUE',
          style:
              TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _pagination(CrmTheme crm, int page, int totalPages, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Text('$count total',
              style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                page > 0 ? () => setState(() => _page = page - 1) : null,
          ),
          Text('Page ${page + 1} / $totalPages',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: page < totalPages - 1
                ? () => setState(() => _page = page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _empty(CrmTheme crm, String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: crm.textSecondary),
            12.h,
            Text(msg, style: TextStyle(color: crm.textSecondary)),
          ],
        ),
      );

  _Totals _totals(List<_BookingInvoiceSummary> rows) {
    double total = 0, disc = 0, adv = 0, coll = 0, bal = 0;
    for (final s in rows) {
      final b = s.booking;
      total += b.totalPrice;
      disc += b.discountAmount;
      adv += b.advanceAmount;
      coll += b.collectedAmount;
      bal += b.isFullyPaid ? 0 : b.balanceDue;
    }
    return _Totals(total, disc, adv, coll, bal);
  }

  // ── CSV / Excel download ────────────────────────────────────────────────
  Future<void> _download(List<_BookingInvoiceSummary> rows) async {
    final data = <List<dynamic>>[
      ['Date', 'Customer', 'Service', 'Invoice #', 'Total', 'Discount',
        'Advance', 'Collected', 'Collected By', 'Balance', 'Status'],
    ];
    for (final s in rows) {
      final b = s.booking;
      final paid = b.isFullyPaid;
      data.add([
        widget.fmt(b.serviceStart),
        b.customerName,
        b.service,
        b.displayBookingNumber,
        b.totalPrice,
        b.discountAmount,
        b.advanceAmount,
        b.collectedAmount,
        _collectedBy(s),
        paid ? 0 : b.balanceDue,
        paid ? 'PAID' : 'DUE',
      ]);
    }
    final t = _totals(rows);
    data.add(['TOTAL', '', '', '', t.total, t.discount, t.advance, t.collected,
      '', t.balance, '']);

    final label = _monthKey ?? 'all-months';
    try {
      await ExportUtils.exportCsv('invoice-balances-$label.csv', data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice report downloaded')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }
}

class _Totals {
  final double total, discount, advance, collected, balance;
  const _Totals(
      this.total, this.discount, this.advance, this.collected, this.balance);
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
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
