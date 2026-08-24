import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/add_booking_mode_sheet.dart';
import '../../core/models/list_page_params.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/utils/client_report_service.dart';
import '../common_widgets/paginated_footer.dart';
import '../../services/customer_service.dart';
import '../../models/customer.dart';
import 'package:nizan_crm/core/error/errors.dart';

class ClientsDirectoryScreen extends HookConsumerWidget {
  const ClientsDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final pageState = useState(1);
    const pageSize = 20;
    final searchCtrl = useTextEditingController();
    final search = useState('');
    final status = useState('All');
    final sortKey = useState('newest');
    final debounce = useRef<Timer?>(null);

    void goPage1() => pageState.value = 1;

    final asyncCustomers = ref.watch(
      paginatedCustomersProvider(
        ListPageParams(
          page: pageState.value,
          limit: pageSize,
          search: search.value.trim().isEmpty ? null : search.value.trim(),
          status: status.value == 'All' ? null : status.value,
          sort: sortKey.value,
        ),
      ),
    );
    final isExporting = useState(false);

    const sortLabels = {
      'newest': 'Newest first',
      'oldest': 'Oldest first',
      'name_asc': 'Name A–Z',
      'name_desc': 'Name Z–A',
    };
    const statuses = ['All', 'Active', 'Inactive', 'Prospect'];

    Widget menuChip(IconData icon, String label, {bool active = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: active ? crmColors.primary.withValues(alpha: 0.08) : crmColors.background,
            border: Border.all(color: active ? crmColors.primary : crmColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: active ? crmColors.primary : crmColors.textSecondary),
            8.w,
            Text(label, style: TextStyle(color: active ? crmColors.primary : crmColors.textPrimary, fontWeight: FontWeight.w600)),
            Icon(Icons.arrow_drop_down, size: 18, color: crmColors.textSecondary),
          ]),
        );

    Widget filterMenu() => PopupMenuButton<String>(
          tooltip: 'Filter by status',
          onSelected: (v) { status.value = v; goPage1(); },
          itemBuilder: (_) => [
            for (final s in statuses)
              CheckedPopupMenuItem(value: s, checked: status.value == s, child: Text(s)),
          ],
          child: menuChip(Icons.filter_list, status.value == 'All' ? 'Filter' : status.value, active: status.value != 'All'),
        );

    Widget sortMenu() => PopupMenuButton<String>(
          tooltip: 'Sort',
          onSelected: (v) { sortKey.value = v; goPage1(); },
          itemBuilder: (_) => [
            for (final e in sortLabels.entries)
              CheckedPopupMenuItem(value: e.key, checked: sortKey.value == e.key, child: Text(e.value)),
          ],
          child: menuChip(Icons.sort, sortLabels[sortKey.value]!),
        );

    // Pulls the FULL client list (not just the current page) and renders a
    // printable PDF report.
    Future<void> exportReport() async {
      final filterChoice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export Client Report'),
          content: const Text('Do you want to export all clients or filter by event date?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'all'),
              child: const Text('All Clients'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'date'),
              child: const Text('Filter by Date'),
            ),
          ],
        ),
      );

      if (filterChoice == null) return;

      DateTimeRange? dateRange;
      if (filterChoice == 'date') {
        dateRange = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          helpText: 'Select Event Date Range',
        );
        if (dateRange == null) return;
      }

      if (isExporting.value) return;
      isExporting.value = true;
      final messenger = ScaffoldMessenger.of(context);
      try {
        var clients = await ref.read(customerServiceProvider).getCustomers();

        // Collapse duplicate client records. Legacy imports created several
        // customers for the same person with different placeholder emails and no
        // phone, so the directory showed one person multiple times. Key by phone
        // (last 10 digits) when present, otherwise by name; keep the most complete
        // record and carry over an event date if the winner is missing one.
        String dedupKey(Customer c) {
          final digits = (c.phone ?? '').replaceAll(RegExp(r'\D'), '');
          final phoneKey =
              digits.length >= 10 ? digits.substring(digits.length - 10) : '';
          return phoneKey.isNotEmpty
              ? 'p:$phoneKey'
              : 'n:${c.name.trim().toLowerCase()}';
        }

        bool isPlaceholder(String? e) =>
            e == null ||
            e.contains('legacy.local') ||
            e.contains('placeholder.local');

        int score(Customer c) {
          var s = 0;
          final digits = (c.phone ?? '').replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 10) s += 4;
          if (!isPlaceholder(c.email)) s += 2;
          if ((c.eventDate ?? '').isNotEmpty) s += 1;
          return s;
        }

        final unique = <String, Customer>{};
        for (final c in clients) {
          final k = dedupKey(c);
          final existing = unique[k];
          if (existing == null) {
            unique[k] = c;
            continue;
          }
          final winner = score(c) > score(existing) ? c : existing;
          final other = identical(winner, c) ? existing : c;
          unique[k] = (winner.eventDate == null || winner.eventDate!.isEmpty)
              ? winner.copyWith(eventDate: other.eventDate)
              : winner;
        }
        clients = unique.values.toList();

        if (dateRange != null) {
          clients = clients.where((c) {
            if (c.eventDate == null || c.eventDate!.isEmpty) return false;
            final d = DateTime.tryParse(c.eventDate!);
            if (d == null) return false;
            final start = dateRange!.start;
            final end = dateRange.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
            return d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end);
          }).toList();
        }

        // Sort clients by eventDate (descending - latest events first)
        clients.sort((a, b) {
          final dateA = DateTime.tryParse(a.eventDate ?? '');
          final dateB = DateTime.tryParse(b.eventDate ?? '');
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

        if (clients.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No clients found for the selected criteria.')),
          );
          return;
        }
        await printClientsReport(clients);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      } finally {
        isExporting.value = false;
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clients Directory',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Clients are created automatically when you add a booking.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: crmColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                16.w,
                OutlinedButton.icon(
                  onPressed: isExporting.value ? null : exportReport,
                  icon: isExporting.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(
                    isExporting.value ? 'Preparing…' : 'Client Report (PDF)',
                  ),
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            16.h,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isExporting.value ? null : exportReport,
                icon: isExporting.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(
                  isExporting.value ? 'Preparing…' : 'Client Report (PDF)',
                ),
              ),
            ),
          ],
          24.h,

          // ── Table card ───────────────────────────────────────────────────
          Card(
            color: crmColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: 24.p,
              child: Column(
                children: [
                  // Search + filter row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (v) {
                            debounce.value?.cancel();
                            debounce.value = Timer(const Duration(milliseconds: 400), () {
                              search.value = v;
                              goPage1();
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Search clients by name, phone, or email...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: search.value.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    tooltip: 'Clear',
                                    onPressed: () {
                                      searchCtrl.clear();
                                      debounce.value?.cancel();
                                      search.value = '';
                                      goPage1();
                                    },
                                  ),
                            filled: true,
                            fillColor: crmColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                      if (!isMobile) ...[
                        const Spacer(),
                        filterMenu(),
                        16.w,
                        sortMenu(),
                      ],
                    ],
                  ),
                  if (isMobile) ...[
                    16.h,
                    Row(
                      children: [
                        Expanded(child: filterMenu()),
                        16.w,
                        Expanded(child: sortMenu()),
                      ],
                    ),
                  ],
                  24.h,

                  // Table header (desktop)
                  if (!isMobile)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'CLIENT',
                              style: TextStyle(
                                color: crmColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'CONTACT INFO',
                              style: TextStyle(
                                color: crmColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'STATUS',
                              style: TextStyle(
                                color: crmColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              'ACTIONS',
                              style: TextStyle(
                                color: crmColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),

                  // Data from provider
                  asyncCustomers.when(
                        data: (response) {
                          final customers = response.items;
                          final hasFilters = search.value.trim().isNotEmpty || status.value != 'All';
                          void clearFilters() {
                            searchCtrl.clear();
                            debounce.value?.cancel();
                            search.value = '';
                            status.value = 'All';
                            goPage1();
                          }
                          if (customers.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.person_search,
                                    size: 48,
                                    color: crmColors.border,
                                  ),
                                  16.h,
                                  Text(
                                    hasFilters
                                        ? 'No clients match your search or filter.'
                                        : 'No clients yet.\nCreate a booking to auto-register a client.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: crmColors.textSecondary,
                                    ),
                                  ),
                                  16.h,
                                  if (hasFilters)
                                    OutlinedButton.icon(
                                      onPressed: clearFilters,
                                      icon: const Icon(Icons.clear_all),
                                      label: const Text('Clear filters'),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: () => showAddBookingModeChooser(context),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create First Booking'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: crmColors.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Text(
                                      '${response.totalItems} client${response.totalItems == 1 ? '' : 's'}',
                                      style: TextStyle(fontWeight: FontWeight.w700, color: crmColors.textPrimary),
                                    ),
                                    if (hasFilters) ...[
                                      8.w,
                                      TextButton.icon(
                                        onPressed: clearFilters,
                                        icon: const Icon(Icons.clear_all, size: 16),
                                        label: const Text('Clear'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (!isMobile)
                                      Text('Sorted: ${sortLabels[sortKey.value]}',
                                          style: TextStyle(fontSize: 12, color: crmColors.textSecondary)),
                                  ],
                                ),
                              ),
                              ...customers.map(
                                (c) => Column(
                                  children: [
                                    _buildClientRow(
                                      context,
                                      ref,
                                      id: c.id ?? '',
                                      name: c.name,
                                      tag: c.status,
                                      phone: c.phone ?? 'N/A',
                                      email: c.email.contains('@placeholder')
                                          ? '—'
                                          : c.email,
                                    ),
                                    const Divider(),
                                  ],
                                ),
                              ),
                              16.h,
                              PaginatedFooter(
                                page: response.page,
                                limit: response.limit,
                                totalPages: response.totalPages,
                                totalItems: response.totalItems,
                                currentItemCount: response.items.length,
                                onPrevious: response.page > 1
                                    ? () => pageState.value -= 1
                                    : null,
                                onNext: response.page < response.totalPages
                                    ? () => pageState.value += 1
                                    : null,
                              ),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, stack) => Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'Error: $error',
                            style: TextStyle(color: crmColors.warning),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientRow(
    BuildContext context,
    WidgetRef ref, {
    required String id,
    required String name,
    required String tag,
    required String phone,
    required String email,
  }) {
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    Future<void> deleteClient() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Client'),
          content: Text(
            'Remove $name from the directory? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          await ref.read(customerServiceProvider).deleteCustomer(id);
          ref.invalidate(customersProvider);
          ref.invalidate(paginatedCustomersProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
          }
        }
      }
    }

    Color tagColor;
    switch (tag) {
      case 'Active':
        tagColor = crmColors.success;
        break;
      case 'Inactive':
        tagColor = crmColors.warning;
        break;
      default:
        tagColor = crmColors.textSecondary;
    }

    if (isMobile) {
      return Padding(
        padding: 16.py,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: crmColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: crmColors.primary,
                    ),
                  ),
                ),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        tag,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (val) {
                    if (val == 'view') context.go('/client/$id');
                    if (val == 'delete') deleteClient();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('View Profile'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            12.h,
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: crmColors.textSecondary),
                8.w,
                Text(phone, style: TextStyle(color: crmColors.textSecondary)),
              ],
            ),
            4.h,
            Row(
              children: [
                Icon(Icons.email, size: 14, color: crmColors.textSecondary),
                8.w,
                Expanded(
                  child: Text(
                    email,
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ),
              ],
            ),
            12.h,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/client/$id'),
                child: const Text('View Profile'),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => context.go('/client/$id'),
      child: Padding(
        padding: 16.py,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: crmColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: crmColors.primary,
                      ),
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: tagColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: 14,
                        color: crmColors.textSecondary,
                      ),
                      8.w,
                      Text(
                        phone,
                        style: TextStyle(color: crmColors.textSecondary),
                      ),
                    ],
                  ),
                  4.h,
                  Row(
                    children: [
                      Icon(
                        Icons.email,
                        size: 14,
                        color: crmColors.textSecondary,
                      ),
                      8.w,
                      Expanded(
                        child: Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: crmColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: tagColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.person_outline,
                      color: crmColors.primary,
                      size: 20,
                    ),
                    tooltip: 'View Profile',
                    onPressed: () => context.go('/client/$id'),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: crmColors.textSecondary,
                      size: 20,
                    ),
                    onSelected: (val) {
                      if (val == 'delete') deleteClient();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
