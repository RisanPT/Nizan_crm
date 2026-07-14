import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/booking_print_service.dart';
import '../../core/utils/gst_calculator.dart';

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
  int _currentPage = 1;
  static const int _itemsPerPage = 15;

  String _currency(double v) => '₹${v.toStringAsFixed(2)}';

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

    return Scaffold(
      backgroundColor: crm.background,
      body: asyncBookings.when(
        data: (allBookings) {
          final filteredInvoices = allBookings.where((b) {
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
                              items: ['All', 'Paid', 'Due'].map((s) {
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
                            Expanded(child: _buildInvoiceList(paginatedInvoices, theme, crm)),
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
                          child: _buildInvoiceDetail(_selectedInvoice!, theme, crm),
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
    double overdue = 0;
    double advanceCollected = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var b in invoices) {
      advanceCollected += b.advanceAmount;
      final bal = b.balanceDue;
      if (bal > 0) {
        outstanding += bal;
        final dDate = DateTime(b.bookingDate.year, b.bookingDate.month, b.bookingDate.day);
        final diff = dDate.difference(today).inDays;
        
        if (diff < 0) {
          overdue += bal;
        } else if (diff == 0) {
          dueToday += bal;
        } else if (diff <= 30) {
          dueWithin30 += bal;
        }
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

    Widget statCard(String title, String value, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodySmall?.copyWith(color: crm.textSecondary)),
          4.h,
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
        ],
      );
    }

    return Container(
      color: crm.surface,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PAYMENT SUMMARY', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: crm.textSecondary)),
          16.h,
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
                child: Icon(Icons.arrow_downward, color: Colors.orange.shade800),
              ),
              16.w,
              Expanded(child: statCard('Total Outstanding Receivables', _currency(outstanding), crm.textPrimary)),
              Expanded(child: statCard('Advance Collected', _currency(advanceCollected), Colors.green.shade700)),
              Expanded(child: statCard('Due Today', _currency(dueToday), Colors.orange.shade700)),
              Expanded(child: statCard('Due Within 30 Days', _currency(dueWithin30), crm.textPrimary)),
              Expanded(child: statCard('Overdue Invoice', _currency(overdue), Colors.red.shade700)),
            ],
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

  Widget _buildInvoiceList(List<Booking> invoices, ThemeData theme, CrmTheme crm) {
    if (invoices.isEmpty) {
      return const Center(child: Text('No invoices found.'));
    }
    return ListView.separated(
      itemCount: invoices.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: crm.border),
      itemBuilder: (context, index) {
        final b = invoices[index];
        final isSelected = _selectedInvoice?.id == b.id;

        final isAdvanceRow = _selectedMonth != null &&
            b.createdAt != null &&
            b.createdAt!.year == _selectedMonth!.year &&
            b.createdAt!.month == _selectedMonth!.month &&
            ((b.bookingDate.year > _selectedMonth!.year) ||
             (b.bookingDate.year == _selectedMonth!.year && b.bookingDate.month > _selectedMonth!.month));

        final status = isAdvanceRow ? 'PAID' : (b.isFullyPaid ? 'PAID' : 'DUE');
        final statusColor = (isAdvanceRow || b.isFullyPaid) ? Colors.green : Colors.orange;
        final amountToDisplay = isAdvanceRow ? b.advanceAmount : b.totalPrice;
        final customerNameSuffix = isAdvanceRow ? ' (ADVANCE)' : '';

        return ListTile(
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
                    Text(b.displayBookingNumber, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: crm.primary)),
                    4.h,
                    Text('${b.bookingDate.day}/${b.bookingDate.month}/${b.bookingDate.year}', style: theme.textTheme.bodySmall?.copyWith(color: crm.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text('${b.customerName}$customerNameSuffix'.toUpperCase(), style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  status,
                  style: theme.textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_currency(amountToDisplay), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (!isAdvanceRow) ...[
                      2.h,
                      Text('Adv: ${_currency(b.advanceAmount)}', style: theme.textTheme.bodySmall?.copyWith(color: crm.textSecondary, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
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

  Widget _buildInvoiceDetail(Booking b, ThemeData theme, CrmTheme crm) {
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
              Text(
                b.displayBookingNumber,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
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
                  ElevatedButton.icon(
                    onPressed: () async {
                      await printBookingDetails(
                        b,
                        variant: BookingPrintVariant.clientInvoice,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: crm.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print Full GST Invoice'),
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
