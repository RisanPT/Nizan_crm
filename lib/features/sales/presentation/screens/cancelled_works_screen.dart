import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/utils/cancelled_works_report_service.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';

/// Indian financial year (Apr–Mar) label for a date, e.g. "FY 2026-27".
String financialYearLabel(DateTime d) {
  final l = d.toLocal();
  final startYear = l.month >= 4 ? l.year : l.year - 1;
  final end = (startYear + 1) % 100;
  return 'FY $startYear-${end.toString().padLeft(2, '0')}';
}

/// Sales → Cancelled Works report. Lists every cancelled booking and exports a
/// printable PDF, optionally scoped to a financial year.
class CancelledWorksScreen extends HookConsumerWidget {
  const CancelledWorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final selectedFy = useState<String>('All');
    final isExporting = useState(false);

    final asyncBookings = ref.watch(bookingProvider);

    return asyncBookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load bookings:\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: crm.textSecondary)),
        ),
      ),
      data: (all) {
        final cancelled = all
            .where((b) => b.status.toLowerCase() == 'cancelled')
            .toList()
          ..sort((a, b) => b.serviceStart.compareTo(a.serviceStart));

        final fyOptions = <String>{
          'All',
          for (final b in cancelled) financialYearLabel(b.serviceStart),
        }.toList();

        final filtered = selectedFy.value == 'All'
            ? cancelled
            : cancelled
                .where((b) =>
                    financialYearLabel(b.serviceStart) == selectedFy.value)
                .toList();

        final valueLost =
            filtered.fold<double>(0, (s, b) => s + b.totalPrice);
        final advance =
            filtered.fold<double>(0, (s, b) => s + b.advanceAmount);

        Future<void> exportReport() async {
          if (isExporting.value || filtered.isEmpty) return;
          isExporting.value = true;
          final messenger = ScaffoldMessenger.of(context);
          try {
            await printCancelledWorksReport(
              filtered,
              periodLabel: selectedFy.value == 'All'
                  ? 'All time'
                  : selectedFy.value,
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Failed to export report: $e')),
            );
          } finally {
            isExporting.value = false;
          }
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cancelled Works',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        4.h,
                        Text(
                          'Every cancelled booking, with the revenue impact.',
                          style: TextStyle(color: crm.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) _exportButton(isExporting, filtered, exportReport),
                ],
              ),
              16.h,

              // ── Controls ────────────────────────────────────────────────
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: fyOptions.contains(selectedFy.value)
                          ? selectedFy.value
                          : 'All',
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Financial Year',
                        prefixIcon: const Icon(Icons.calendar_month_outlined,
                            size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        for (final fy in fyOptions)
                          DropdownMenuItem(value: fy, child: Text(fy)),
                      ],
                      onChanged: (v) => selectedFy.value = v ?? 'All',
                    ),
                  ),
                  if (isMobile)
                    SizedBox(
                      width: double.infinity,
                      child: _exportButton(isExporting, filtered, exportReport),
                    ),
                ],
              ),
              18.h,

              // ── Summary ─────────────────────────────────────────────────
              Row(
                children: [
                  _stat(context, 'Cancelled', '${filtered.length}',
                      crm.primary),
                  12.w,
                  _stat(context, 'Value Lost', '₹${valueLost.toStringAsFixed(0)}',
                      crm.destructive),
                  12.w,
                  _stat(context, 'Advance Collected',
                      '₹${advance.toStringAsFixed(0)}', crm.accent),
                ],
              ),
              20.h,

              // ── List ────────────────────────────────────────────────────
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.event_busy_outlined,
                          size: 42, color: crm.textSecondary),
                      10.h,
                      Text('No cancelled works in this period.',
                          style: TextStyle(color: crm.textSecondary)),
                    ]),
                  ),
                )
              else
                ...filtered.map((b) => _row(context, b)),
            ],
          ),
        );
      },
    );
  }

  Widget _exportButton(ValueNotifier<bool> isExporting, List<Booking> filtered,
          Future<void> Function() onExport) =>
      FilledButton.icon(
        onPressed:
            isExporting.value || filtered.isEmpty ? null : () => onExport(),
        icon: isExporting.value
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: Text(isExporting.value ? 'Preparing…' : 'Download Report (PDF)'),
      );

  Widget _stat(
      BuildContext context, String label, String value, Color color) {
    final crm = context.crmColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            4.h,
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: crm.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Booking b) {
    final crm = context.crmColors;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = b.serviceStart.toLocal();
    final date = '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    final location = [b.district.trim(), b.region.trim()]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          b.customerName.trim().isEmpty
                              ? 'Unknown'
                              : b.customerName.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                      8.w,
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: crm.destructive.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('CANCELLED',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: crm.destructive)),
                      ),
                    ],
                  ),
                  4.h,
                  Text(
                    [
                      if (b.service.trim().isNotEmpty) b.service.trim(),
                      date,
                      if (location.isNotEmpty) location,
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (b.internalRemarks.trim().isNotEmpty) ...[
                    4.h,
                    Text('Remarks: ${b.internalRemarks.trim()}',
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            12.w,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${b.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                2.h,
                Text('Adv ₹${b.advanceAmount.toStringAsFixed(0)}',
                    style:
                        TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
