import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/add_booking_mode_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/client_report_service.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

// ── Labels ──────────────────────────────────────────────────────────────────

const _sortLabels = {
  'newest': 'Newest added',
  'oldest': 'Oldest added',
  'name_asc': 'Name A–Z',
  'name_desc': 'Name Z–A',
  'event_soonest': 'Event date — soonest',
  'event_latest': 'Event date — latest',
};

const _statuses = ['All', 'Active', 'Prospect', 'Inactive'];

const _eventLabels = {
  'any': 'Any event',
  'upcoming': 'Upcoming',
  'past': 'Past',
  'none': 'No event',
  'range': 'Date range',
};

/// Presets for the "date added" filter.
enum _Added { any, today, week, month, last30, custom }

const _addedLabels = {
  _Added.any: 'Any time',
  _Added.today: 'Today',
  _Added.week: 'This week',
  _Added.month: 'This month',
  _Added.last30: 'Last 30 days',
  _Added.custom: 'Custom range',
};

final _dayFmt = DateFormat('d MMM yyyy');
final _shortFmt = DateFormat('d MMM');

Color _statusColor(CrmTheme crm, String s) {
  switch (s) {
    case 'Active':
      return crm.success;
    case 'Inactive':
      return crm.warning;
    default:
      return crm.accent; // Prospect
  }
}

/// "YYYY-MM-DD" (or ISO) → local date, else null.
DateTime? _eventDay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final d = DateTime.tryParse(raw.trim());
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// "Today", "Tomorrow", "in 5 days", "3 days ago".
String _relDays(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 0) return 'in $diff days';
  return '${-diff} days ago';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

String? _realEmail(String email) =>
    email.contains('@placeholder') || email.contains('legacy.local')
        ? null
        : email;

// ── Screen ──────────────────────────────────────────────────────────────────

class ClientsDirectoryScreen extends HookConsumerWidget {
  const ClientsDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;

    // ── Query state ──
    final page = useState(1);
    final pageSize = useState(20);
    final searchCtrl = useTextEditingController();
    final search = useState('');
    final status = useState('All');
    final sort = useState('newest');
    final event = useState('any');
    final eventRange = useState<DateTimeRange?>(null);
    final added = useState(_Added.any);
    final addedRange = useState<DateTimeRange?>(null);
    final debounce = useRef<Timer?>(null);
    final isExporting = useState(false);
    useEffect(() => () => debounce.value?.cancel(), const []);

    void resetPage() => page.value = 1;

    // Resolve the "date added" preset into a concrete range.
    DateTimeRange? addedWindow() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      switch (added.value) {
        case _Added.any:
          return null;
        case _Added.today:
          return DateTimeRange(start: today, end: today);
        case _Added.week:
          return DateTimeRange(
              start: today.subtract(Duration(days: today.weekday - 1)),
              end: today);
        case _Added.month:
          return DateTimeRange(start: DateTime(now.year, now.month), end: today);
        case _Added.last30:
          return DateTimeRange(
              start: today.subtract(const Duration(days: 29)), end: today);
        case _Added.custom:
          return addedRange.value;
      }
    }

    final aw = addedWindow();
    final query = ClientQuery(
      page: page.value,
      limit: pageSize.value,
      search: search.value,
      status: status.value,
      sort: sort.value,
      event: event.value == 'range' && eventRange.value == null
          ? 'any'
          : event.value,
      eventFrom: eventRange.value?.start,
      eventTo: eventRange.value?.end,
      addedFrom: aw?.start,
      addedTo: aw?.end,
    );

    final async = ref.watch(clientDirectoryProvider(query));
    final statsAsync = ref.watch(clientStatsProvider);

    // Keep showing the previous page while the next one loads (no flicker).
    final lastPage = useRef<ClientPage?>(null);
    if (async.hasValue) lastPage.value = async.value;
    final data = async.value ?? lastPage.value;

    final hasFilters = search.value.trim().isNotEmpty ||
        status.value != 'All' ||
        event.value != 'any' ||
        added.value != _Added.any;

    void clearFilters() {
      searchCtrl.clear();
      debounce.value?.cancel();
      search.value = '';
      status.value = 'All';
      event.value = 'any';
      eventRange.value = null;
      added.value = _Added.any;
      addedRange.value = null;
      resetPage();
    }

    void refresh() => ref.refreshData.customers();

    Future<void> pickEventRange() async {
      final r = await showBrandedDateRangePicker(
        context,
        initialDateRange: eventRange.value,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'Clients with an event between',
      );
      if (r == null) return;
      eventRange.value = r;
      event.value = 'range';
      resetPage();
    }

    Future<void> pickAddedRange() async {
      final r = await showBrandedDateRangePicker(
        context,
        initialDateRange: addedRange.value,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        helpText: 'Clients added between',
      );
      if (r == null) return;
      addedRange.value = r;
      added.value = _Added.custom;
      resetPage();
    }

    Future<void> deleteClient(Customer c) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete client'),
          content:
              Text('Remove ${c.name} from the directory? This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: crm.destructive),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true || c.id == null) return;
      try {
        await ref.read(customerServiceProvider).deleteCustomer(c.id!);
        ref.refreshData.customers(); // list, paginated, directory, stats
        if (context.mounted) showSuccessSnackBar(context, '${c.name} deleted');
      } catch (e) {
        if (context.mounted) showErrorSnackBar(context, e);
      }
    }

    Future<void> exportReport() =>
        _exportReport(context, ref, isExporting: isExporting);

    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      final narrow = width < 760;
      final wide = width >= 1000;

      return RefreshIndicator(
        onRefresh: () async {
          refresh();
          try {
            await ref.read(clientDirectoryProvider(query).future);
          } catch (_) {
            // The list shows its own error state.
          }
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ── Header ──
            _Header(
              narrow: narrow,
              total: statsAsync.value?.total,
              isExporting: isExporting.value,
              onExport: exportReport,
              onRefresh: refresh,
              onNewBooking: () => showAddBookingModeChooser(context),
            ),
            18.h,

            // ── Summary cards ──
            statsAsync.when(
              loading: () => const SizedBox(
                  height: 108, child: Center(child: CircularProgressIndicator())),
              // The summary is secondary — if it fails, show a slim notice and
              // keep the directory usable rather than a big error block.
              error: (e, _) => _StatsUnavailable(
                  error: e, onRetry: () => ref.invalidate(clientStatsProvider)),
              data: (s) => _StatGrid(width: width, stats: [
                _Stat('${s.total}', 'Total Clients', 'all time',
                    Icons.groups_2_outlined, crm.primary,
                    selected: status.value == 'All' && event.value == 'any',
                    onTap: () {
                  status.value = 'All';
                  event.value = 'any';
                  resetPage();
                }),
                _Stat('${s.active}', 'Active', 'booked clients',
                    Icons.verified_outlined, crm.success,
                    selected: status.value == 'Active', onTap: () {
                  status.value = 'Active';
                  resetPage();
                }),
                _Stat('${s.prospect}', 'Prospects', 'not booked yet',
                    Icons.person_search_outlined, crm.accent,
                    selected: status.value == 'Prospect', onTap: () {
                  status.value = 'Prospect';
                  resetPage();
                }),
                _Stat('${s.inactive}', 'Inactive', 'no recent activity',
                    Icons.pause_circle_outline, crm.warning,
                    selected: status.value == 'Inactive', onTap: () {
                  status.value = 'Inactive';
                  resetPage();
                }),
                _Stat('${s.upcomingEvents}', 'Upcoming Events',
                    '${s.eventsNext30Days} in the next 30 days',
                    Icons.event_available_outlined, const Color(0xFF6E1423),
                    selected: event.value == 'upcoming', onTap: () {
                  event.value = 'upcoming';
                  sort.value = 'event_soonest';
                  resetPage();
                }),
                _Stat('${s.addedThisMonth}', 'Added This Month',
                    DateFormat('MMMM yyyy').format(DateTime.now()),
                    Icons.person_add_alt_outlined, const Color(0xFF9E2B43),
                    selected: added.value == _Added.month, onTap: () {
                  added.value = _Added.month;
                  resetPage();
                }),
              ]),
            ),
            16.h,

            // ── Toolbar ──
            _Card(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: searchCtrl,
                          hasText: search.value.isNotEmpty,
                          onChanged: (v) {
                            debounce.value?.cancel();
                            debounce.value =
                                Timer(const Duration(milliseconds: 400), () {
                              search.value = v;
                              resetPage();
                            });
                          },
                          onClear: () {
                            searchCtrl.clear();
                            debounce.value?.cancel();
                            search.value = '';
                            resetPage();
                          },
                        ),
                      ),
                      if (!narrow) ...[
                        12.w,
                        _SortMenu(
                          value: sort.value,
                          onChanged: (v) {
                            sort.value = v;
                            resetPage();
                          },
                        ),
                      ],
                    ],
                  ),
                  if (narrow) ...[
                    10.h,
                    _SortMenu(
                      value: sort.value,
                      expand: true,
                      onChanged: (v) {
                        sort.value = v;
                        resetPage();
                      },
                    ),
                  ],
                  14.h,
                  // Status chips with live counts from the server.
                  _Label('Status'),
                  6.h,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _statuses)
                        _FilterChip(
                          label: s,
                          count: data?.counts[s],
                          color: s == 'All' ? crm.primary : _statusColor(crm, s),
                          selected: status.value == s,
                          onTap: () {
                            status.value = s;
                            resetPage();
                          },
                        ),
                    ],
                  ),
                  14.h,
                  Wrap(
                    spacing: 24,
                    runSpacing: 14,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Label('Event date'),
                          6.h,
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final e in const [
                                'any',
                                'upcoming',
                                'past',
                                'none'
                              ])
                                _FilterChip(
                                  label: _eventLabels[e]!,
                                  selected: event.value == e,
                                  color: crm.primary,
                                  onTap: () {
                                    event.value = e;
                                    eventRange.value = null;
                                    resetPage();
                                  },
                                ),
                              _FilterChip(
                                label: event.value == 'range' &&
                                        eventRange.value != null
                                    ? '${_shortFmt.format(eventRange.value!.start)} – ${_shortFmt.format(eventRange.value!.end)}'
                                    : 'Date range…',
                                icon: Icons.date_range_rounded,
                                selected: event.value == 'range' &&
                                    eventRange.value != null,
                                color: crm.primary,
                                onTap: pickEventRange,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Label('Date added'),
                          6.h,
                          _AddedMenu(
                            value: added.value,
                            customRange: addedRange.value,
                            onChanged: (v) {
                              if (v == _Added.custom) {
                                pickAddedRange();
                                return;
                              }
                              added.value = v;
                              addedRange.value = null;
                              resetPage();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (hasFilters) ...[
                    12.h,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                        label: const Text('Clear all filters'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            16.h,

            // ── Results ──
            _Card(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thin loading bar while a new page/filter is fetched.
                  SizedBox(
                    height: 3,
                    child: async.isLoading && data != null
                        ? LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            color: crm.primary)
                        : null,
                  ),
                  if (async.hasError && !async.isLoading)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppErrorView(
                        error: async.error,
                        onRetry: () => ref.invalidate(clientDirectoryProvider),
                      ),
                    )
                  else if (data == null)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (data.items.isEmpty)
                    _EmptyState(
                      hasFilters: hasFilters,
                      onClear: clearFilters,
                      onNewBooking: () => showAddBookingModeChooser(context),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Showing ${(data.page - 1) * data.limit + 1}–'
                              '${(data.page - 1) * data.limit + data.items.length}'
                              ' of ${data.totalItems} client${data.totalItems == 1 ? '' : 's'}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: crm.textPrimary),
                            ),
                          ),
                          if (!narrow)
                            Text('Sorted by ${_sortLabels[sort.value]}',
                                style: TextStyle(
                                    fontSize: 12, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    if (wide) _TableHeader(crm: crm),
                    Divider(height: 1, color: crm.border),
                    for (final row in data.items) ...[
                      wide
                          ? _ClientTableRow(
                              row: row,
                              onOpen: () => context.go('/client/${row.customer.id}'),
                              onDelete: () => deleteClient(row.customer),
                            )
                          : _ClientCard(
                              row: row,
                              onOpen: () => context.go('/client/${row.customer.id}'),
                              onDelete: () => deleteClient(row.customer),
                            ),
                      Divider(height: 1, color: crm.border),
                    ],
                    _Pagination(
                      narrow: narrow,
                      page: data.page,
                      pages: data.totalPages,
                      pageSize: pageSize.value,
                      onPage: (p) => page.value = p,
                      onPageSize: (s) {
                        pageSize.value = s;
                        resetPage();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── PDF export (unchanged behaviour, moved out of build) ────────────────────

Future<void> _exportReport(BuildContext context, WidgetRef ref,
    {required ValueNotifier<bool> isExporting}) async {
  final filterChoice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Export Client Report'),
      content:
          const Text('Do you want to export all clients or filter by event date?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('All Clients')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'date'),
            child: const Text('Filter by Date')),
      ],
    ),
  );
  if (filterChoice == null || !context.mounted) return;

  DateTimeRange? dateRange;
  if (filterChoice == 'date') {
    dateRange = await showBrandedDateRangePicker(
      context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select Event Date Range',
    );
    if (dateRange == null) return;
  }
  if (isExporting.value || !context.mounted) return;
  isExporting.value = true;
  try {
    var clients = await ref.read(customerServiceProvider).getCustomers();

    // Collapse duplicate client records (legacy imports created several
    // customers for the same person). Key by phone (last 10 digits) when
    // present, otherwise by name; keep the most complete record.
    String dedupKey(Customer c) {
      final digits = (c.phone ?? '').replaceAll(RegExp(r'\D'), '');
      final phoneKey =
          digits.length >= 10 ? digits.substring(digits.length - 10) : '';
      return phoneKey.isNotEmpty ? 'p:$phoneKey' : 'n:${c.name.trim().toLowerCase()}';
    }

    int score(Customer c) {
      var s = 0;
      if ((c.phone ?? '').replaceAll(RegExp(r'\D'), '').length >= 10) s += 4;
      if (_realEmail(c.email) != null) s += 2;
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
      final start = dateRange.start;
      final end = dateRange.end
          .add(const Duration(hours: 23, minutes: 59, seconds: 59));
      clients = clients.where((c) {
        final d = DateTime.tryParse(c.eventDate ?? '');
        if (d == null) return false;
        return d.isAfter(start.subtract(const Duration(seconds: 1))) &&
            d.isBefore(end);
      }).toList();
    }

    // Latest events first.
    clients.sort((a, b) {
      final da = DateTime.tryParse(a.eventDate ?? '');
      final db = DateTime.tryParse(b.eventDate ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    if (clients.isEmpty) {
      if (context.mounted) {
        showWarningSnackBar(context, 'No clients found for the selected criteria.');
      }
      return;
    }
    await printClientsReport(clients);
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  } finally {
    isExporting.value = false;
  }
}

// ── Building blocks ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: child,
    );
  }
}

class _StatsUnavailable extends StatelessWidget {
  const _StatsUnavailable({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: crm.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.warning.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 18, color: crm.warning),
        10.w,
        Expanded(
          child: Text(
            'Summary unavailable — ${friendlyErrorMessage(error)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: context.crmColors.textSecondary));
}

class _Header extends StatelessWidget {
  const _Header({
    required this.narrow,
    required this.total,
    required this.isExporting,
    required this.onExport,
    required this.onRefresh,
    required this.onNewBooking,
  });

  final bool narrow;
  final int? total;
  final bool isExporting;
  final VoidCallback onExport;
  final VoidCallback onRefresh;
  final VoidCallback onNewBooking;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final exportBtn = OutlinedButton.icon(
      onPressed: isExporting ? null : onExport,
      icon: isExporting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: Text(isExporting ? 'Preparing…' : 'Client Report'),
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
    final newBtn = FilledButton.icon(
      onPressed: onNewBooking,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('New Booking'),
      style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Clients',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: crm.textPrimary)),
        2.h,
        Text(
          '${total == null ? '' : '$total clients · '}created automatically when you add a booking',
          style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
        ),
      ],
    );
    final refreshBtn = IconButton(
      tooltip: 'Refresh',
      onPressed: onRefresh,
      icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: title), refreshBtn]),
          12.h,
          Row(children: [
            Expanded(child: exportBtn),
            10.w,
            Expanded(child: newBtn),
          ]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        refreshBtn,
        8.w,
        exportBtn,
        10.w,
        newBtn,
      ],
    );
  }
}

class _Stat {
  const _Stat(this.value, this.label, this.caption, this.icon, this.color,
      {this.selected = false, this.onTap});
  final String value;
  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.width, required this.stats});
  final double width;
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final cols = width < 520 ? 2 : (width < 1000 ? 3 : 6);
    const gap = 12.0;
    final w = (width - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final s in stats) SizedBox(width: w, child: _StatCard(stat: s)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Material(
      color: stat.selected ? stat.color.withValues(alpha: 0.06) : crm.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: stat.onTap,
        child: Container(
          height: 108,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: stat.selected
                    ? stat.color.withValues(alpha: 0.6)
                    : crm.border,
                width: stat.selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(stat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: crm.textSecondary)),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: stat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(stat.icon, size: 16, color: stat.color),
                ),
              ]),
              const Spacer(),
              Text(stat.value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: crm.textPrimary)),
              4.h,
              Text(stat.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: stat.color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search by name, phone, email or company…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasText || controller.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: crm.background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: crm.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: crm.border),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu(
      {required this.value, required this.onChanged, this.expand = false});
  final String value;
  final ValueChanged<String> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return PopupMenuButton<String>(
      tooltip: 'Sort',
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final e in _sortLabels.entries)
          CheckedPopupMenuItem(
              value: e.key, checked: value == e.key, child: Text(e.value)),
      ],
      child: Container(
        height: 46,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: crm.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 18, color: crm.textSecondary),
            8.w,
            Flexible(
              child: Text(_sortLabels[value] ?? value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: crm.textPrimary)),
            ),
            6.w,
            Icon(Icons.expand_more_rounded,
                size: 18, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _AddedMenu extends StatelessWidget {
  const _AddedMenu(
      {required this.value, required this.customRange, required this.onChanged});
  final _Added value;
  final DateTimeRange? customRange;
  final ValueChanged<_Added> onChanged;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final active = value != _Added.any;
    final label = value == _Added.custom && customRange != null
        ? '${_shortFmt.format(customRange!.start)} – ${_shortFmt.format(customRange!.end)}'
        : _addedLabels[value]!;
    return PopupMenuButton<_Added>(
      tooltip: 'Filter by date added',
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final e in _addedLabels.entries)
          CheckedPopupMenuItem(
              value: e.key,
              checked: value == e.key,
              child: Text(e.key == _Added.custom ? 'Custom range…' : e.value)),
      ],
      child: _ChipBody(
        label: label,
        icon: Icons.calendar_month_outlined,
        selected: active,
        color: crm.primary,
        trailing: Icons.expand_more_rounded,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.count,
    this.icon,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: _ChipBody(
          label: label,
          selected: selected,
          color: color,
          count: count,
          icon: icon),
    );
  }
}

class _ChipBody extends StatelessWidget {
  const _ChipBody({
    required this.label,
    required this.selected,
    required this.color,
    this.count,
    this.icon,
    this.trailing,
  });
  final String label;
  final bool selected;
  final Color color;
  final int? count;
  final IconData? icon;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final fg = selected ? color : crm.textPrimary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.10) : crm.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected ? color.withValues(alpha: 0.55) : crm.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            6.w,
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg)),
          if (count != null) ...[
            6.w,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.18)
                      : crm.border.faded(0.6),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
            ),
          ],
          if (trailing != null) ...[
            4.w,
            Icon(trailing, size: 16, color: crm.textSecondary),
          ],
        ],
      ),
    );
  }
}

// ── Rows ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Text(_initials(name),
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 13.5, color: color)),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(context.crmColors, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        5.w,
        Text(status,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

/// Event date + "in N days" badge.
class _EventCell extends StatelessWidget {
  const _EventCell(this.raw);
  final String? raw;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = _eventDay(raw);
    if (d == null) {
      return Text('No event',
          style: TextStyle(fontSize: 12.5, color: crm.textSecondary));
    }
    final now = DateTime.now();
    final days = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    final upcoming = days >= 0;
    final c = !upcoming
        ? crm.textSecondary
        : (days <= 7 ? crm.destructive : (days <= 30 ? crm.warning : crm.success));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_dayFmt.format(d),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: crm.textPrimary)),
        2.h,
        Text(_relDays(d),
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: upcoming ? FontWeight.w700 : FontWeight.w500,
                color: c)),
      ],
    );
  }
}

Future<void> _launch(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showErrorSnackBar(context, null, fallback: 'Could not open ${uri.scheme}.');
    }
  } catch (e) {
    if (context.mounted) {
      showErrorSnackBar(context, e, fallback: 'Could not open ${uri.scheme}.');
    }
  }
}

String _digits(String? phone) => (phone ?? '').replaceAll(RegExp(r'\D'), '');

class _ContactActions extends StatelessWidget {
  const _ContactActions({required this.phone});
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = _digits(phone);
    if (d.length < 10) return const SizedBox.shrink();
    final wa = d.length == 10 ? '91$d' : d;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: 'Call',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.call_outlined, size: 18, color: crm.primary),
        onPressed: () => _launch(context, Uri.parse('tel:$d')),
      ),
      IconButton(
        tooltip: 'WhatsApp',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.chat_outlined, size: 18, color: Color(0xFF16A34A)),
        onPressed: () => _launch(context, Uri.parse('https://wa.me/$wa')),
      ),
    ]);
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.onOpen, required this.onDelete});
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(Icons.more_vert_rounded, size: 20, color: crm.textSecondary),
      onSelected: (v) {
        if (v == 'open') onOpen();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'open',
            child: Row(children: [
              Icon(Icons.person_outline, size: 18),
              SizedBox(width: 10),
              Text('View profile'),
            ])),
        PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 18, color: crm.destructive),
              const SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: crm.destructive)),
            ])),
      ],
    );
  }
}

const _colClient = 5;
const _colContact = 4;
const _colEvent = 3;
const _colAdded = 3;
const _colStatus = 2;

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    Widget h(String t, int flex) => Expanded(
        flex: flex,
        child: Text(t,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: crm.textSecondary)));
    return Container(
      color: crm.background,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(children: [
        h('CLIENT', _colClient),
        h('CONTACT', _colContact),
        h('EVENT DATE', _colEvent),
        h('ADDED', _colAdded),
        h('STATUS', _colStatus),
        const SizedBox(width: 128),
      ]),
    );
  }
}

class _ClientTableRow extends StatelessWidget {
  const _ClientTableRow(
      {required this.row, required this.onOpen, required this.onDelete});
  final ClientRow row;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = row.customer;
    final email = _realEmail(c.email);
    return InkWell(
      onTap: onOpen,
      hoverColor: crm.primary.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: _colClient,
              child: Row(children: [
                _Avatar(name: c.name, color: _statusColor(crm, c.status)),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                      if ((c.company ?? '').trim().isNotEmpty)
                        Text(c.company!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
              ]),
            ),
            Expanded(
              flex: _colContact,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((c.phone ?? '').isEmpty ? '—' : c.phone!,
                      style: TextStyle(fontSize: 13, color: crm.textPrimary)),
                  if (email != null)
                    Text(email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                ],
              ),
            ),
            Expanded(flex: _colEvent, child: _EventCell(c.eventDate)),
            Expanded(
              flex: _colAdded,
              child: row.createdAt == null
                  ? Text('—', style: TextStyle(color: crm.textSecondary))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_dayFmt.format(row.createdAt!),
                            style: TextStyle(
                                fontSize: 13, color: crm.textPrimary)),
                        Text(DateFormat('h:mm a').format(row.createdAt!),
                            style: TextStyle(
                                fontSize: 11.5, color: crm.textSecondary)),
                      ],
                    ),
            ),
            Expanded(
                flex: _colStatus,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusPill(c.status))),
            SizedBox(
              width: 128,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ContactActions(phone: c.phone),
                  _RowMenu(onOpen: onOpen, onDelete: onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard(
      {required this.row, required this.onOpen, required this.onDelete});
  final ClientRow row;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = row.customer;
    final email = _realEmail(c.email);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(name: c.name, color: _statusColor(crm, c.status)),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                      3.h,
                      _StatusPill(c.status),
                    ],
                  ),
                ),
                _ContactActions(phone: c.phone),
                _RowMenu(onOpen: onOpen, onDelete: onDelete),
              ],
            ),
            10.h,
            Padding(
              padding: const EdgeInsets.only(left: 52, right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _iconLine(crm, Icons.phone_outlined,
                      (c.phone ?? '').isEmpty ? '—' : c.phone!),
                  if (email != null) _iconLine(crm, Icons.mail_outline, email),
                  8.h,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label('Event'),
                            3.h,
                            _EventCell(c.eventDate),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label('Added'),
                            3.h,
                            Text(
                                row.createdAt == null
                                    ? '—'
                                    : _dayFmt.format(row.createdAt!),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: crm.textPrimary)),
                            if (row.createdAt != null)
                              Text(DateFormat('h:mm a').format(row.createdAt!),
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: crm.textSecondary)),
                          ],
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

  Widget _iconLine(CrmTheme crm, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          Icon(icon, size: 14, color: crm.textSecondary),
          8.w,
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          ),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.hasFilters,
      required this.onClear,
      required this.onNewBooking});
  final bool hasFilters;
  final VoidCallback onClear;
  final VoidCallback onNewBooking;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(hasFilters ? Icons.filter_alt_off_outlined : Icons.groups_2_outlined,
              size: 52, color: crm.textSecondary.withValues(alpha: 0.45)),
          14.h,
          Text(hasFilters ? 'No clients match these filters' : 'No clients yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: crm.textPrimary)),
          6.h,
          Text(
            hasFilters
                ? 'Try a different search, or clear the filters.'
                : 'Clients are created automatically when you add a booking.',
            textAlign: TextAlign.center,
            style: TextStyle(color: crm.textSecondary),
          ),
          16.h,
          hasFilters
              ? OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Clear filters'))
              : FilledButton.icon(
                  onPressed: onNewBooking,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create first booking')),
        ],
      ),
    );
  }
}

// ── Pagination ──────────────────────────────────────────────────────────────

/// Rounded "‹ Prev · 1 2 … 7 · Next ›" bar (same style as the stock list),
/// with a page-size selector.
class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.narrow,
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.onPage,
    required this.onPageSize,
  });

  final bool narrow;
  final int page; // 1-based
  final int pages;
  final int pageSize;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onPageSize;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;

    final shown = <int>{1, pages, page - 1, page, page + 1}
        .where((i) => i >= 1 && i <= pages)
        .toList()
      ..sort();
    final entries = <int?>[];
    for (final i in shown) {
      if (entries.isNotEmpty && entries.last != null && i - entries.last! > 1) {
        entries.add(null);
      }
      entries.add(i);
    }

    Widget step(String label, IconData icon, int? target, {bool trailing = false}) {
      final enabled = target != null;
      final color =
          enabled ? crm.primary : crm.textSecondary.withValues(alpha: 0.4);
      final ic = Icon(icon, size: 18, color: color);
      return InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: enabled ? () => onPage(target) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!trailing) ic,
            if (!narrow) ...[
              if (!trailing) 2.w,
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              if (trailing) 2.w,
            ],
            if (trailing) ic,
          ]),
        ),
      );
    }

    Widget number(int i) {
      final selected = i == page;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : () => onPage(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$i',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? crm.primary : crm.textSecondary)),
            3.h,
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              width: selected ? 14 : 0,
              decoration: BoxDecoration(
                  color: crm.primary, borderRadius: BorderRadius.circular(2)),
            ),
          ]),
        ),
      );
    }

    Widget divider() => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: crm.border);

    final bar = pages <= 1
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: crm.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              step('Prev', Icons.chevron_left_rounded,
                  page > 1 ? page - 1 : null),
              divider(),
              if (narrow)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: '$page',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: crm.primary)),
                    TextSpan(
                        text: ' / $pages',
                        style: TextStyle(color: crm.textSecondary)),
                  ]), style: const TextStyle(fontSize: 13)),
                )
              else
                for (final e in entries)
                  e == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text('…',
                              style: TextStyle(color: crm.textSecondary)))
                      : number(e),
              divider(),
              step('Next', Icons.chevron_right_rounded,
                  page < pages ? page + 1 : null,
                  trailing: true),
            ]),
          );

    final sizeMenu = PopupMenuButton<int>(
      tooltip: 'Rows per page',
      onSelected: onPageSize,
      itemBuilder: (_) => [
        for (final s in const [20, 50, 100])
          CheckedPopupMenuItem(
              value: s, checked: s == pageSize, child: Text('$s per page')),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$pageSize per page',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        Icon(Icons.expand_more_rounded, size: 16, color: crm.textSecondary),
      ]),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: narrow
          ? Column(children: [bar, 10.h, sizeMenu])
          : Row(children: [
              const Spacer(),
              bar,
              Expanded(
                  child: Align(alignment: Alignment.centerRight, child: sizeMenu)),
            ]),
    );
  }
}
