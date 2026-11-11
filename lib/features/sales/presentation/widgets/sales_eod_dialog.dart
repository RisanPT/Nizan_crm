import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/sales/data/sales_eod_report.dart';
import 'package:nizan_crm/features/sales/services/sales_eod_service.dart';
import 'package:nizan_crm/features/sales/utils/sales_eod_pdf.dart';
import 'package:nizan_crm/services/user_service.dart';

final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _countFmt = NumberFormat.decimalPattern('en_IN');

/// Displays the Sales End of Day (EOD) dialog with live daily metrics,
/// breakdown of calls, leads, closed bookings, and direct PDF download.
Future<void> showSalesEodDialog(
  BuildContext context, {
  String? initialDate,
  String? initialSalesPersonId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _SalesEodDialog(
      initialDate: initialDate,
      initialSalesPersonId: initialSalesPersonId,
    ),
  );
}

class _SalesEodDialog extends ConsumerStatefulWidget {
  final String? initialDate;
  final String? initialSalesPersonId;

  const _SalesEodDialog({
    this.initialDate,
    this.initialSalesPersonId,
  });

  @override
  ConsumerState<_SalesEodDialog> createState() => _SalesEodDialogState();
}

class _SalesEodDialogState extends ConsumerState<_SalesEodDialog> {
  late DateTime _selectedDate;
  DateTimeRange? _selectedDateRange;
  String? _selectedSalesPersonId;
  int _activeTabIndex = 0;
  bool _isDownloading = false;
  bool _isPrinting = false;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      try {
        final parts = widget.initialDate!.split('-').map(int.parse).toList();
        _selectedDate = DateTime(parts[0], parts[1], parts[2]);
      } catch (_) {
        _selectedDate = DateTime.now();
      }
    } else {
      _selectedDate = DateTime.now();
    }
    _selectedSalesPersonId = widget.initialSalesPersonId;
  }

  bool get _isRange => _selectedDateRange != null;
  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF601A29),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedDateRange = null;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now.add(const Duration(days: 30)),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: _selectedDate.subtract(const Duration(days: 6)),
            end: _selectedDate,
          ),
      saveText: 'Apply Range',
      helpText: 'Select Date Range for EOD / Ledger',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF601A29),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  /// The query shown on screen (set in build). Exports re-fetch it first so
  /// the file always has the latest numbers — e.g. a manual lead count that
  /// was edited after this dialog loaded.
  SalesEodQuery? _query;

  Future<SalesEodReport> _latest(SalesEodReport shown) async {
    final q = _query;
    if (q == null) return shown;
    return ref.refresh(salesEodReportProvider(q).future);
  }

  Future<void> _handleDownloadPdf(SalesEodReport report) async {
    setState(() => _isDownloading = true);
    try {
      report = await _latest(report);
      await downloadSalesEodPdf(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('EOD Report for ${report.date} downloaded successfully.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleDownloadCsv(SalesEodReport report) async {
    try {
      report = await _latest(report);
      await downloadSalesEodCsv(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('EOD CSV for ${report.date} downloaded successfully.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _handlePrintPdf(SalesEodReport report) async {
    setState(() => _isPrinting = true);
    try {
      report = await _latest(report);
      await printSalesEodPdf(report);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handleCopySummary(SalesEodReport report) async {
    try {
      report = await _latest(report);
      final text = formatSalesEodWhatsAppText(report);
      await Clipboard.setData(ClipboardData(text: text));

      setState(() => _isCopied = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'EOD summary copied to clipboard! Ready to paste into WhatsApp.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isCopied = false);
      });
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final role = session?.role ?? 'sales';
    final isSalesExec = role == 'sales' || role == 'sales_executive';

    final query = (
      date: _isRange ? null : _dateStr,
      from: _isRange ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start) : null,
      to: _isRange ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end) : null,
      salesPersonId: isSalesExec ? null : _selectedSalesPersonId,
    );

    _query = query;
    final asyncReport = ref.watch(salesEodReportProvider(query));
    final usersAsync = ref.watch(crmUsersProvider);

    final isToday = !_isRange && DateFormat('yyyy-MM-dd').format(DateTime.now()) == _dateStr;
    final isYesterday = !_isRange &&
        DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1))) == _dateStr;

    final String dateDisplay;
    if (_isRange) {
      final s = DateFormat('d MMM yy').format(_selectedDateRange!.start);
      final e = DateFormat('d MMM yy').format(_selectedDateRange!.end);
      dateDisplay = '$s  to  $e';
    } else {
      dateDisplay = DateFormat('EEE, d MMM yyyy').format(_selectedDate);
    }

    return Dialog(
      backgroundColor: crm.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 960,
          maxHeight: 900,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // 1. Header with Gradient Accent
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                decoration: BoxDecoration(
                  color: crm.surface,
                  border: Border(bottom: BorderSide(color: crm.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF601A29), Color(0xFF8B2539)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.summarize_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'End of Day (EOD) Report',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: crm.textPrimary,
                                  ),
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'TODAY',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSalesExec
                                ? 'Your daily activity, closed bookings, and revenue summary'
                                : 'Daily performance, bookings, and team activity audit',
                            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // 2. Filter & Date Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: crm.background,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    // Date button
                    InkWell(
                      onTap: _isRange ? _pickDateRange : _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: crm.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isRange ? const Color(0xFF601A29) : crm.border,
                            width: _isRange ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isRange ? Icons.date_range_rounded : Icons.calendar_today_rounded,
                              size: 16,
                              color: const Color(0xFF601A29),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateDisplay,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: crm.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down_rounded, size: 20, color: crm.textSecondary),
                          ],
                        ),
                      ),
                    ),

                    // Quick Chips & Custom Range
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _QuickDateChip(
                          label: 'Today',
                          isSelected: isToday,
                          onTap: () => setState(() {
                            _selectedDate = DateTime.now();
                            _selectedDateRange = null;
                          }),
                        ),
                        _QuickDateChip(
                          label: 'Yesterday',
                          isSelected: isYesterday,
                          onTap: () => setState(() {
                            _selectedDate = DateTime.now().subtract(const Duration(days: 1));
                            _selectedDateRange = null;
                          }),
                        ),
                        // Custom Range Button
                        InkWell(
                          onTap: _pickDateRange,
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isRange ? const Color(0xFF601A29) : crm.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isRange ? const Color(0xFF601A29) : crm.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.date_range_rounded,
                                  size: 14,
                                  color: _isRange ? Colors.white : crm.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isRange
                                      ? 'Custom (${_selectedDateRange!.duration.inDays + 1}d)'
                                      : 'Custom Range',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _isRange ? FontWeight.bold : FontWeight.w500,
                                    color: _isRange ? Colors.white : crm.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isRange) ...[
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            tooltip: 'Reset to Single Day',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            onPressed: () => setState(() => _selectedDateRange = null),
                          ),
                        ],
                      ],
                    ),

                    // Manager Dropdown for Sales Reps
                    if (!isSalesExec)
                      usersAsync.maybeWhen(
                        data: (users) {
                          final salesUsers = users
                              .where((u) => ['sales', 'sales_executive', 'sales_manager']
                                  .contains(u.role.toLowerCase()))
                              .toList();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: crm.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: crm.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedSalesPersonId,
                                hint: const Text('All Team (Roll-up)', style: TextStyle(fontSize: 12.5)),
                                icon: const Icon(Icons.person_outline_rounded, size: 18),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Team (Roll-up)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                  ),
                                  for (final u in salesUsers)
                                    DropdownMenuItem<String?>(
                                      value: u.id,
                                      // Capped so a long name can't push the picker off a phone screen.
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 220),
                                        child: Text(
                                          '${u.name} (${u.role})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12.5),
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedSalesPersonId = val);
                                },
                              ),
                            ),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),

              // 3. Body Content
              Expanded(
                child: asyncReport.when(
                  loading: () => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF601A29)),
                        const SizedBox(height: 14),
                        Text(
                          'Loading EOD metrics for $dateDisplay...',
                          style: TextStyle(fontSize: 13, color: crm.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load EOD Report',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: crm.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(e.toString(), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry'),
                            onPressed: () => ref.invalidate(salesEodReportProvider(query)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (report) {
                    final s = report.summary;

                    return Column(
                      children: [
                        // Metric KPI Cards
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 600;
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MetricCard(
                                          title: 'Calls Made',
                                          value: '${s.callsMade}',
                                          subtext: '${s.callsConnected} connected',
                                          icon: Icons.phone_in_talk_rounded,
                                          accentColor: const Color(0xFF2563EB),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MetricCard(
                                          title: 'Bookings Closed',
                                          value: '${s.bookingsCount}',
                                          subtext: '${s.leadsConverted} leads converted',
                                          icon: Icons.check_circle_rounded,
                                          accentColor: const Color(0xFF16A34A),
                                        ),
                                      ),
                                      if (!isNarrow) ...[
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _MetricCard(
                                            title: 'Booked Revenue',
                                            value: _currFmt.format(s.totalRevenue),
                                            subtext: 'Adv: ${_currFmt.format(s.totalAdvance)}',
                                            icon: Icons.currency_rupee_rounded,
                                            accentColor: const Color(0xFF601A29),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _MetricCard(
                                            title: 'Follow-ups',
                                            value: '${s.followUpsCompleted}',
                                            subtext: '${s.pendingFollowUpsCount} due / pending',
                                            icon: Icons.event_repeat_rounded,
                                            accentColor: const Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isNarrow) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _MetricCard(
                                            title: 'Booked Revenue',
                                            value: _currFmt.format(s.totalRevenue),
                                            subtext: 'Adv: ${_currFmt.format(s.totalAdvance)}',
                                            icon: Icons.currency_rupee_rounded,
                                            accentColor: const Color(0xFF601A29),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _MetricCard(
                                            title: 'Follow-ups',
                                            value: '${s.followUpsCompleted}',
                                            subtext: '${s.pendingFollowUpsCount} due / pending',
                                            icon: Icons.event_repeat_rounded,
                                            accentColor: const Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),

                        // Tab Selection
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _TabItem(
                                  label: 'EOD Sheet',
                                  icon: Icons.table_view_rounded,
                                  isSelected: _activeTabIndex == 0,
                                  onTap: () => setState(() => _activeTabIndex = 0),
                                ),
                                const SizedBox(width: 6),
                                _TabItem(
                                  label: 'Team Ledger',
                                  icon: Icons.grid_on_rounded,
                                  isSelected: _activeTabIndex == 1,
                                  onTap: () => setState(() => _activeTabIndex = 1),
                                ),
                                const SizedBox(width: 6),
                                _TabItem(
                                  label: 'Bookings (${report.bookings.length})',
                                  icon: Icons.receipt_long_rounded,
                                  isSelected: _activeTabIndex == 2,
                                  onTap: () => setState(() => _activeTabIndex = 2),
                                ),
                                const SizedBox(width: 6),
                                _TabItem(
                                  label: 'Activity Log (${report.activities.length})',
                                  icon: Icons.history_rounded,
                                  isSelected: _activeTabIndex == 3,
                                  onTap: () => setState(() => _activeTabIndex = 3),
                                ),
                                const SizedBox(width: 6),
                                _TabItem(
                                  label: 'Due Follow-ups (${report.pendingFollowUps.length})',
                                  icon: Icons.schedule_rounded,
                                  isSelected: _activeTabIndex == 4,
                                  onTap: () => setState(() => _activeTabIndex = 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),

                        // Tab View Contents
                        Expanded(
                          child: IndexedStack(
                            index: _activeTabIndex,
                            children: [
                              // 0. EOD Spreadsheet View (Screenshots 2 & 3)
                              _EodSpreadsheetView(report: report, crm: crm),

                              // 1. Team Ledger Table View (Screenshot 1)
                              _TeamLedgerTableView(report: report, crm: crm),

                              // 2. Bookings Tab
                              _BookingsList(bookings: report.bookings, crm: crm),

                              // 3. Activity Log Tab
                              _ActivityList(activities: report.activities, crm: crm),

                              // 4. Due Follow-ups Tab
                              _FollowUpsList(followUps: report.pendingFollowUps, crm: crm),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // 4. Action Bar (Download PDF, Print, Share)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: crm.surface,
                  border: Border(top: BorderSide(color: crm.border)),
                ),
                child: Row(
                  children: [
                    // Copy Summary Button (Flexible: on a phone the labels
                    // shorten with an ellipsis instead of overflowing)
                    Flexible(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                          size: 16,
                          color: _isCopied ? const Color(0xFF16A34A) : const Color(0xFF601A29),
                        ),
                        label: Text(
                          _isCopied ? 'Copied!' : 'Copy Summary',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _isCopied ? const Color(0xFF16A34A) : crm.textPrimary,
                            fontWeight: _isCopied ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          side: BorderSide(
                            color: _isCopied ? const Color(0xFF16A34A) : crm.border,
                            width: _isCopied ? 1.5 : 1,
                          ),
                          backgroundColor: _isCopied ? const Color(0xFF16A34A).withValues(alpha: 0.1) : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: asyncReport.hasValue
                            ? () => _handleCopySummary(asyncReport.requireValue)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Print
                    IconButton.outlined(
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_rounded, size: 18),
                      tooltip: 'Print Report',
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: crm.border),
                      ),
                      onPressed: asyncReport.hasValue && !_isPrinting
                          ? () => _handlePrintPdf(asyncReport.requireValue)
                          : null,
                    ),

                    const SizedBox(width: 10),

                    // Download CSV
                    IconButton.outlined(
                      icon: const Icon(Icons.table_view_rounded, size: 18),
                      tooltip: 'Download CSV',
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: crm.border),
                      ),
                      onPressed: asyncReport.hasValue
                          ? () => _handleDownloadCsv(asyncReport.requireValue)
                          : null,
                    ),

                    const SizedBox(width: 10),

                    // Primary: Download PDF Button (right-aligned in the space left)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                          label: Text(
                            _isDownloading ? 'Generating...' : 'Download PDF',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF601A29), // Team N Maroon
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: asyncReport.hasValue && !_isDownloading
                              ? () => _handleDownloadPdf(asyncReport.requireValue)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SUB-COMPONENTS
// ---------------------------------------------------------------------------

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtext;
  final IconData icon;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: crm.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: crm.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: crm.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF601A29).withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: const Color(0xFF601A29).withValues(alpha: 0.3)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF601A29) : crm.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF601A29) : crm.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickDateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF601A29) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF601A29) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final List<SalesEodBooking> bookings;
  final CrmTheme crm;

  const _BookingsList({required this.bookings, required this.crm});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, size: 40, color: crm.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text('No bookings closed on this date', style: TextStyle(color: crm.textSecondary, fontSize: 13.5)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final b = bookings[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: crm.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.bookmark_added_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  b.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: crm.textPrimary),
                                ),
                              ),
                              if (b.bookingNumber.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '#${b.bookingNumber}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: crm.textSecondary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currFmt.format(b.totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${b.service}  ·  ${b.phone}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: crm.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Adv: ${_currFmt.format(b.advanceAmount)}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityList extends StatelessWidget {
  final List<SalesEodActivity> activities;
  final CrmTheme crm;

  const _ActivityList({required this.activities, required this.crm});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_missed_rounded, size: 40, color: crm.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text('No activities recorded on this date', style: TextStyle(color: crm.textSecondary, fontSize: 13.5)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = activities[i];
        final isConnected = a.callResponse.toLowerCase() == 'connected';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: crm.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                      : const Color(0xFF64748B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  a.type == 'call' ? Icons.phone_rounded : Icons.task_alt_rounded,
                  color: isConnected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  a.leadName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: crm.textPrimary),
                                ),
                              ),
                              if (a.leadPhone.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '(${a.leadPhone})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                                  : const Color(0xFFD97706).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              a.callResponse.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isConnected ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (a.remark.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        a.remark,
                        style: TextStyle(fontSize: 12, color: crm.textSecondary),
                      ),
                    ],
                    if (a.time.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        a.time,
                        style: TextStyle(fontSize: 10.5, color: crm.textSecondary.withValues(alpha: 0.7)),
                      ),
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
}


class _FollowUpsList extends StatelessWidget {
  final List<SalesEodPendingFollowUp> followUps;
  final CrmTheme crm;

  const _FollowUpsList({required this.followUps, required this.crm});

  @override
  Widget build(BuildContext context) {
    if (followUps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt_rounded, size: 40, color: Color(0xFF16A34A)),
            const SizedBox(height: 10),
            Text('No pending follow-ups due', style: TextStyle(color: crm.textSecondary, fontSize: 13.5)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: followUps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final f = followUps[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: crm.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.customerName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${f.phone}${f.notes.isNotEmpty ? '  ·  ${f.notes}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                    ),
                  ],
                ),
              ),
              if (f.followUpDate.isNotEmpty)
                Text(
                  f.followUpDate,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// SPREADSHEET & TEAM LEDGER VIEWS (Screenshots 1, 2, and 3)
// ---------------------------------------------------------------------------

class _EodSpreadsheetView extends StatelessWidget {
  final SalesEodReport report;
  final CrmTheme crm;

  const _EodSpreadsheetView({required this.report, required this.crm});

  @override
  Widget build(BuildContext context) {
    final bToday = report.bookingsTargetToday;
    final vToday = report.bookingValueTargetToday;
    final bMtd = report.bookingsTargetMtd;
    final vMtd = report.bookingValueTargetMtd;
    final repName = report.isTeam ? 'All Sales Team' : (report.salesPerson?.name ?? 'Individual');

    final shortExcessBookings = bToday.shortExcess <= 0
        ? '(${bToday.shortExcess.abs().toStringAsFixed(1)})'
        : bToday.shortExcess.toStringAsFixed(1);
    final shortExcessValue = vToday.shortExcess < 0
        ? '-(₹${_countFmt.format(vToday.shortExcess.abs().round())})'
        : '₹${_countFmt.format(vToday.shortExcess.round())}';

    final isRange = report.reportDateFormatted.contains(' to ') || report.date.contains(' to ');
    final periodHeader = isRange ? 'SELECTED PERIOD' : 'TODAY';
    final periodCol = isRange ? 'Period' : 'Today';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Blue Banner Title Header (matching Screenshot 2)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B5394),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'End of Day Sales Report — ${report.isTeam ? 'Team' : 'Individual'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Metadata Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.border),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              spacing: 16,
              children: [
                _MetaItem(label: 'Report Date:', value: report.reportDateFormatted, isYellowPill: true),
                _MetaItem(label: 'Sales Person:', value: repName, isYellowPill: true),
                _MetaItem(label: 'Lead-count task:', value: report.leadCountTask),
                _MetaItem(label: 'Month:', value: report.monthName),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Section 1: TODAY / PERIOD — ACHIEVABLE TARGET vs ACHIEVED ──
          _SectionHeader(title: '$periodHeader — ACHIEVABLE TARGET vs ACHIEVED'),
          _TableCard(
            columns: const ['Metric', 'Achievable Target', 'Achieved', 'Achievement %', 'Short / (Excess)'],
            rows: [
              [
                'Bookings (Nos)',
                bToday.achievableTarget.toStringAsFixed(1),
                '${bToday.achieved.toInt()}',
                '${bToday.achievementPct.toStringAsFixed(1)}%',
                shortExcessBookings,
              ],
              [
                'Booking Value (₹)',
                _currFmt.format(vToday.achievableTarget),
                _currFmt.format(vToday.achieved),
                '${vToday.achievementPct.toStringAsFixed(1)}%',
                shortExcessValue,
              ],
            ],
            highlightExcess: true,
          ),
          const SizedBox(height: 14),

          // ── Section 2: MONTH-TO-DATE (1st of month → report date) ──
          const _SectionHeader(title: 'MONTH-TO-DATE (1st of month → report date)'),
          _TableCard(
            columns: const [
              'Metric',
              'MTD Target (Till Date)',
              'MTD Achieved',
              'Achievement %',
              'Monthly Target',
              'Balance to Target',
            ],
            rows: [
              [
                'Bookings (Nos)',
                bMtd.mtdTarget.toStringAsFixed(1),
                '${bMtd.mtdAchieved.toInt()}',
                '${bMtd.mtdAchievementPct.toStringAsFixed(1)}%',
                bMtd.monthlyTarget.toStringAsFixed(1),
                bMtd.balanceToTarget.toStringAsFixed(1),
              ],
              [
                'Booking Value (₹)',
                _currFmt.format(vMtd.mtdTarget),
                _currFmt.format(vMtd.mtdAchieved),
                '${vMtd.mtdAchievementPct.toStringAsFixed(1)}%',
                _currFmt.format(vMtd.monthlyTarget),
                _currFmt.format(vMtd.balanceToTarget),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // ── Section 3: BOOKINGS BY SOURCE ──
          const _SectionHeader(title: 'BOOKINGS BY SOURCE'),
          _TableCard(
            columns: ['Source', periodCol, 'MTD', 'Share of MTD'],
            rows: [
              ['Organic', '${report.organicBookings.today}', '${report.organicBookings.mtd}', '${report.organicBookings.shareOfMtd.toStringAsFixed(1)}%'],
              ['Paid Ads (Kerala page)', '${report.paidAdsBookings.today}', '${report.paidAdsBookings.mtd}', '${report.paidAdsBookings.shareOfMtd.toStringAsFixed(1)}%'],
              if (report.trialBookings.today > 0 || report.trialBookings.mtd > 0)
                ['Trial Bookings', '${report.trialBookings.today}', '${report.trialBookings.mtd}', '${report.trialBookings.shareOfMtd.toStringAsFixed(1)}%'],
              ['Total Bookings', '${report.totalBookings.today}', '${report.totalBookings.mtd}', '100.0%'],
            ],
            isTotalLastRow: true,
          ),
          const SizedBox(height: 14),

          // ── Section 4: LEADS & FOLLOW-UPS LOGGED ──
          const _SectionHeader(title: 'LEADS & FOLLOW-UPS LOGGED'),
          _TableCard(
            columns: ['Count', periodCol, 'MTD'],
            rows: [
              ['WhatsApp Leads (Organic)', '${report.whatsappLeads.today.toInt()}', '${report.whatsappLeads.mtd.toInt()}'],
              ['IG Leads — Main Page', '${report.igMainLeads.today.toInt()}', '${report.igMainLeads.mtd.toInt()}'],
              ['IG Leads — Kerala Page', '${report.igKeralaLeads.today.toInt()}', '${report.igKeralaLeads.mtd.toInt()}'],
              ['Paid Ads Leads', '${report.paidAdsLeads.today.toInt()}', '${report.paidAdsLeads.mtd.toInt()}'],
              if (report.trialCampaignLeads.today > 0 || report.trialCampaignLeads.mtd > 0)
                ['Trial Campaign Leads', '${report.trialCampaignLeads.today.toInt()}', '${report.trialCampaignLeads.mtd.toInt()}'],
              if (report.otherLeads.today > 0 || report.otherLeads.mtd > 0)
                ['Other Leads (YouTube, Reference, Walk-in…)', '${report.otherLeads.today.toInt()}', '${report.otherLeads.mtd.toInt()}'],
              ['Leads Contacted', '${report.leadsContacted.today.toInt()}', '${report.leadsContacted.mtd.toInt()}'],
              ['Follow-ups Done', '${report.followUpsDone.today.toInt()}', '${report.followUpsDone.mtd.toInt()}'],
              ['Contacted → Booking %', '${report.contactedToBookingPct.today.toStringAsFixed(1)}%', '${report.contactedToBookingPct.mtd.toStringAsFixed(1)}%'],
              ['Team Missed Leads (IG – WhatsApp)', '${report.teamMissedLeads.today.toInt()}', '(${report.teamMissedLeads.mtd.toInt()})'],
            ],
          ),
          const SizedBox(height: 8),
          _LeadCountCheckBox(report: report, crm: crm, periodLabel: periodCol),
          const SizedBox(height: 14),

          // ── Section 5: TRIAL BOOKING CAMPAIGN ──
          const _SectionHeader(title: 'TRIAL BOOKING CAMPAIGN'),
          _TableCard(
            columns: ['Metric', periodCol, 'MTD'],
            rows: [
              ['Trial Campaign Leads', '${report.trialCampaignLeadsMetric.today.toInt()}', '${report.trialCampaignLeadsMetric.mtd.toInt()}'],
              ['Trial Bookings', '${report.trialBookingsMetric.today.toInt()}', '${report.trialBookingsMetric.mtd.toInt()}'],
              [
                'Trial Conversion %',
                report.trialConversionPctMetric.today > 0 ? '${report.trialConversionPctMetric.today.toStringAsFixed(1)}%' : '-',
                report.trialConversionPctMetric.mtd > 0 ? '${report.trialConversionPctMetric.mtd.toStringAsFixed(1)}%' : '-',
              ],
            ],
          ),
          const SizedBox(height: 14),

          // ── Section 6: ORDER VALUE & PAYMENTS ──
          const _SectionHeader(title: 'ORDER VALUE & PAYMENTS'),
          _TableCard(
            columns: ['Metric', periodCol, 'MTD'],
            rows: [
              ['Total Order Value (₹)', _currFmt.format(report.totalOrderValueMetric.today), _currFmt.format(report.totalOrderValueMetric.mtd)],
              ['Advance Paid (₹)', _currFmt.format(report.advancePaidMetric.today), _currFmt.format(report.advancePaidMetric.mtd)],
              ['Balance Due (₹)', _currFmt.format(report.balanceDueMetric.today), _currFmt.format(report.balanceDueMetric.mtd)],
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _TeamLedgerTableView extends StatelessWidget {
  final SalesEodReport report;
  final CrmTheme crm;

  const _TeamLedgerTableView({required this.report, required this.crm});

  @override
  Widget build(BuildContext context) {
    if (report.ledgerRows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_list_rounded, size: 40, color: crm.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text('No ledger activity recorded for this date', style: TextStyle(color: crm.textSecondary, fontSize: 13.5)),
          ],
        ),
      );
    }

    final teamCountDates = {
      for (final r in report.ledgerRows)
        if (r.isTeamCount) r.date,
    };
    final headers = [
      'Date',
      'Sales Person',
      'WhatsApp Leads\n(Organic)',
      'IG Leads —\nMain Page',
      'IG Leads —\nKerala Page',
      'Paid Ads\nLeads',
      'Trial Campaign\nLeads',
      'Leads Contacted\n(by me today)',
      'Follow-ups\n(done today)',
      'Organic\nBookings (Nos)',
      'Paid Ads\nBookings (Nos)',
      'Trial\nBookings (Nos)',
      'Total Order\nValue (₹)',
      'Advance\nPaid (₹)',
      'Comment',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF601A29),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Text(
                'TEAM DAILY SALES LEDGER',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              ),
            ),
            DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF601A29)),
              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              dataRowMinHeight: 38,
              dataRowMaxHeight: 44,
              columnSpacing: 14,
              horizontalMargin: 12,
              border: TableBorder.all(color: crm.border, width: 0.6),
              columns: headers.map((h) => DataColumn(label: Text(h, textAlign: TextAlign.center))).toList(),
              rows: [
                // Top TOTAL Row (matching Screenshot 1)
                if (report.ledgerTotals != null)
                  DataRow(
                    color: WidgetStateProperty.all(const Color(0xFFFBEFEF)),
                    cells: [
                      const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF601A29)))),
                      const DataCell(Text('All Team', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.whatsappLeads}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.igMainLeads}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.igKeralaLeads}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.paidAdsLeads}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.trialCampaignLeads}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.leadsContacted}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.followUpsDone}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.organicBookings}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.paidAdsBookings}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Center(child: Text('${report.ledgerTotals!.trialBookings}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Align(
                        alignment: Alignment.centerRight,
                        child: Text(_currFmt.format(report.ledgerTotals!.totalOrderValue),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                      )),
                      DataCell(Align(
                        alignment: Alignment.centerRight,
                        child: Text(_currFmt.format(report.ledgerTotals!.advancePaid),
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                      )),
                      const DataCell(Text('')),
                    ],
                  ),

                // Rep Rows (plus one "Team — manual lead count" row on days
                // with a manual count; salesperson rows then show "—" for
                // leads, since the count is a team number).
                for (final (idx, r) in report.ledgerRows.indexed)
                  DataRow(
                    color: WidgetStateProperty.all(r.isTeamCount
                        ? const Color(0xFFFFF7E6)
                        : (idx.isEven ? crm.surface : crm.background)),
                    cells: [
                      DataCell(Text(r.date, style: const TextStyle(fontSize: 11.5))),
                      DataCell(Text(r.salesPersonName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontStyle: r.isTeamCount ? FontStyle.italic : FontStyle.normal))),
                      for (final n in [r.whatsappLeads, r.igMainLeads, r.igKeralaLeads, r.paidAdsLeads, r.trialCampaignLeads])
                        DataCell(Center(
                            child: Text(
                                !r.isTeamCount && teamCountDates.contains(r.date) ? '—' : '$n',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: r.isTeamCount ? FontWeight.w800 : FontWeight.normal)))),
                      DataCell(Center(child: Text('${r.leadsContacted}', style: const TextStyle(fontSize: 12)))),
                      DataCell(Center(child: Text('${r.followUpsDone}', style: const TextStyle(fontSize: 12)))),
                      DataCell(Center(child: Text('${r.organicBookings}', style: const TextStyle(fontSize: 12)))),
                      DataCell(Center(child: Text('${r.paidAdsBookings}', style: const TextStyle(fontSize: 12)))),
                      DataCell(Center(child: Text('${r.trialBookings}', style: const TextStyle(fontSize: 12)))),
                      DataCell(Align(
                        alignment: Alignment.centerRight,
                        child: Text(_currFmt.format(r.totalOrderValue),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF16A34A))),
                      )),
                      DataCell(Align(
                        alignment: Alignment.centerRight,
                        child: Text(_currFmt.format(r.advancePaid),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      )),
                      DataCell(Text(r.comment, style: const TextStyle(fontSize: 11))),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Under the leads table: where the lead counts came from (the team's manual
/// morning count, or leads saved in the form on days with no count) and the
/// team cross-check — manual count vs leads actually saved in the CRM.
class _LeadCountCheckBox extends StatelessWidget {
  final SalesEodReport report;
  final CrmTheme crm;
  final String periodLabel;
  const _LeadCountCheckBox({required this.report, required this.crm, required this.periodLabel});

  String _source(EodLeadCountCheck c) {
    switch (c.source) {
      case 'manual':
        return "team's manual count";
      case 'mixed':
        return "team's manual count (${c.manualDays} day${c.manualDays == 1 ? '' : 's'}), "
            'form leads for ${c.formDays} day${c.formDays == 1 ? '' : 's'} with no count';
      default:
        return 'leads saved in the form (no manual count entered)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = report.leadCheckToday;
    final m = report.leadCheckMtd;

    Widget gap(int n) => Text(
          n == 0 ? '✓ 0' : (n > 0 ? '$n not saved yet' : '${-n} more saved than counted'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: n == 0 ? const Color(0xFF16A34A) : (n > 0 ? crm.destructive : crm.warning),
          ),
        );

    Widget row(String label, EodLeadCountCheck c) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: c.hasManual
              ? Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    ),
                    Text('Manual count ${c.manualCount}', style: TextStyle(fontSize: 12, color: crm.textPrimary)),
                    Text('Saved in CRM ${c.savedInCrm}', style: TextStyle(fontSize: 12, color: crm.textPrimary)),
                    gap(c.notLogged),
                  ],
                )
              : Text('$label: no manual count entered — nothing to cross-check.',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lead counts above: ${_source(t)}.',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          if (!report.isTeam && t.hasManual)
            Text('The manual count is one shared number for the whole sales team.',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          const SizedBox(height: 4),
          Text('TEAM CROSS-CHECK',
              style: TextStyle(
                  fontSize: 11, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: crm.primary)),
          row(periodLabel, t),
          row('MTD', m),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFFC68A2E), // Gold / Ochre banner
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isYellowPill;

  const _MetaItem({required this.label, required this.value, this.isYellowPill = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(width: 8),
        // Flexible so a long value wraps inside the pill on a phone.
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isYellowPill ? const Color(0xFFFFF2CC) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: isYellowPill ? const Color(0xFFD6B656) : const Color(0xFFCBD5E1)),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final bool highlightExcess;
  final bool isTotalLastRow;

  const _TableCard({
    required this.columns,
    required this.rows,
    this.highlightExcess = false,
    this.isTotalLastRow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
      ),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFCBD5E1), width: 0.6),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Sub-header Row (champagne / pale blush like Screenshot 2)
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFFBEFEF)),
            children: columns.map((col) {
              final isMetric = col == 'Metric' || col == 'Source' || col == 'Count';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  col,
                  textAlign: isMetric ? TextAlign.left : TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF601A29),
                  ),
                ),
              );
            }).toList(),
          ),

          // Data Rows
          for (final (rIdx, r) in rows.indexed)
            TableRow(
              decoration: BoxDecoration(
                color: (isTotalLastRow && rIdx == rows.length - 1)
                    ? const Color(0xFFFFF9E6)
                    : (rIdx.isEven ? Colors.white : const Color(0xFFF8FAFC)),
              ),
              children: [
                for (final (cIdx, cellText) in r.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Text(
                      cellText,
                      textAlign: cIdx == 0 ? TextAlign.left : TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: (cIdx == 0 || (isTotalLastRow && rIdx == rows.length - 1))
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: _getCellColor(cellText, cIdx, highlightExcess),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getCellColor(String val, int colIndex, bool isExcessCol) {
    if (isExcessCol && colIndex == 4) {
      if (val.contains('-(') || val.contains('(')) return const Color(0xFFDC2626);
      return const Color(0xFF16A34A);
    }
    if (val.endsWith('%') && !val.startsWith('0')) {
      return const Color(0xFF16A34A);
    }
    return const Color(0xFF0F172A);
  }
}

