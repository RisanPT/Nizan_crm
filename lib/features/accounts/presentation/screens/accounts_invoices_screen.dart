import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/models/booking.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/providers/booking_provider.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/booking_print_service.dart';
import 'package:nizan_crm/core/utils/gst_calculator.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';

class AccountsInvoicesScreen extends ConsumerStatefulWidget {
  const AccountsInvoicesScreen({super.key});

  @override
  ConsumerState<AccountsInvoicesScreen> createState() =>
      _AccountsInvoicesScreenState();
}

class _AccountsInvoicesScreenState extends ConsumerState<AccountsInvoicesScreen> {
  Booking? _selectedInvoice;
  String _searchQuery = '';
  DateTime? _selectedMonth;
  String _paymentStatusFilter = 'All';
  String _source = 'all'; // all | bookings | trials
  int _currentPage = 1;
  static const int _itemsPerPage = 15;

  String _currency(double v) => '₹${v.toStringAsFixed(2)}';

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatDate(DateTime d) =>
      '${d.day} ${_monthAbbr[d.month - 1]} ${d.year}';

  /// Small status pill used in the receivables hero.
  Widget _pill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          4.w,
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Adapt a Trial into a synthetic Booking so the entire invoices screen and
  // the GST invoice PDF can reuse it unchanged. The first trial look becomes the
  // main service line; the rest become add-on rows on the invoice.
  Booking _bookingFromTrial(Trial t) {
    String label(TrialItem i) => i.lookLabel.trim().isNotEmpty
        ? i.lookLabel.trim()
        : (i.packageName.trim().isNotEmpty ? i.packageName.trim() : 'Trial look');
    final items = t.trialItems;
    final total = items.fold<double>(0, (s, i) => s + i.price);
    final service = items.isEmpty ? 'Makeup Trial' : label(items.first);
    final addons = items.length <= 1
        ? const <BookingAddon>[]
        : items
            .sublist(1)
            .map((i) => BookingAddon(service: label(i), amount: i.price, persons: 1))
            .toList();
    final status = t.status.toLowerCase() == 'completed' ? 'completed' : 'confirmed';
    return Booking(
      id: t.id,
      bookingNumber:
          t.trialNumber.isNotEmpty ? t.trialNumber : 'TRIAL-${t.id}',
      customerName: t.clientName,
      phone: t.phone,
      email: t.email,
      service: service,
      status: status,
      bookingDate: t.trialDate,
      serviceStart: t.trialDate,
      serviceEnd: t.trialDate,
      totalPrice: total,
      advanceAmount: 0,
      addons: addons,
      createdAt: t.createdAt,
      internalRemarks: t.notes,
    );
  }

  String _formatMonthYear(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _changeMonth(int delta) {
    setState(() {
      if (_selectedMonth == null) {
        _selectedMonth = DateTime.now();
      } else {
        _selectedMonth = DateTime(_selectedMonth!.year, _selectedMonth!.month + delta);
      }
      _currentPage = 1;
      _selectedInvoice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final asyncBookings = ref.watch(bookingProvider);
    // Trials (scheduled/completed) become synthetic invoices.
    final trials = ref.watch(allTrialsProvider).value ?? const <Trial>[];
    final trialInvoices = trials
        .where((t) {
          final s = t.status.toLowerCase();
          return s == 'scheduled' || s == 'completed';
        })
        .map(_bookingFromTrial)
        .toList();
    final trialIds = trialInvoices.map((b) => b.id).toSet();

    return Scaffold(
      backgroundColor: crm.background,
      body: asyncBookings.when(
        data: (allBookings) {
          final sourceList = _source == 'trials'
              ? trialInvoices
              : _source == 'bookings'
                  ? allBookings
                  : [...allBookings, ...trialInvoices];
          final filteredInvoices = sourceList.where((b) {
            final status = b.status.toLowerCase();
            if (status != 'confirmed' && status != 'completed') return false;

            if (_searchQuery.isNotEmpty) {
               final matchesSearch = b.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                   b.displayBookingNumber.toLowerCase().contains(_searchQuery.toLowerCase());
               if (!matchesSearch) return false;
            }

            if (_selectedMonth != null) {
              final eventInSelectedMonth = b.bookingDate.year == _selectedMonth!.year &&
                  b.bookingDate.month == _selectedMonth!.month;

              final bookedInSelectedMonth = b.createdAt != null &&
                  b.createdAt!.year == _selectedMonth!.year &&
                  b.createdAt!.month == _selectedMonth!.month;

              final isFutureMonth = (b.bookingDate.year > _selectedMonth!.year) ||
                  (b.bookingDate.year == _selectedMonth!.year && b.bookingDate.month > _selectedMonth!.month);

              final isConfirmedFutureWork = b.status.toLowerCase() == 'confirmed' &&
                  bookedInSelectedMonth &&
                  isFutureMonth;

              if (!eventInSelectedMonth && !isConfirmedFutureWork) {
                return false;
              }
            }

            if (_paymentStatusFilter != 'All') {
               final isPaid = b.isFullyPaid;
               if (_paymentStatusFilter == 'Paid' && !isPaid) return false;
               if (_paymentStatusFilter == 'Due' && isPaid) return false;
               if (_paymentStatusFilter == 'Overdue') {
                 final now = DateTime.now();
                 final todayStart = DateTime(now.year, now.month, now.day);
                 // Overdue = still owing after every work has been completed.
                 if (isPaid || !b.paymentDueDate.isBefore(todayStart)) {
                   return false;
                 }
               }
            }

            return true;
          }).toList()..sort((a, b) {
            final isAdvA = _selectedMonth != null &&
                a.createdAt != null &&
                a.createdAt!.year == _selectedMonth!.year &&
                a.createdAt!.month == _selectedMonth!.month &&
                a.bookingDate.isAfter(a.createdAt!);
            final isAdvB = _selectedMonth != null &&
                b.createdAt != null &&
                b.createdAt!.year == _selectedMonth!.year &&
                b.createdAt!.month == _selectedMonth!.month &&
                b.bookingDate.isAfter(b.createdAt!);

            final dateA = isAdvA ? a.createdAt! : a.bookingDate;
            final dateB = isAdvB ? b.createdAt! : b.bookingDate;
            return dateB.compareTo(dateA);
          });

          final totalPages = (filteredInvoices.length / _itemsPerPage).ceil();
          if (_currentPage > totalPages && totalPages > 0) {
             _currentPage = totalPages;
          } else if (_currentPage < 1) {
             _currentPage = 1;
          }

          final startIndex = (_currentPage - 1) * _itemsPerPage;
          final endIndex = (startIndex + _itemsPerPage < filteredInvoices.length) 
               ? startIndex + _itemsPerPage 
               : filteredInvoices.length;
          
          final paginatedInvoices = filteredInvoices.isEmpty ? <Booking>[] : filteredInvoices.sublist(startIndex, endIndex);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                color: crm.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invoices',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        // Month Selector
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: crm.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 20),
                                onPressed: () => _changeMonth(-1),
                                tooltip: 'Previous Month',
                              ),
                              GestureDetector(
                                onTap: () {
                                  if (_selectedMonth == null) {
                                    setState(() => _selectedMonth = DateTime.now());
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    _selectedMonth == null ? 'All Time' : _formatMonthYear(_selectedMonth!),
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 20),
                                onPressed: () => _changeMonth(1),
                                tooltip: 'Next Month',
                              ),
                              if (_selectedMonth != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(() {
                                    _selectedMonth = null;
                                    _currentPage = 1;
                                    _selectedInvoice = null;
                                  }),
                                  tooltip: 'Clear Month Filter',
                                ),
                            ],
                          ),
                        ),
                        16.w,
                        // Source toggle: All / Bookings / Trials
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            border: Border.all(color: crm.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final s in const [
                                ('all', 'All'),
                                ('bookings', 'Bookings'),
                                ('trials', 'Trials'),
                              ])
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => setState(() {
                                    _source = s.$1;
                                    _currentPage = 1;
                                    _selectedInvoice = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _source == s.$1
                                          ? crm.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(s.$2,
                                        style: TextStyle(
                                            color: _source == s.$1
                                                ? Colors.white
                                                : crm.textSecondary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        16.w,
                        // Status Filter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: crm.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _paymentStatusFilter,
                              isDense: true,
                              items: ['All', 'Paid', 'Due', 'Overdue'].map((s) {
                                return DropdownMenuItem(value: s, child: Text(s));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _paymentStatusFilter = val;
                                    _currentPage = 1;
                                    _selectedInvoice = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        16.w,
                        // Search
                        SizedBox(
                          width: 250,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search in Invoices...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: crm.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: crm.border),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                                _currentPage = 1;
                                _selectedInvoice = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Summary Blocks
              _buildSummaryHeader(filteredInvoices, allBookings, theme, crm),
              const Divider(height: 1),

              // Split View
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Pane: Invoice List
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: crm.surface,
                        child: Column(
                          children: [
                            Expanded(child: _buildInvoiceList(paginatedInvoices, theme, crm, trialIds)),
                            if (totalPages > 1)
                              _buildPagination(totalPages, theme, crm),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedInvoice != null) const VerticalDivider(width: 1),
                    // Right Pane: Detail View
                    if (_selectedInvoice != null)
                      Expanded(
                        flex: 6,
                        child: Container(
                          color: crm.background,
                          child: _buildInvoiceDetail(_selectedInvoice!, theme, crm,
                              trialIds.contains(_selectedInvoice!.id)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: crm.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSummaryHeader(List<Booking> invoices, List<Booking> allBookings, ThemeData theme, CrmTheme crm) {
    double outstanding = 0;
    double dueToday = 0;
    double dueWithin30 = 0;
    double dueLater = 0;
    double overdue = 0;
    double advanceCollected = 0;
    int overdueCount = 0;
    int awaitingWorksCount = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var b in invoices) {
      advanceCollected += b.advanceAmount;
      final bal = b.balanceDue;
      if (bal > 0) {
        outstanding += bal;
        // Age against the date the client actually settles — the LAST work
        // date. A booking part-done this month with works still to come next
        // month is not overdue; it is due on that future date.
        final dDate = b.paymentDueDate;
        final diff = dDate.difference(today).inDays;

        if (diff < 0) {
          overdue += bal;
          overdueCount++;
        } else if (diff == 0) {
          dueToday += bal;
        } else if (diff <= 30) {
          dueWithin30 += bal;
        } else {
          dueLater += bal;
        }
        // Multi-work bookings that still have works to come.
        if (b.isMultiWork && diff >= 0) awaitingWorksCount++;
      }
    }

    final targetMonth = _selectedMonth ?? DateTime.now();
    final isCurrentMonth = targetMonth.year == now.year && targetMonth.month == now.month;
    final monthStr = isCurrentMonth ? 'This Month (${_formatMonthYear(targetMonth)})' : _formatMonthYear(targetMonth);

    int eventCount = 0;
    double eventCollected = 0;
    int bookedCount = 0;
    double bookedAdvance = 0;

    for (var b in allBookings) {
      final status = b.status.toLowerCase();
      if (status != 'confirmed' && status != 'completed') continue;

      if (b.bookingDate.year == targetMonth.year && b.bookingDate.month == targetMonth.month) {
        eventCount++;
        double collected = b.advanceAmount + b.collectedAmount;
        if (b.isFullyPaid) {
          collected = b.totalPrice - b.discountAmount;
        }
        eventCollected += collected;
      }

      if (b.createdAt != null &&
          b.createdAt!.year == targetMonth.year &&
          b.createdAt!.month == targetMonth.month) {
        bookedCount++;
        bookedAdvance += b.advanceAmount;
      }
    }

    final isMobile = ResponsiveBuilder.isMobile(context);
    final overdueColor = Colors.red.shade700;
    final todayColor = Colors.orange.shade700;
    final soonColor = crm.primary;
    final laterColor = crm.textSecondary;

    // Ageing buckets, rendered as a proportional bar + legend.
    final buckets = <(String, double, Color)>[
      ('Overdue', overdue, overdueColor),
      ('Due today', dueToday, todayColor),
      ('Due in 30 days', dueWithin30, soonColor),
      ('Due later', dueLater, laterColor),
    ];
    final bucketTotal = buckets.fold<double>(0, (s, b) => s + b.$2);

    Widget ageingLegend((String, double, Color) b) {
      final pct = bucketTotal <= 0 ? 0.0 : (b.$2 / bucketTotal) * 100;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: b.$3.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: b.$3.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: b.$3, shape: BoxShape.circle),
                ),
                6.w,
                Text(
                  b.$1,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: crm.textSecondary),
                ),
              ],
            ),
            4.h,
            Text(
              _currency(b.$2),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: b.$2 > 0 ? b.$3 : crm.textSecondary,
              ),
            ),
            if (bucketTotal > 0)
              Text(
                '${pct.toStringAsFixed(0)}% of outstanding',
                style: TextStyle(fontSize: 10, color: crm.textSecondary),
              ),
          ],
        ),
      );
    }

    return Container(
      color: crm.surface,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PAYMENT SUMMARY', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: crm.textSecondary)),
          16.h,
          // ── Hero: outstanding vs collected ──────────────────────────────
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isMobile ? 0 : 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        crm.primary.withValues(alpha: 0.10),
                        crm.primary.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: crm.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: crm.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.account_balance_wallet_outlined,
                                color: crm.primary, size: 18),
                          ),
                          10.w,
                          Text(
                            'Total Outstanding Receivables',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: crm.textSecondary),
                          ),
                        ],
                      ),
                      10.h,
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _currency(outstanding),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: crm.textPrimary,
                          ),
                        ),
                      ),
                      8.h,
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (overdueCount > 0)
                            _pill('$overdueCount overdue',
                                overdueColor, Icons.priority_high),
                          if (awaitingWorksCount > 0)
                            _pill('$awaitingWorksCount awaiting works',
                                soonColor, Icons.event_repeat_outlined),
                          if (outstanding <= 0)
                            _pill('All settled', Colors.green.shade700,
                                Icons.check_circle_outline),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              isMobile ? 12.h : 16.w,
              Expanded(
                flex: isMobile ? 0 : 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.savings_outlined,
                                color: Colors.green.shade700, size: 18),
                          ),
                          10.w,
                          Expanded(
                            child: Text(
                              'Advance Collected',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: crm.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      10.h,
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _currency(advanceCollected),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          16.h,
          // ── Ageing bar ──────────────────────────────────────────────────
          if (bucketTotal > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (final b in buckets)
                      if (b.$2 > 0)
                        Expanded(
                          flex: ((b.$2 / bucketTotal) * 1000).round().clamp(1, 1000),
                          child: Container(color: b.$3),
                        ),
                  ],
                ),
              ),
            ),
            12.h,
          ],
          GridView.count(
            crossAxisCount: isMobile ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isMobile ? 2.1 : 2.9,
            children: [for (final b in buckets) ageingLegend(b)],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: crm.primary.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.calendar_month, color: crm.primary, size: 24),
                      ),
                      16.w,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Events in $monthStr',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: crm.primary,
                              ),
                            ),
                            4.h,
                            Text(
                              'We have $eventCount works with event date in $monthStr',
                              style: theme.textTheme.bodySmall?.copyWith(color: crm.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currency(eventCollected),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          4.h,
                          Text(
                            'Amount Collected',
                            style: theme.textTheme.bodySmall?.copyWith(color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              16.w,
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bookmark_outline, color: Colors.teal.shade700, size: 24),
                      ),
                      16.w,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bookings in $monthStr',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            4.h,
                            Text(
                              'We have $bookedCount bookings created in $monthStr',
                              style: theme.textTheme.bodySmall?.copyWith(color: crm.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currency(bookedAdvance),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          4.h,
                          Text(
                            'Advance Collected',
                            style: theme.textTheme.bodySmall?.copyWith(color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(List<Booking> invoices, ThemeData theme, CrmTheme crm,
      Set<String> trialIds) {
    if (invoices.isEmpty) {
      return const Center(child: Text('No invoices found.'));
    }
    return ListView.separated(
      itemCount: invoices.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: crm.border),
      itemBuilder: (context, index) {
        final b = invoices[index];
        final isSelected = _selectedInvoice?.id == b.id;
        final isTrial = trialIds.contains(b.id);

        final isAdvanceRow = _selectedMonth != null &&
            b.createdAt != null &&
            b.createdAt!.year == _selectedMonth!.year &&
            b.createdAt!.month == _selectedMonth!.month &&
            ((b.bookingDate.year > _selectedMonth!.year) ||
             (b.bookingDate.year == _selectedMonth!.year && b.bookingDate.month > _selectedMonth!.month));

        final settled = isAdvanceRow || b.isFullyPaid;
        final today = DateTime.now();
        final isOverdue = !settled &&
            b.paymentDueDate
                .isBefore(DateTime(today.year, today.month, today.day));
        final status = settled ? 'PAID' : (isOverdue ? 'OVERDUE' : 'DUE');
        final statusColor = settled
            ? Colors.green.shade700
            : (isOverdue ? Colors.red.shade700 : Colors.orange.shade700);
        final amountToDisplay = isAdvanceRow ? b.advanceAmount : b.totalPrice;
        final customerNameSuffix = isAdvanceRow ? ' (ADVANCE)' : '';

        return Container(
          decoration: BoxDecoration(
            // Accent bar makes the selected invoice obvious next to the preview.
            border: Border(
              left: BorderSide(
                color: isSelected ? crm.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: ListTile(
          selected: isSelected,
          selectedTileColor: crm.primary.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          onTap: () => setState(() => _selectedInvoice = b),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(b.displayBookingNumber,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: crm.primary)),
                        ),
                        if (isTrial) ...[
                          6.w,
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('TRIAL',
                                style: TextStyle(
                                    color: Color(0xFF8B5CF6),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    4.h,
                    Text(
                      // Multi-work bookings settle on the final work date, so
                      // show that rather than just the first booking date.
                      b.isMultiWork
                          ? '${b.workDates.length} works · due ${_formatDate(b.paymentDueDate)}'
                          : _formatDate(b.bookingDate),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: crm.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text('${b.customerName}$customerNameSuffix'.toUpperCase(), style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.30)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_currency(amountToDisplay),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (!isAdvanceRow) ...[
                      2.h,
                      // Balance is what Accounts chases, so lead with it.
                      Text(
                        b.balanceDue > 0
                            ? 'Bal: ${_currency(b.balanceDue)}'
                            : 'Adv: ${_currency(b.advanceAmount)}',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: b.balanceDue > 0
                              ? statusColor
                              : crm.textSecondary,
                          fontSize: 11,
                          fontWeight: b.balanceDue > 0
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildPagination(int totalPages, ThemeData theme, CrmTheme crm) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: crm.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Page $_currentPage of $totalPages', style: theme.textTheme.bodySmall),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => setState(() {
                          _currentPage--;
                          _selectedInvoice = null;
                        })
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < totalPages
                    ? () => setState(() {
                          _currentPage++;
                          _selectedInvoice = null;
                        })
                    : null,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInvoiceDetail(
      Booking b, ThemeData theme, CrmTheme crm, bool isTrial) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detail Header Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: crm.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    b.displayBookingNumber,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (isTrial) ...[
                    8.w,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('TRIAL',
                          style: TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  if (!isTrial) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        await printBookingDetails(
                          b,
                          variant: BookingPrintVariant.clientAdvanceReceipt,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Print Advance Receipt'),
                    ),
                    12.w,
                  ],
                  ElevatedButton.icon(
                    onPressed: () async {
                      await printBookingDetails(
                        b,
                        variant: isTrial
                            ? BookingPrintVariant.trialInvoice
                            : BookingPrintVariant.clientInvoice,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: crm.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print, size: 16),
                    label: Text(
                        isTrial ? 'Print Trial Invoice' : 'Print Full GST Invoice'),
                  ),
                  12.w,
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedInvoice = null),
                  ),
                ],
              )
            ],
          ),
        ),
        const Divider(height: 1),
        // Invoice Preview Paper
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                  border: Border.all(color: crm.border),
                ),
                child: _buildPreviewPaper(b, theme, crm),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPaper(Booking b, ThemeData theme, CrmTheme crm) {
    final isAdvanceRow = _selectedMonth != null &&
        b.createdAt != null &&
        b.createdAt!.year == _selectedMonth!.year &&
        b.createdAt!.month == _selectedMonth!.month &&
        ((b.bookingDate.year > _selectedMonth!.year) ||
         (b.bookingDate.year == _selectedMonth!.year && b.bookingDate.month > _selectedMonth!.month));

    final bal = b.balanceDue;
    final pkgAmount = b.totalPrice - b.addons.fold<double>(0, (s, a) => s + (a.amount * a.persons));
    final maroon = const Color(0xFF601a29);
    final totalCgst = GstCalculator.cgst(b.totalPrice);
    final totalSgst = GstCalculator.sgst(b.totalPrice);
    final totalGst = totalCgst + totalSgst;
    
    final invoiceStatus = (b.status.toLowerCase() == 'confirmed' || b.status.toLowerCase() == 'completed') ? 'APPROVED' : 'PENDING';

    return Stack(
      children: [
        if (isAdvanceRow || bal <= 0)
          Positioned(
            top: 40,
            left: -40,
            child: Transform.rotate(
              angle: -0.785398,
              child: Container(
                color: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 8),
                child: const Text('PAID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER (Centered)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/teamn_logo.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  8.h,
                  Text('TEAM N MAKEOVERS', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: maroon, letterSpacing: 1.2)),
                  Text(isAdvanceRow ? 'ADVANCE RECEIPT' : 'GST INVOICE', style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1, color: Colors.grey.shade700)),
                ],
              ),
              24.h,
              
              // INVOICE META ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text('INVOICE NO.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500, letterSpacing: 1, fontSize: 10)),
                      4.h,
                      Text(b.displayBookingNumber, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ]
                  ),
                  32.w,
                  Column(
                    children: [
                      Text('DATE', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500, letterSpacing: 1, fontSize: 10)),
                      4.h,
                      Text('${b.bookingDate.day.toString().padLeft(2, '0')}/${b.bookingDate.month.toString().padLeft(2, '0')}/${b.bookingDate.year}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ]
                  ),
                  32.w,
                  Column(
                    children: [
                      Text('STATUS', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500, letterSpacing: 1, fontSize: 10)),
                      4.h,
                      Text((isAdvanceRow || bal <= 0) ? 'PAID' : invoiceStatus, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                    ]
                  ),
                ],
              ),
              
              24.h,
              const Divider(height: 1),
              24.h,
              
              // BOXES
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BILLED TO', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1)),
                          12.h,
                          Text(b.customerName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: maroon)),
                          8.h,
                          if (b.phone.isNotEmpty) _pdfInfoRow('Phone', b.phone, theme),
                          if (b.secondaryContact.isNotEmpty) _pdfInfoRow('Alt. Phone', b.secondaryContact, theme),
                          if (b.email.isNotEmpty) _pdfInfoRow('Email', b.email, theme),
                          if (b.address.isNotEmpty) _pdfInfoRow('Address', b.address, theme),
                          if (b.region.isNotEmpty) _pdfInfoRow('District', b.region, theme),
                        ],
                      ),
                    ),
                  ),
                  16.w,
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COMPANY DETAILS', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1)),
                          12.h,
                          Text('TEAM N MAKEOVERS', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: maroon)),
                          8.h,
                          Text('Kozhikode Kerala 673014\nIndia', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF1f2937), height: 1.5)),
                          8.h,
                          _pdfInfoRow('GSTIN', '32AAJCN6432D1ZR', theme),
                          _pdfInfoRow('Phone', '9645424283', theme),
                          _pdfInfoRow('Email', 'teamnfinance@gmail.com', theme),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              32.h,
              // SERVICES HEADER
              Row(
                children: [
                  Container(width: 4, height: 16, color: maroon),
                  8.w,
                  Text('SERVICES', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: maroon, letterSpacing: 1)),
                ],
              ),
              16.h,
              
              // SERVICES TABLE
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: isAdvanceRow
                    ? const {
                        0: FlexColumnWidth(3.5),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.5),
                      }
                    : const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(0.8),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1),
                        5: FlexColumnWidth(1.2),
                      },
                children: [
                  TableRow(
                    children: [
                      _pdfTh('SERVICE', theme),
                      _pdfTh('HSN / SAC', theme, center: true),
                      _pdfTh(isAdvanceRow ? 'RATE' : 'BASE AMT', theme, right: true),
                      if (!isAdvanceRow) ...[
                        _pdfTh('CGST 2.5%', theme, right: true),
                        _pdfTh('SGST 2.5%', theme, right: true),
                      ],
                      _pdfTh(isAdvanceRow ? 'AMOUNT' : 'TOTAL (INCL. GST)', theme, right: true),
                    ],
                  ),
                  TableRow(
                    children: [
                      _pdfTd(b.service, theme),
                      _pdfTdCenter(GstCalculator.defaultSacCode, theme),
                      _pdfTdRight(_currency(isAdvanceRow ? pkgAmount : GstCalculator.baseAmount(pkgAmount)), theme),
                      if (!isAdvanceRow) ...[
                        _pdfTdBoldRight(_currency(GstCalculator.cgst(pkgAmount)), theme),
                        _pdfTdBoldRight(_currency(GstCalculator.sgst(pkgAmount)), theme),
                      ],
                      _pdfTdBoldRight(_currency(pkgAmount), theme),
                    ],
                  ),
                  for (final addon in b.addons)
                    TableRow(
                      children: [
                        _pdfTd('${addon.service}${addon.persons > 1 ? ' × ${addon.persons}' : ''}', theme),
                        _pdfTdCenter(GstCalculator.defaultSacCode, theme),
                        _pdfTdRight(_currency(isAdvanceRow ? addon.amount * addon.persons : GstCalculator.baseAmount(addon.amount * addon.persons)), theme),
                        if (!isAdvanceRow) ...[
                          _pdfTdBoldRight(_currency(GstCalculator.cgst(addon.amount * addon.persons)), theme),
                          _pdfTdBoldRight(_currency(GstCalculator.sgst(addon.amount * addon.persons)), theme),
                        ],
                        _pdfTdBoldRight(_currency(addon.amount * addon.persons), theme),
                      ],
                    )
                ],
              ),
              
              24.h,
              // SUMMARY TABLE
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 380,
                  child: Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const { 0: FlexColumnWidth(2), 1: FlexColumnWidth(1) },
                    children: [
                      _summaryTableRow(isAdvanceRow ? 'Total Received' : 'Subtotal (Incl. GST)', _currency(isAdvanceRow ? b.advanceAmount : b.totalPrice), theme),
                      if (!isAdvanceRow && b.discountAmount > 0)
                        _summaryTableRow('Discount', '- ${_currency(b.discountAmount)}', theme),
                      if (!isAdvanceRow) ...[
                        _summaryTableRowGST('CGST @ 2.5%', _currency(totalCgst), theme),
                        _summaryTableRowGST('SGST @ 2.5%', _currency(totalSgst), theme),
                        _summaryTableRow('Total GST', _currency(totalGst), theme),
                        _summaryTableRow('Advance Paid', _currency(b.advanceAmount), theme),
                      ],
                      if (!isAdvanceRow && b.collectedAmount > 0)
                        _summaryTableRow('Artist Collected', _currency(b.collectedAmount), theme),
                      _summaryTableRowBalance('BALANCE DUE', _currency(isAdvanceRow ? 0.0 : bal), theme),
                    ],
                  ),
                ),
              ),

              // Multi-work bookings are settled only after the final work, so
              // spell out when the balance actually falls due.
              if (!isAdvanceRow && bal > 0 && b.isMultiWork) ...[
                8.h,
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Payable on completion of all ${b.workDates.length} works · due ${_formatDate(b.paymentDueDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],

              32.h,
              // FOOTER
              const Divider(height: 1, color: Color(0xFFD9DDE3)),
              16.h,
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('✓ Price inclusive of GST @ 5%  |  SAC: 998361', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                ),
              ),
              16.h,
              Text('Terms & Conditions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: maroon)),
              8.h,
              Text(
                '1. The booking advance payment is non-refundable and non-transferable under any circumstances.\n'
                '2. Any additional services requested on the event day will be charged extra as per actual costs.\n'
                '3. The remaining balance must be fully paid on or before the event date prior to service completion.\n'
                '4. Please ensure power supply and standard mirror / lighting setups are available at the service location.',
                style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF4b5563), height: 1.8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pdfInfoRow(String key, String val, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70, 
            child: Text(key, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF4b5563), fontWeight: FontWeight.w600))
          ),
          Expanded(
            child: Text(val, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF1f2937)))
          ),
        ],
      ),
    );
  }

  Widget _pdfTh(String text, ThemeData theme, {bool right = false, bool center = false}) {
    TextAlign align = TextAlign.left;
    if (right) align = TextAlign.right;
    if (center) align = TextAlign.center;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(text, textAlign: align, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade400, fontSize: 11)),
    );
  }

  Widget _pdfTd(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF1f2937))),
    );
  }
  
  Widget _pdfTdCenter(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF1f2937))),
    );
  }
  
  Widget _pdfTdRight(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(text, textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF1f2937))),
    );
  }
  
  Widget _pdfTdBoldRight(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(text, textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF1f2937))),
    );
  }

  TableRow _summaryTableRow(String label, String val, ThemeData theme) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(label, textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF4b5563))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(val, textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1f2937))),
        ),
      ],
    );
  }

  TableRow _summaryTableRowGST(String label, String val, ThemeData theme) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFf0fdf4)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(label, textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF4b5563))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(val, textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1f2937))),
        ),
      ],
    );
  }

  TableRow _summaryTableRowBalance(String label, String val, ThemeData theme) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFF601a29)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(label, textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(val, textAlign: TextAlign.right, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

}
