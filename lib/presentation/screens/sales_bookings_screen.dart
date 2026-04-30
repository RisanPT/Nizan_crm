import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/dashboard_report_service.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../services/package_service.dart';

class SalesBookingsScreen extends HookConsumerWidget {
  const SalesBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final theme = Theme.of(context);
    final isMobile = ResponsiveBuilder.isMobile(context);
    final selectedIds = useState<Set<String>>(<String>{});
    final pageState = useState(1);
    final searchCtrl = useTextEditingController();
    final searchQuery = useState('');
    final duplicatesOnly = useState(false);
    final isMonthlyView = useState(false);
    final selectedFY = useState<String>('2025-26');
    const pageSize = 20;

    final financialYears = ['2026-27', '2025-26', '2024-25', '2023-24'];

    final pageParams = PaginatedBookingsParams(
      page: pageState.value,
      limit: pageSize,
      search: searchQuery.value,
      duplicatesOnly: duplicatesOnly.value,
      financialYear: selectedFY.value,
    );
    final asyncPaginatedBookings = ref.watch(
      paginatedBookingsProvider(pageParams),
    );

    useEffect(() {
      selectedIds.value = <String>{};
      return null;
    }, [pageState.value]);

    useEffect(() {
      pageState.value = 1;
      selectedIds.value = <String>{};
      return null;
    }, [searchQuery.value, duplicatesOnly.value, selectedFY.value]);

    Future<void> deleteBookings(
      List<String> bookingIds,
      int currentPageCount,
    ) async {
      if (bookingIds.isEmpty) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            bookingIds.length == 1 ? 'Delete Booking' : 'Delete Bookings',
          ),
          content: Text(
            bookingIds.length == 1
                ? 'This booking will be deleted permanently.'
                : '${bookingIds.length} bookings will be deleted permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      final notifier = ref.read(bookingProvider.notifier);
      for (final bookingId in bookingIds) {
        await notifier.removeBooking(bookingId);
      }

      ref.invalidate(paginatedBookingsProvider);

      selectedIds.value = {
        for (final existingId in selectedIds.value)
          if (!bookingIds.contains(existingId)) existingId,
      };

      if (bookingIds.length >= currentPageCount && pageState.value > 1) {
        pageState.value -= 1;
      }
    }

    return asyncPaginatedBookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load bookings: $error',
          style: TextStyle(color: crmColors.textSecondary),
        ),
      ),
      data: (response) {
        final bookings = response.items;
        final allSelected =
            bookings.isNotEmpty &&
            bookings.every((booking) => selectedIds.value.contains(booking.id));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales & Invoices',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              8.h,
              Text(
                'All bookings with financial status, advance tracking, and invoice-ready totals.',
                style: TextStyle(color: crmColors.textSecondary, fontSize: 15),
              ),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: selectedFY.value,
                    onChanged: (val) {
                      if (val != null) selectedFY.value = val;
                    },
                    items: financialYears.map((fy) {
                      return DropdownMenuItem(
                        value: fy,
                        child: Text('FY $fy', style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    style: TextStyle(color: crmColors.primary, fontSize: 16),
                    underline: Container(height: 2, color: crmColors.primary),
                  ),
                  20.w,
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('List View'),
                        icon: Icon(Icons.list),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Monthly Summary'),
                        icon: Icon(Icons.calendar_month),
                      ),
                    ],
                    selected: {isMonthlyView.value},
                    onSelectionChanged: (val) {
                      isMonthlyView.value = val.first;
                    },
                  ),
                ],
              ),
              24.h,
              Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 360,
                    child: TextFormField(
                      controller: searchCtrl,
                      onFieldSubmitted: (value) {
                        final trimmed = value.trim();
                        searchQuery.value = trimmed;
                        if (trimmed.isEmpty) {
                          searchCtrl.clear();
                        }
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Search by client, phone, package, region or booking no...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.value.isEmpty
                            ? IconButton(
                                onPressed: () =>
                                    searchQuery.value = searchCtrl.text.trim(),
                                icon: const Icon(Icons.search),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => searchQuery.value =
                                        searchCtrl.text.trim(),
                                    icon: const Icon(Icons.search),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      searchCtrl.clear();
                                      searchQuery.value = '';
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  FilterChip(
                    selected: duplicatesOnly.value,
                    onSelected: (value) => duplicatesOnly.value = value,
                    avatar: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Duplicates only'),
                  ),
                ],
              ),
              20.h,
              Row(
                children: [
                  if (!isMobile) ...[
                    Checkbox(
                      value: allSelected,
                      onChanged: bookings.isEmpty
                          ? null
                          : (value) {
                              selectedIds.value = value == true
                                  ? {for (final booking in bookings) booking.id}
                                  : <String>{};
                            },
                    ),
                    Text(
                      'Select all',
                      style: TextStyle(color: crmColors.textSecondary),
                    ),
                  ],
                  const Spacer(),
                  if (selectedIds.value.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => deleteBookings(
                        selectedIds.value.toList(growable: false),
                        bookings.length,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(
                        'Delete Selected (${selectedIds.value.length})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crmColors.destructive,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              24.h,
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _MetricCard(
                    label: 'Total Bookings',
                    value: '${response.totalItems}',
                  ),
                  _MetricCard(
                    label: 'Sales Value',
                    value: '₹${_money(response.summary.totalSales)}',
                  ),
                  _MetricCard(
                    label: 'Advance Collected',
                    value: '₹${_money(response.summary.totalAdvance)}',
                  ),
                  _MetricCard(
                    label: 'Completed',
                    value: '${response.summary.completedCount}',
                  ),
                  _MetricCard(
                    label: 'Cancelled',
                    value: '${response.summary.cancelledCount}',
                  ),
                  _MetricCard(
                    label: 'Duplicate Entries',
                    value: '${response.duplicateItems}',
                  ),
                ],
              ),
              24.h,
              if (duplicatesOnly.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    response.duplicateItems == 0
                        ? 'No duplicate bookings found for the current filter.'
                        : '${response.duplicateItems} duplicate entries found across ${response.duplicateGroups} groups. Review them, then use single delete or bulk delete safely.',
                    style: TextStyle(
                      color: crmColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (isMonthlyView.value)
                _MonthlySalesSummaryView(
                  financialYear: selectedFY.value,
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: crmColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: crmColors.border),
                  ),
                  child: isMobile
                      ? Column(
                          children: bookings
                              .map(
                                (booking) => _MobileBookingCard(
                                  booking: booking,
                                  isSelected: selectedIds.value.contains(
                                    booking.id,
                                  ),
                                  onSelectChanged: (value) {
                                    final next = {...selectedIds.value};
                                    if (value == true) {
                                      next.add(booking.id);
                                    } else {
                                      next.remove(booking.id);
                                    }
                                    selectedIds.value = next;
                                  },
                                  onDelete: () => deleteBookings([
                                    booking.id,
                                  ], bookings.length),
                                ),
                              )
                              .toList(),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Row(
                                children: const [
                                  SizedBox(width: 44),
                                  Expanded(
                                    flex: 2,
                                    child: _HeaderText('Booking'),
                                  ),
                                  Expanded(flex: 2, child: _HeaderText('Date')),
                                  Expanded(flex: 2, child: _HeaderText('Client')),
                                  Expanded(
                                    flex: 2,
                                    child: _HeaderText('Package'),
                                  ),
                                  Expanded(child: _HeaderText('Status')),
                                  Expanded(child: _HeaderText('Advance')),
                                  Expanded(child: _HeaderText('Total')),
                                  Expanded(child: _HeaderText('Balance')),
                                  SizedBox(width: 60),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...bookings.map(
                              (booking) => _DesktopBookingRow(
                                booking: booking,
                                isSelected: selectedIds.value.contains(
                                  booking.id,
                                ),
                                onSelectChanged: (value) {
                                  final next = {...selectedIds.value};
                                  if (value == true) {
                                    next.add(booking.id);
                                  } else {
                                    next.remove(booking.id);
                                  }
                                  selectedIds.value = next;
                                },
                                onDelete: () =>
                                    deleteBookings([booking.id], bookings.length),
                              ),
                            ),
                          ],
                        ),
                ),
              20.h,
              _PaginationBar(
                page: response.page,
                limit: response.limit,
                totalPages: response.totalPages,
                totalItems: response.totalItems,
                currentItemCount: bookings.length,
                onPrevious: response.page > 1
                    ? () => pageState.value -= 1
                    : null,
                onNext: response.page < response.totalPages
                    ? () => pageState.value += 1
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: crmColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          10.h,
          Text(
            value,
            style: TextStyle(
              color: crmColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int limit;
  final int totalPages;
  final int totalItems;
  final int currentItemCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.totalItems,
    required this.currentItemCount,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final startItem = totalItems == 0 ? 0 : ((page - 1) * limit) + 1;
    final endItem = totalItems == 0 ? 0 : startItem + currentItemCount - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crmColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $startItem-$endItem of $totalItems bookings',
              style: TextStyle(
                color: crmColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Page $page of $totalPages',
            style: TextStyle(
              color: crmColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          12.w,
          OutlinedButton.icon(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),
          8.w,
          ElevatedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Text(
      text,
      style: TextStyle(
        color: crmColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 1,
      ),
    );
  }
}

class _DesktopBookingRow extends StatelessWidget {
  final Booking booking;
  final bool isSelected;
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback onDelete;

  const _DesktopBookingRow({
    required this.booking,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final balance =
        ((booking.totalPrice - booking.advanceAmount - booking.discountAmount)
                .clamp(0, double.infinity))
            .toDouble();

    return InkWell(
      onTap: () => context.go('/booking/manage/${booking.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Checkbox(value: isSelected, onChanged: onSelectChanged),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '#${booking.displayBookingNumber}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(booking.bookingDate),
                style: TextStyle(
                  color: crmColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(flex: 2, child: Text(booking.customerName)),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.service),
                  if (booking.duplicateCount > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _DuplicateBadge(count: booking.duplicateCount),
                    ),
                ],
              ),
            ),
            Expanded(child: _StatusChip(status: booking.status)),
            Expanded(child: Text('₹${_money(booking.advanceAmount)}')),
            Expanded(child: Text('₹${_money(booking.totalPrice)}')),
            Expanded(child: Text('₹${_money(balance)}')),
            SizedBox(
              width: 60,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete booking',
                  icon: Icon(
                    Icons.delete_outline,
                    color: crmColors.destructive,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileBookingCard extends StatelessWidget {
  final Booking booking;
  final bool isSelected;
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback onDelete;

  const _MobileBookingCard({
    required this.booking,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final balance =
        ((booking.totalPrice - booking.advanceAmount - booking.discountAmount)
                .clamp(0, double.infinity))
            .toDouble();

    return InkWell(
      onTap: () => context.go('/booking/manage/${booking.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: crmColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(value: isSelected, onChanged: onSelectChanged),
                Expanded(
                  child: Text(
                    booking.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusChip(status: booking.status),
              ],
            ),
            8.h,
            Text(
              '#${booking.displayBookingNumber} • ${booking.service}',
              style: TextStyle(
                color: crmColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (booking.duplicateCount > 1) ...[
              8.h,
              _DuplicateBadge(count: booking.duplicateCount),
            ],
            10.h,
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MiniFinance(
                  label: 'Advance',
                  value: '₹${_money(booking.advanceAmount)}',
                ),
                _MiniFinance(
                  label: 'Total',
                  value: '₹${_money(booking.totalPrice)}',
                ),
                _MiniFinance(label: 'Balance', value: '₹${_money(balance)}'),
                _MiniFinance(
                  label: 'Date',
                  value: _formatDate(booking.bookingDate),
                ),
              ],
            ),
            8.h,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: crmColors.destructive),
                label: Text(
                  'Delete',
                  style: TextStyle(color: crmColors.destructive),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniFinance extends StatelessWidget {
  final String label;
  final String value;

  const _MiniFinance({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: crmColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: crmColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          4.h,
          Text(
            value,
            style: TextStyle(
              color: crmColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateBadge extends StatelessWidget {
  final int count;

  const _DuplicateBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Possible duplicate ($count)',
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'completed':
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green.shade700;
        break;
      case 'cancelled':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade700;
        break;
      case 'confirmed':
        bg = Colors.blue.withValues(alpha: 0.12);
        fg = Colors.blue.shade700;
        break;
      default:
        bg = Colors.amber.withValues(alpha: 0.14);
        fg = Colors.amber.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

String _money(double value) {
  return value.toStringAsFixed(0);
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

class _MonthlySalesSummaryView extends ConsumerWidget {
  final String financialYear;

  const _MonthlySalesSummaryView({required this.financialYear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final asyncBookings = ref.watch(bookingProvider);

    return asyncBookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (allBookings) {
        // Parse FY
        final parts = financialYear.split('-');
        final startYear = int.parse(parts[0]);
        final endYear = 2000 + int.parse(parts[1]);

        final fyStart = DateTime(startYear, 4, 1);
        final fyEnd = DateTime(endYear, 3, 31, 23, 59, 59);

        // Filter bookings for this FY
        final fyBookings = allBookings.where((b) {
          return !b.bookingDate.isBefore(fyStart) &&
              !b.bookingDate.isAfter(fyEnd);
        }).toList();

        // Group by month
        final monthlyStats = <int, _MonthStats>{};
        // Initialize all 12 months (Apr to Mar)
        for (int i = 0; i < 12; i++) {
          final month = (4 + i - 1) % 12 + 1;
          final year = (4 + i > 12) ? endYear : startYear;
          monthlyStats[i] = _MonthStats(month: month, year: year);
        }

        for (final b in fyBookings) {
          int monthIndex;
          if (b.bookingDate.month >= 4) {
            monthIndex = b.bookingDate.month - 4;
          } else {
            monthIndex = b.bookingDate.month + 8;
          }

          final stats = monthlyStats[monthIndex]!;
          stats.totalBookings++;
          if (b.status.toLowerCase() != 'cancelled') {
            stats.totalSales += b.totalPrice;
            stats.advanceCollected += b.advanceAmount;
          }
          if (b.status.toLowerCase() == 'completed') {
            stats.completedCount++;
          } else if (b.status.toLowerCase() == 'cancelled') {
            stats.cancelledCount++;
          }
        }

        final statsList = List.generate(12, (index) => monthlyStats[index]!);

        return Column(
          children: [
            _FYPerformanceChart(
              stats: statsList,
              financialYear: financialYear,
            ),
            24.h,
            Container(
              decoration: BoxDecoration(
                color: crmColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: crmColors.border),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    crmColors.primary.withValues(alpha: 0.05),
                  ),
                  columns: const [
                    DataColumn(label: _HeaderText('MONTH')),
                    DataColumn(label: _HeaderText('BOOKINGS'), numeric: true),
                    DataColumn(label: _HeaderText('GROSS SALES'), numeric: true),
                    DataColumn(label: _HeaderText('ADVANCE'), numeric: true),
                    DataColumn(label: _HeaderText('COMPLETED'), numeric: true),
                    DataColumn(label: _HeaderText('CANCELLED'), numeric: true),
                    DataColumn(label: _HeaderText('ACTION')),
                  ],
                  rows: statsList.map((stats) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '${_monthName(stats.month)} ${stats.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(Text(stats.totalBookings.toString())),
                        DataCell(Text('₹${_money(stats.totalSales)}')),
                        DataCell(Text('₹${_money(stats.advanceCollected)}')),
                        DataCell(Text(stats.completedCount.toString())),
                        DataCell(Text(stats.cancelledCount.toString())),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.download, size: 20),
                            tooltip: 'Download Monthly Report',
                            onPressed: () async {
                              final asyncPackages = ref.read(packagesProvider);
                              final asyncEmployees = ref.read(employeesProvider);
                              
                              if (asyncPackages.value == null || asyncEmployees.value == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Loading requirements...')),
                                );
                                return;
                              }

                              final reportMonth = DateTime(stats.year, stats.month);
                              // We use the full allBookings but filter it specifically for the report logic inside service
                              await downloadDashboardReport(
                                month: reportMonth,
                                bookings: allBookings,
                                packages: asyncPackages.value!,
                                employees: asyncEmployees.value!,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}

class _MonthStats {
  final int month;
  final int year;
  int totalBookings = 0;
  double totalSales = 0;
  double advanceCollected = 0;
  int completedCount = 0;
  int cancelledCount = 0;

  _MonthStats({required this.month, required this.year});
}

class _FYPerformanceChart extends StatelessWidget {
  final List<_MonthStats> stats;
  final String financialYear;

  const _FYPerformanceChart({
    required this.stats,
    required this.financialYear,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final maxSales = stats.fold<double>(
      0,
      (max, s) => s.totalSales > max ? s.totalSales : max,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Financial Performance Chart (FY $financialYear)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _LegendItem(color: crmColors.primary, label: 'Gross Sales'),
                  16.w,
                  _LegendItem(color: crmColors.sidebar, label: 'Advance Collected'),
                ],
              ),
            ],
          ),
          24.h,
          SizedBox(
            height: 300,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: stats.map((s) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _MonthlyBarStack(
                      stats: s,
                      maxSales: maxSales <= 0 ? 1 : maxSales,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        8.w,
        Text(
          label,
          style: TextStyle(
            color: context.crmColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MonthlyBarStack extends StatelessWidget {
  final _MonthStats stats;
  final double maxSales;

  const _MonthlyBarStack({required this.stats, required this.maxSales});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final salesRatio = (stats.totalSales / maxSales).clamp(0.0, 1.0);
    final advanceRatio = (stats.advanceCollected / maxSales).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Bar(
                heightRatio: salesRatio,
                color: crmColors.primary,
                tooltip: 'Sales: ₹${stats.totalSales.toStringAsFixed(0)}',
              ),
              4.w,
              _Bar(
                heightRatio: advanceRatio,
                color: crmColors.sidebar,
                tooltip: 'Advance: ₹${stats.advanceCollected.toStringAsFixed(0)}',
              ),
            ],
          ),
        ),
        8.h,
        Text(
          _monthNameShort(stats.month),
          style: TextStyle(
            color: crmColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _monthNameShort(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }
}

class _Bar extends StatelessWidget {
  final double heightRatio;
  final Color color;
  final String tooltip;

  const _Bar({
    required this.heightRatio,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FractionallySizedBox(
        heightFactor: heightRatio.clamp(0.05, 1.0),
        child: Container(
          width: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                color,
                color.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
