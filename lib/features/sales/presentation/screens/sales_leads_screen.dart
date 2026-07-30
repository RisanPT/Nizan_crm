import 'package:flutter/material.dart';
import 'package:nizan_crm/core/utils/lead_priority.dart';
import 'package:nizan_crm/core/utils/phone_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/utils/dashboard_report_service.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/services/user_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nizan_crm/services/notification_service.dart';

import 'package:nizan_crm/core/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────
//  Smart-paste parser
// ─────────────────────────────────────────────────────────
class _ParsedLead {
  final String name;
  final String phone;
  final String location;
  final String source;
  final String leadType;
  final String remarks;
  final DateTime? enquiryDate;

  const _ParsedLead({
    this.name = '',
    this.phone = '',
    this.location = '',
    this.source = '',
    this.leadType = '',
    this.remarks = '',
    this.enquiryDate,
  });
}

_ParsedLead _parseClipboardText(String raw) {
  String name = '';
  String phone = '';
  String location = '';
  String source = '';
  String leadType = '';
  String remarks = '';
  DateTime? enquiryDate;

  final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  for (final line in lines) {
    final phoneMatch = RegExp(r'[\+\d][\d\s\-]{7,14}').firstMatch(line);
    if (phoneMatch != null && phone.isEmpty) {
      phone = phoneMatch.group(0)!.replaceAll(RegExp(r'\s'), '');
    }

    if (enquiryDate == null) {
      final dateMatch = RegExp(
        r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})',
      ).firstMatch(line);
      if (dateMatch != null) {
        try {
          final d = int.parse(dateMatch.group(1)!);
          final m = int.parse(dateMatch.group(2)!);
          var y = int.parse(dateMatch.group(3)!);
          if (y < 100) y += 2000;
          enquiryDate = DateTime(y, m, d);
        } catch (_) {}
      }
    }

    final kvMatch = RegExp(r'^([^:：]+)[：:]\s*(.+)$').firstMatch(line);
    if (kvMatch != null) {
      final key = kvMatch.group(1)!.toLowerCase().trim();
      final value = kvMatch.group(2)!.trim();
      if (_matchKey(key, ['name', 'client', 'bride', 'groom', 'customer', 'person'])) {
        name = value;
      } else if (_matchKey(key, ['phone', 'mobile', 'number', 'contact', 'whatsapp', 'ph'])) {
        phone = value.replaceAll(RegExp(r'\s'), '');
      } else if (_matchKey(key, ['location', 'place', 'venue', 'address', 'area', 'city'])) {
        location = value;
      } else if (_matchKey(key, ['source', 'via', 'referred', 'from', 'channel'])) {
        source = value;
      } else if (_matchKey(key, ['type', 'lead type', 'category', 'event type', 'service'])) {
        leadType = value;
      } else if (_matchKey(key, ['remark', 'note', 'comment', 'detail', 'info'])) {
        remarks = value;
      }
    } else if (name.isEmpty && line.length > 2 && line.length < 60) {
      if (!RegExp(r'\d').hasMatch(line) && !line.contains('@')) {
        name = line;
      }
    }
  }

  if (location.isEmpty) {
    for (final line in lines) {
      if (line != name && !line.contains(phone) && line.length < 40 && !RegExp(r'^\d').hasMatch(line)) {
        location = line;
        break;
      }
    }
  }

  return _ParsedLead(
    name: name,
    phone: phone,
    location: location,
    source: source,
    leadType: leadType,
    remarks: remarks,
    enquiryDate: enquiryDate,
  );
}

bool _matchKey(String key, List<String> options) =>
    options.any((o) => key.contains(o));

/// Statuses a user picks directly when creating/editing a lead. "Lost" is NOT
/// here — it goes through the lost-approval flow in the outcome dialog. So do
/// the system states "Pending Lost Approval" and "Converted".
const List<String> kLeadStatuses = ['New', 'Contacted', 'Follow-up'];

/// Outcome-dialog options: the pickers PLUS Lost (which triggers the approval).
const List<String> kOutcomeStatuses = [...kLeadStatuses, 'Lost'];

/// Every status a lead can be in (for filters, badges, colours).
const List<String> kAllLeadStatuses = [
  'New',
  'Contacted',
  'Follow-up',
  'Pending Lost Approval',
  'Lost',
  'Converted',
];
const List<String> kLeadStatusFilters = ['All', ...kAllLeadStatuses];

/// Event types (replaces the old free-text Lead Type).
const List<String> kEventTypes = [
  'Wedding',
  'Reception',
  'Engagement',
  'Haldi',
  'Mehendi',
  'Sangeet',
  'Baby Shower',
  'Birthday',
  'Corporate Event',
  'Photoshoot',
  'Fashion Show',
  'Celebrity Event',
  'Housewarming',
  'Other',
];

/// Map a possibly-legacy status onto a selectable one so a status dropdown
/// never gets a `value` that isn't among its items (which would assert).
String coerceLeadStatus(String s) => kLeadStatuses.contains(s) ? s : 'Contacted';

/// Roles allowed to approve/reject a lost-lead request. Mirrors the backend
/// `LOST_REVIEWER_ROLES` in leadController.js — keep the two in sync.
const Set<String> kLostReviewerRoles = {
  'admin',
  'manager',
  'sales_manager',
  'regional_manager',
};

bool isLostReviewer(String? role) =>
    role != null && kLostReviewerRoles.contains(role);

String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}';
}

String _fmtDateTime(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final amPm = d.hour >= 12 ? 'PM' : 'AM';
  final min = d.minute.toString().padLeft(2, '0');
  return '${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}  $hour:$min $amPm';
}

// ─────────────────────────────────────────────────────────
//  Status color helper (top-level so shared everywhere)
// ─────────────────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'converted': return const Color(0xFF22C55E);
    case 'lost':      return const Color(0xFFEF4444);
    case 'pending lost approval': return const Color(0xFFB45309); // amber-700
    case 'contacted': return const Color(0xFF3B82F6);
    case 'qualified': return const Color(0xFF14B8A6);
    case 'follow-up': return const Color(0xFFF97316);
    default:          return const Color(0xFFF97316);
  }
}

// ─────────────────────────────────────────────────────────
//  Call helper
// ─────────────────────────────────────────────────────────
Future<void> _launchCall(BuildContext context, String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
  if (cleaned.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
    }
    return;
  }
  final uri = Uri.parse('tel:$cleaned');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot launch call to $cleaned')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────
class SalesLeadsScreen extends HookConsumerWidget {
  const SalesLeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    final currentPage = useState(1);
    final searchQuery = useState('');
    final searchCtrl = useTextEditingController();
    final selectedStatus = useState('All');
    final selectedSource = useState('All');
    final selectedSalesperson = useState('All');
    final selectedMonth = useState('All');

    final monthOptions = useMemoized(() {
      final options = <Map<String, String>>[{'label': 'All Months', 'value': 'All'}];
      final now = DateTime.now();
      for (int i = 0; i < 12; i++) {
        final d = DateTime(now.year, now.month - i, 1);
        final label = '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1]} ${d.year}';
        final value = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        options.add({'label': label, 'value': value});
      }
      return options;
    });

    final session = ref.watch(authSessionProvider);
    final isAdminOrManagerOrCRM = session != null && (session.role == 'admin' || session.role == 'manager' || session.role == 'crm');
    final asyncUsers = ref.watch(crmUsersProvider);

    // Debounce search input
    useEffect(() {
      currentPage.value = 1; // Reset to page 1 on search change
      return null;
    }, [searchQuery.value]);

    final filter = LeadFilter(
      page: currentPage.value,
      limit: 20,
      search: searchQuery.value,
      status: selectedStatus.value,
      source: selectedSource.value,
      salesperson: selectedSalesperson.value,
      month: selectedMonth.value,
    );

    final asyncPaginatedLeads = ref.watch(paginatedLeadsProvider(filter));

    void onFilterChange<T>(ValueNotifier<T> notifier, T newValue) {
      if (notifier.value != newValue) {
        notifier.value = newValue;
        currentPage.value = 1; // Reset to page 1 on any filter change
      }
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AddLeadCard(),
            24.h,
            Text(
              'All Leads',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            8.h,
            Text(
              'Track and manage all potential customer inquiries.',
              style: TextStyle(color: crm.textSecondary),
            ),
            20.h,
            asyncPaginatedLeads.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              )),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (paginated) {
                final leads = paginated.items;

                Future<void> exportLeadsReport() async {
                  await _runWithReportLoader(
                    context: context,
                    crmColors: crm,
                    action: () async {
                      // Fetch all matching leads for the report, ignoring pagination
                      final allLeadsResponse = await ref.read(leadServiceProvider).getLeads(
                        LeadFilter(
                          page: 1,
                          limit: 10000,
                          search: searchQuery.value,
                          status: selectedStatus.value,
                          source: selectedSource.value,
                          salesperson: selectedSalesperson.value,
                          month: selectedMonth.value,
                        )
                      );
                      
                      await downloadLeadsReport(
                        leads: allLeadsResponse.items,
                        statusFilter: selectedStatus.value,
                        sourceFilter: selectedSource.value,
                        searchQuery: searchQuery.value,
                        users: asyncUsers.value ?? [],
                      );
                    },
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats for all matching leads; each card doubles as a
                    // one-tap status filter.
                    _LeadStatsRow(
                      stats: paginated.stats ?? {},
                      activeStatus: selectedStatus.value,
                      onSelect: (v) {
                        selectedStatus.value = v;
                        currentPage.value = 1;
                      },
                    ),
                    24.h,
                    // Filter Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: crm.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: crm.border),
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: searchCtrl,
                                  onFieldSubmitted: (value) => onFilterChange(searchQuery, value.trim()),
                                  decoration: InputDecoration(
                                    hintText: 'Search leads...',
                                    hintStyle: TextStyle(color: crm.textSecondary, fontSize: 14),
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    suffixIcon: searchQuery.value.isEmpty
                                        ? IconButton(
                                            onPressed: () => onFilterChange(searchQuery, searchCtrl.text.trim()),
                                            icon: const Icon(Icons.search, size: 20),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                onPressed: () => onFilterChange(searchQuery, searchCtrl.text.trim()),
                                                icon: const Icon(Icons.search, size: 20),
                                              ),
                                              IconButton(
                                                onPressed: () {
                                                  searchCtrl.clear();
                                                  onFilterChange(searchQuery, '');
                                                },
                                                icon: const Icon(Icons.close, size: 20),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: DropdownButton<String>(
                                        value: selectedStatus.value,
                                        isExpanded: true,
                                        onChanged: (val) {
                                          if (val != null) onFilterChange(selectedStatus, val);
                                        },
                                        items: kLeadStatusFilters.map((s) {
                                          return DropdownMenuItem(
                                            value: s,
                                            child: Text(s == 'All' ? 'All Statuses' : s, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                          );
                                        }).toList(),
                                        style: TextStyle(color: crm.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.keyboard_arrow_down),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: DropdownButton<String>(
                                        value: selectedSource.value,
                                        isExpanded: true,
                                        onChanged: (val) {
                                          if (val != null) onFilterChange(selectedSource, val);
                                        },
                                        items: ['All', 'Instagram', 'YouTube', 'Reference', 'Walk-in', 'Other'].map((s) {
                                          return DropdownMenuItem(
                                            value: s,
                                            child: Text(s == 'All' ? 'All Sources' : s, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                          );
                                        }).toList(),
                                        style: TextStyle(color: crm.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.keyboard_arrow_down),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                DropdownButton<String>(
                                  value: selectedMonth.value,
                                  isExpanded: true,
                                  onChanged: (val) {
                                    if (val != null) onFilterChange(selectedMonth, val);
                                  },
                                  items: monthOptions.map((opt) {
                                    return DropdownMenuItem(
                                      value: opt['value'],
                                      child: Text(opt['label']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    );
                                  }).toList(),
                                  style: TextStyle(color: crm.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                ),
                                if (isAdminOrManagerOrCRM) ...[
                                  const Divider(),
                                  DropdownButton<String>(
                                    value: selectedSalesperson.value,
                                    isExpanded: true,
                                    onChanged: (val) {
                                      if (val != null) onFilterChange(selectedSalesperson, val);
                                    },
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'All',
                                        child: Text('All Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      const DropdownMenuItem(
                                        value: 'Unassigned',
                                        child: Text('Unassigned', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      ...asyncUsers.value
                                              ?.where((u) => u.role == 'sales')
                                              .map((u) => DropdownMenuItem(
                                                    value: u.id,
                                                    child: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  ))
                                              .toList() ??
                                          [],
                                    ],
                                    style: TextStyle(color: crm.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.keyboard_arrow_down),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: exportLeadsReport,
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Export Leads'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: crm.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: searchCtrl,
                                    onFieldSubmitted: (value) => onFilterChange(searchQuery, value.trim()),
                                    decoration: InputDecoration(
                                      hintText: 'Search leads (name, phone, location)...',
                                      hintStyle: TextStyle(color: crm.textSecondary, fontSize: 14),
                                      prefixIcon: const Icon(Icons.search, size: 20),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                      suffixIcon: searchQuery.value.isEmpty
                                          ? IconButton(
                                              onPressed: () => onFilterChange(searchQuery, searchCtrl.text.trim()),
                                              icon: const Icon(Icons.search, size: 20),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: () => onFilterChange(searchQuery, searchCtrl.text.trim()),
                                                  icon: const Icon(Icons.search, size: 20),
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    searchCtrl.clear();
                                                    onFilterChange(searchQuery, '');
                                                  },
                                                  icon: const Icon(Icons.close, size: 20),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 24, color: crm.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                DropdownButton<String>(
                                  value: selectedStatus.value,
                                  onChanged: (val) {
                                    if (val != null) onFilterChange(selectedStatus, val);
                                  },
                                  items: kLeadStatusFilters.map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s == 'All' ? 'All Statuses' : s, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    );
                                  }).toList(),
                                  style: TextStyle(color: crm.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                ),
                                Container(width: 1, height: 24, color: crm.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                DropdownButton<String>(
                                  value: selectedSource.value,
                                  onChanged: (val) {
                                    if (val != null) onFilterChange(selectedSource, val);
                                  },
                                  items: ['All', 'Instagram', 'YouTube', 'Reference', 'Walk-in', 'Other'].map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s == 'All' ? 'All Sources' : s, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    );
                                  }).toList(),
                                  style: TextStyle(color: crm.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                ),
                                Container(width: 1, height: 24, color: crm.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                DropdownButton<String>(
                                  value: selectedMonth.value,
                                  onChanged: (val) {
                                    if (val != null) onFilterChange(selectedMonth, val);
                                  },
                                  items: monthOptions.map((opt) {
                                    return DropdownMenuItem(
                                      value: opt['value'],
                                      child: Text(opt['label']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    );
                                  }).toList(),
                                  style: TextStyle(color: crm.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                ),
                                if (isAdminOrManagerOrCRM) ...[
                                  Container(width: 1, height: 24, color: crm.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                  DropdownButton<String>(
                                    value: selectedSalesperson.value,
                                    onChanged: (val) {
                                      if (val != null) onFilterChange(selectedSalesperson, val);
                                    },
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'All',
                                        child: Text('All Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      const DropdownMenuItem(
                                        value: 'Unassigned',
                                        child: Text('Unassigned', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      ...asyncUsers.value
                                              ?.where((u) => u.role == 'sales')
                                              .map((u) => DropdownMenuItem(
                                                    value: u.id,
                                                    child: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  ))
                                              .toList() ??
                                          [],
                                    ],
                                    style: TextStyle(color: crm.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.keyboard_arrow_down),
                                  ),
                                ],
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: exportLeadsReport,
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Export Leads'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: crm.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    20.h,
                    // Lead count badge on mobile
                    if (isMobile) ...[  
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: crm.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${paginated.totalItems} total lead${paginated.totalItems == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: crm.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _LeadsTable(leads: leads, isDesktop: isDesktop),
                    
                    // Pagination Controls
                    if (paginated.totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: paginated.page > 1
                                  ? () => currentPage.value--
                                  : null,
                              color: crm.primary,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                'Page ${paginated.page} of ${paginated.totalPages}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: crm.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: paginated.page < paginated.totalPages
                                  ? () => currentPage.value++
                                  : null,
                              color: crm.primary,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Add Lead Card  (with Smart Paste + responsive form)
// ─────────────────────────────────────────────────────────
class _AddLeadCard extends HookConsumerWidget {
  const _AddLeadCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isExpanded = useState(!isMobile); // collapsed by default on mobile
    final crm = context.crmColors;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crm.border),
      ),
      child: Column(
        children: [
          // ── Header (always visible) ─────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: isMobile ? () => isExpanded.value = !isExpanded.value : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 14 : 20,
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6C63FF)),
                  12.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add New Lead',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        if (!isMobile || isExpanded.value)
                          Text(
                            'Fill manually or paste from WhatsApp / clipboard',
                            style: TextStyle(color: crm.textSecondary, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (isMobile)
                    Icon(
                      isExpanded.value
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: crm.textSecondary,
                    ),
                ],
              ),
            ),
          ),

          // ── Form (collapsible on mobile) ────────────────
          if (isExpanded.value)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                0,
                isMobile ? 16 : 24,
                isMobile ? 20 : 24,
              ),
              child: _LeadForm(
                onSaved: () => ref.invalidate(leadsProvider),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lays form fields into an aligned grid on desktop. Each field declares a
/// column span; a field that would overflow the current row starts a new one,
/// and the last row is padded so widths stay consistent.
class _FormGrid extends StatelessWidget {
  final List<(Widget, int)> fields;

  static const double gap = 16;

  const _FormGrid({required this.fields});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Four columns on a wide window, two on a narrow one, so fields never
        // squeeze below a usable width.
        final columns = c.maxWidth >= 1000 ? 4 : 2;
        return _buildGrid(columns);
      },
    );
  }

  Widget _buildGrid(int columns) {
    final rows = <List<(Widget, int)>>[];
    var current = <(Widget, int)>[];
    var used = 0;

    for (final f in fields) {
      final span = f.$2.clamp(1, columns);
      if (used + span > columns) {
        rows.add(current);
        current = [];
        used = 0;
      }
      current.add((f.$1, span));
      used += span;
    }
    if (current.isNotEmpty) rows.add(current);

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: EdgeInsets.only(bottom: row == rows.last ? 0 : gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  Expanded(flex: row[i].$2, child: row[i].$1),
                  if (i != row.length - 1) SizedBox(width: gap),
                ],
                // Pad the final row so a half-full row keeps column widths.
                if (row.fold<int>(0, (a, b) => a + b.$2) < columns) ...[
                  SizedBox(width: gap),
                  Spacer(
                      flex: columns - row.fold<int>(0, (a, b) => a + b.$2)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Shared Lead Form (used in Add card and Edit dialog)
// ─────────────────────────────────────────────────────────
class _LeadForm extends HookConsumerWidget {
  final Lead? initialLead; // null = add new
  final VoidCallback onSaved;

  const _LeadForm({this.initialLead, required this.onSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isEditing = initialLead != null;

    final nameCtrl      = useTextEditingController(text: initialLead?.name ?? '');
    final phoneCtrl     = useTextEditingController(text: initialLead?.phone ?? '');
    final alternateCtrl = useTextEditingController(text: initialLead?.alternateNumber ?? '');
    final selectedSource   = useState(initialLead?.source ?? 'Instagram');
    final customSourceCtrl = useTextEditingController(
      text: _isKnownSource(initialLead?.source) ? '' : (initialLead?.source ?? ''),
    );
    final locationCtrl  = useTextEditingController(text: initialLead?.location ?? '');
    final leadTypeCtrl  = useTextEditingController(text: initialLead?.leadType ?? 'Individual');
    // Event Type replaces Lead Type. Default to a valid option so the dropdown
    // never gets an unknown value.
    final eventType = useState(
      kEventTypes.contains(initialLead?.eventType)
          ? initialLead!.eventType
          : (initialLead?.eventType.isNotEmpty ?? false ? 'Other' : 'Wedding'),
    );
    final remarksCtrl   = useTextEditingController(text: initialLead?.remarks ?? '');
    final enquiryDate   = useState(initialLead?.enquiryDate ?? DateTime.now());
    final bookedDate    = useState<DateTime?>(initialLead?.bookedDate);
    final followUpDate  = useState<DateTime?>(initialLead?.followUpDate);
    // Keep the real status so a system state (Converted / Lost / Pending) isn't
    // silently downgraded on edit — the picker just can't SELECT those.
    final status        = useState(initialLead?.status ?? 'New');
    final priority      = useState(initialLead?.priority ?? 'Warm');
    final assignedTo    = useState<String?>(initialLead?.assignedTo);
    final asyncUsers    = ref.watch(crmUsersProvider);
    final session       = ref.watch(authSessionProvider);
    final isAdminOrManager = session != null && (session.role == 'admin' || session.role == 'manager');
    final isSaving      = useState(false);
    final isPasting     = useState(false);
    final sampleIndex   = useState(0);

    // Fix source dropdown: if the stored value isn't a known option, use 'Other'
    if (!_isKnownSource(selectedSource.value) && selectedSource.value != 'Other') {
      customSourceCtrl.text = selectedSource.value;
      selectedSource.value = 'Other';
    }

    // ── smart paste ──────────────────────────────────────
    Future<void> smartPaste() async {
      isPasting.value = true;
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text ?? '';
        if (text.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Clipboard is empty.')),
            );
          }
          return;
        }
        final parsed = _parseClipboardText(text);
        if (parsed.name.isNotEmpty)     nameCtrl.text     = parsed.name;
        if (parsed.phone.isNotEmpty)    phoneCtrl.text    = parsed.phone;
        if (parsed.location.isNotEmpty) locationCtrl.text = parsed.location;
        if (parsed.source.isNotEmpty) {
          const knownSources = ['Instagram', 'YouTube', 'Reference', 'Walk-in'];
          final matched = knownSources.firstWhere(
            (s) => s.toLowerCase() == parsed.source.toLowerCase(),
            orElse: () => 'Other',
          );
          selectedSource.value = matched;
          if (matched == 'Other') customSourceCtrl.text = parsed.source;
        }
        if (parsed.leadType.isNotEmpty) leadTypeCtrl.text = parsed.leadType;
        if (parsed.remarks.isNotEmpty)  remarksCtrl.text  = parsed.remarks;
        if (parsed.enquiryDate != null) enquiryDate.value = parsed.enquiryDate!;

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pasted! Name: "${parsed.name}", Phone: "${parsed.phone}"'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } finally {
        isPasting.value = false;
      }
    }

    // ── save / update ─────────────────────────────────────
    Future<void> save() async {
      if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and Phone are required')),
        );
        return;
      }
      isSaving.value = true;
      try {
        final dio = ref.read(dioProvider);

        // Set when the user chooses to create a lead despite a duplicate match,
        // so the server-side duplicate guard lets it through.
        var allowDuplicate = false;

        // 1. Duplicate Check
        if (!isEditing) {
          final phoneNorm = normalizePhone(phoneCtrl.text);
          final altNorm = normalizePhone(alternateCtrl.text);
          
          if (phoneNorm.isNotEmpty || altNorm.isNotEmpty) {
            try {
              final dupRes = await dio.get('/leads', queryParameters: {
                'limit': 10,
                'search': phoneNorm.isNotEmpty ? phoneNorm : altNorm,
              });
              final data = dupRes.data;
              List items = [];
              if (data is Map && data.containsKey('items')) {
                items = data['items'] as List;
              } else if (data is Map) {
                items = (data['data'] ?? data['leads'] ?? []) as List;
              } else if (data is List) {
                items = data;
              }
              
              bool duplicateFound = false;
              for (var i in items) {
                final leadPhone = i['phone']?.toString() ?? '';
                final leadAlt = i['alternateNumber']?.toString() ?? '';
                
                if (phoneNorm.isNotEmpty && (leadPhone == phoneNorm || leadAlt == phoneNorm)) duplicateFound = true;
                if (altNorm.isNotEmpty && (leadPhone == altNorm || leadAlt == altNorm)) duplicateFound = true;
              }

              if (duplicateFound && context.mounted) {
                final proceed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Duplicate Contact Found'),
                    content: const Text('A lead with this Primary or Alternate number already exists. Do you still want to create it?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed')),
                    ],
                  ),
                );
                if (proceed != true) {
                  isSaving.value = false;
                  return;
                }
                // User accepted the duplicate — tell the server to allow it.
                allowDuplicate = true;
              }
            } catch (e) {
              // Ignore search errors and proceed
            }
          }
        }

        final payload = {
          'name': nameCtrl.text,
          'phone': normalizePhone(phoneCtrl.text),
          'priority': priority.value,
          'source': selectedSource.value == 'Other'
              ? customSourceCtrl.text.trim()
              : selectedSource.value,
          'location': locationCtrl.text,
          'leadType': leadTypeCtrl.text,
          'eventType': eventType.value,
          'alternateNumber': normalizePhone(alternateCtrl.text),
          'enquiryDate': enquiryDate.value.toIso8601String(),
          'bookedDate': bookedDate.value?.toIso8601String(),
          'followUpDate': followUpDate.value?.toIso8601String(),
          // Only send an editable status. System states (Lost / Pending /
          // Converted) are managed by their own flows and preserved server-side.
          if (kLeadStatuses.contains(status.value)) 'status': status.value,
          // 'reason' is intentionally omitted — it belongs to the Lost-approval
          // flow. Sending it here would erase the reason on a normal edit.
          'remarks': remarksCtrl.text,
          'assignedTo': (session?.role == 'sales') ? session?.userId : assignedTo.value,
          if (allowDuplicate) 'allowDuplicate': true,
        };

        String leadIdStr = '';
        if (isEditing) {
          leadIdStr = initialLead!.id;
          await dio.put('/leads/$leadIdStr', data: payload);
        } else {
          final res = await dio.post('/leads', data: payload);
          if (res.data is Map) {
             leadIdStr = res.data['_id']?.toString() ?? res.data['id']?.toString() ?? '';
          }
          // Reset form after add
          nameCtrl.clear();
          phoneCtrl.clear();
          locationCtrl.clear();
          alternateCtrl.clear();
          remarksCtrl.clear();
          customSourceCtrl.clear();
          leadTypeCtrl.text = 'Individual';
          eventType.value = 'Wedding';
          selectedSource.value = 'Instagram';
          enquiryDate.value = DateTime.now();
          bookedDate.value = null;
          followUpDate.value = null;
          status.value = 'New';
          assignedTo.value = null;
        }

        // Schedule or cancel notification
        if (leadIdStr.isNotEmpty) {
          final notifId = leadIdStr.hashCode;
          if (payload['followUpDate'] != null) {
            final dt = DateTime.parse(payload['followUpDate'] as String);
            // import required: import 'package:nizan_crm/services/notification_service.dart';
            await NotificationService().scheduleFollowUpNotification(
              id: notifId,
              title: 'Follow-up Due: ${payload['name']}',
              body: 'Follow-up with ${payload['name']} (${payload['phone']})',
              scheduledDate: dt,
            );
          } else {
            await NotificationService().cancelNotification(notifId);
          }
        }

        onSaved();
        if (context.mounted) {
          if (isEditing) Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Lead updated!' : 'Lead added successfully!'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    // ── date picker helper (allows past dates) ─────────────────────────────────
    Future<void> pickDate({
      required DateTime initial,
      required void Function(DateTime) onPicked,
      DateTime? firstDate,
      DateTime? lastDate,
    }) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: firstDate ?? DateTime(2015), // allow past dates
        lastDate: lastDate ?? DateTime(2100),
      );
      if (picked != null) onPicked(picked);
    }

    // ── date + time picker helper ────────────────────────────────────────────
    Future<void> pickDateTime({
      required DateTime initial,
      required void Function(DateTime) onPicked,
    }) async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2015),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null) return;
      if (!context.mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      );
      if (pickedTime == null) return;
      onPicked(DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute,
      ));
    }

    // ── UI ────────────────────────────────────────────────
    Widget buildField(Widget child) => child;

    // Fields declare how many grid columns they occupy on desktop; on mobile
    // everything stacks full width. Using spans (rather than fixed pixel
    // widths in a Wrap) keeps every row aligned at any window size.
    (Widget, int) responsiveField(Widget field, {double desktopWidth = 220}) {
      final span = desktopWidth >= 340 ? 2 : 1;
      return (field, span);
    }

    final List<(Widget, int)> fields = [
      // Name
      responsiveField(
        TextFormField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name *',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        desktopWidth: 250,
      ),

      // Phone + Call button row (only on mobile form; desktop uses separate layout)
      responsiveField(
        isMobile
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick call button in the form
                  Container(
                    height: 56,
                    width: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.call_rounded, color: Color(0xFF22C55E), size: 22),
                      tooltip: 'Call',
                      onPressed: () => _launchCall(context, phoneCtrl.text),
                    ),
                  ),
                ],
              )
            : TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.call_rounded, color: Color(0xFF22C55E), size: 20),
                    tooltip: 'Call',
                    onPressed: () => _launchCall(context, phoneCtrl.text),
                  ),
                ),
              ),
        desktopWidth: 230,
      ),

      // Enquiry Date — allows past dates
      responsiveField(
        InkWell(
          onTap: () => pickDate(
            initial: enquiryDate.value,
            onPicked: (d) => enquiryDate.value = d,
            firstDate: DateTime(2015), // past allowed
          ),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date Enquired For',
              prefixIcon: Icon(Icons.calendar_today_outlined),
              helperText: 'Past dates allowed',
              helperStyle: TextStyle(fontSize: 10),
            ),
            child: Text(_fmtDate(enquiryDate.value)),
          ),
        ),
        desktopWidth: 210,
      ),

      // Booked Date
      responsiveField(
        InkWell(
          onTap: () => pickDate(
            initial: bookedDate.value ?? DateTime.now(),
            onPicked: (d) => bookedDate.value = d,
          ),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Booked Date',
              prefixIcon: Icon(Icons.bookmark_added_outlined),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(bookedDate.value != null ? _fmtDate(bookedDate.value!) : 'Not Booked'),
                if (bookedDate.value != null)
                  GestureDetector(
                    onTap: () => bookedDate.value = null,
                    child: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ),
        ),
        desktopWidth: 200,
      ),

      // Source
      responsiveField(
        DropdownButtonFormField<String>(
          initialValue: selectedSource.value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Source',
            prefixIcon: Icon(Icons.campaign_outlined),
          ),
          items: ['Instagram', 'YouTube', 'Reference', 'Walk-in', 'Other']
              .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            selectedSource.value = v!;
            if (v != 'Other') customSourceCtrl.clear();
          },
        ),
        desktopWidth: 180,
      ),

      // Custom Source
      if (selectedSource.value == 'Other')
        responsiveField(
          TextFormField(
            controller: customSourceCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Specify Source',
              prefixIcon: Icon(Icons.edit_outlined),
              hintText: 'e.g. Google Ads',
            ),
          ),
          desktopWidth: 180,
        ),

      // Location
      responsiveField(
        TextFormField(
          controller: locationCtrl,
          decoration: const InputDecoration(
            labelText: 'Location',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        desktopWidth: 180,
      ),

      // Event Type (replaces Lead Type)
      responsiveField(
        DropdownButtonFormField<String>(
          initialValue: eventType.value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Event Type',
            prefixIcon: Icon(Icons.celebration_outlined),
          ),
          items: kEventTypes
              .map((e) => DropdownMenuItem(
                  value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            if (v != null) eventType.value = v;
          },
        ),
        desktopWidth: 180,
      ),

      // Alternate Number (optional)
      responsiveField(
        TextFormField(
          controller: alternateCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Alternate Number (Optional)',
            prefixIcon: Icon(Icons.phone_forwarded_outlined),
          ),
        ),
        desktopWidth: 180,
      ),

      // Status
      responsiveField(
        DropdownButtonFormField<String>(
          initialValue: status.value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Status',
            prefixIcon: Icon(Icons.info_outline),
          ),
          items: <String>{
            ...kLeadStatuses,
            // Show the current status even if it's a system state, so the
            // dropdown never gets a value that isn't among its items.
            status.value,
          }
              .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            status.value = v!;
            // Clear followUpDate if switching away from Follow-up
            if (v != 'Follow-up') followUpDate.value = null;
          },
        ),
        desktopWidth: 180,
      ),

      // Follow-up Date & Time — shown only when status is Follow-up
      if (status.value == 'Follow-up')
        responsiveField(
          InkWell(
            onTap: () => pickDateTime(
              initial: followUpDate.value ?? DateTime.now().add(const Duration(days: 1)),
              onPicked: (dt) => followUpDate.value = dt,
            ),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Follow-up Date & Time *',
                prefixIcon: const Icon(Icons.event_available_outlined, color: Color(0xFFF97316)),
                labelStyle: const TextStyle(color: Color(0xFFF97316)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
                ),
                suffixIcon: followUpDate.value != null
                    ? GestureDetector(
                        onTap: () => followUpDate.value = null,
                        child: const Icon(Icons.close, size: 16, color: Color(0xFFF97316)),
                      )
                    : null,
              ),
              child: Text(
                followUpDate.value != null
                    ? _fmtDateTime(followUpDate.value!)
                    : 'Tap to set follow-up time',
                style: TextStyle(
                  color: followUpDate.value != null
                      ? const Color(0xFFF97316)
                      : Colors.grey,
                ),
              ),
            ),
          ),
          desktopWidth: 240,
        ),

      // The lost reason is captured in the Lost-approval flow (Record Outcome),
      // not on the entry form — a lead can't be marked Lost from here.

      // Assign Sales Executive (Admin/Manager view only)
      if (isAdminOrManager)
        responsiveField(
          DropdownButtonFormField<String>(
            initialValue: assignedTo.value,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Assign Sales Executive',
              prefixIcon: Icon(Icons.assignment_ind_outlined),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Unassigned (None)'),
              ),
              ...asyncUsers.value
                      ?.where((u) => u.role == 'sales')
                      .map((u) => DropdownMenuItem<String>(
                            value: u.id,
                            child: Text(u.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList() ??
                  [],
            ],
            onChanged: (v) {
              assignedTo.value = v;
            },
          ),
          desktopWidth: 220,
        ),

      // Lead priority — how likely this lead is to close.
      responsiveField(
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Priority',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: LeadPrioritySelector(
              value: priority.value,
              onChanged: (v) => priority.value = v,
            ),
          ),
        ),
        desktopWidth: 340,
      ),
      // Remarks
      responsiveField(
        TextFormField(
          controller: remarksCtrl,
          maxLines: isMobile ? 3 : 1,
          decoration: const InputDecoration(
            labelText: 'Remarks',
            prefixIcon: Icon(Icons.notes),
            alignLabelWithHint: true,
          ),
        ),
        desktopWidth: 400,
      ),
    ];

    return buildField(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Action buttons row ──────────────────────────
          if (!isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: Builder(builder: (ctx) {
                    const samples = [
                      (
                        label: 'Instagram',
                        text:
                            'Name: Fatima Noor\n'
                            'Phone: 9876543210\n'
                            'Location: Calicut\n'
                            'Source: Instagram\n'
                            'Date: 25/06/2026\n'
                            'Lead Type: Bridal\n'
                            'Remarks: Full bridal makeup + saree draping',
                      ),
                      (
                        label: 'YouTube',
                        text:
                            'Name: Rahul Menon\n'
                            'Phone: 9745123456\n'
                            'Location: Kochi\n'
                            'Source: YouTube\n'
                            'Date: 10/07/2026\n'
                            'Lead Type: Groom\n'
                            'Remarks: Saw tutorial video, wants groom package',
                      ),
                      (
                        label: 'Reference',
                        text:
                            'Name: Sana Fathima\n'
                            'Phone: 9812005678\n'
                            'Location: Thrissur\n'
                            'Source: Reference\n'
                            'Date: 05/08/2026\n'
                            'Lead Type: Individual\n'
                            'Remarks: Referred by Aisha Khan – birthday party makeup',
                      ),
                      (
                        label: 'Other (Google Ads)',
                        text:
                            'Name: Divya Krishnan\n'
                            'Phone: 9900112233\n'
                            'Location: Kozhikode\n'
                            'Source: Google Ads\n'
                            'Date: 20/09/2026\n'
                            'Lead Type: Bridal\n'
                            'Remarks: Enquiry from Google ad campaign',
                      ),
                    ];
                    final idx = sampleIndex.value % samples.length;
                    final current = samples[idx];
                    return OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: current.text));
                        sampleIndex.value = (idx + 1) % samples.length;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '📋 "${current.label}" sample copied! Tap Smart Paste →',
                            ),
                            backgroundColor: Colors.teal[700],
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: Text(
                        isMobile ? 'Copy: ${current.label}' : 'Copy: ${current.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }),
                ),
                12.w,
                ElevatedButton.icon(
                  onPressed: isPasting.value ? null : smartPaste,
                  icon: isPasting.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.content_paste_rounded, size: 18),
                  label: const Text('Smart Paste'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            12.h,
            // ── Paste format hint ───────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF6C63FF)),
                  8.w,
                  Expanded(
                    child: Text(
                      'WhatsApp format: Name: Aisha | Phone: 9876543210 | Location: Calicut | Date: 15/06/2026 | Remarks: Bridal makeup',
                      style: TextStyle(
                        fontSize: 12,
                        color: crm.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            16.h,
          ],

          // ── Form fields ─────────────────────────────────
          if (isMobile)
            // Stack fields vertically on mobile
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: fields
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: f.$1,
                      ))
                  .toList(),
            )
          else
            _FormGrid(fields: fields),

          if (!isMobile) 24.h else 8.h,

          // ── Save button ─────────────────────────────────
          SizedBox(
            height: 52,
            width: isMobile ? double.infinity : 200,
            child: ElevatedButton.icon(
              onPressed: isSaving.value ? null : save,
              icon: isSaving.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isEditing ? Icons.check_rounded : Icons.save_outlined),
              label: Text(isEditing ? 'Update Lead' : 'Save Lead'),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isKnownSource(String? s) {
  if (s == null) return false;
  return ['Instagram', 'YouTube', 'Reference', 'Walk-in', 'Other'].contains(s);
}

// ─────────────────────────────────────────────────────────
//  Edit Lead Dialog / Bottom Sheet
// ─────────────────────────────────────────────────────────
Future<void> _showEditDialog(BuildContext context, WidgetRef ref, Lead lead) async {
  final isMobile = ResponsiveBuilder.isMobile(context);
  if (isMobile) {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const _BottomSheetHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.edit_rounded, color: Color(0xFF6C63FF)),
                    12.w,
                    const Text(
                      'Edit Lead',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Consumer(
                    builder: (ctx, ref, _) => _LeadForm(
                      initialLead: lead,
                      onSaved: () => ref.invalidate(leadsProvider),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } else {
    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_rounded, color: Color(0xFF6C63FF)),
                    12.w,
                    const Text(
                      'Edit Lead',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                16.h,
                Consumer(
                  builder: (ctx, ref, _) => _LeadForm(
                    initialLead: lead,
                    onSaved: () => ref.invalidate(leadsProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Delete confirmation
// ─────────────────────────────────────────────────────────
Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Lead lead) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Delete Lead'),
      content: Text('Delete lead for "${lead.name}"? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  try {
    await ref.read(leadServiceProvider).deleteLead(lead.id);
    ref.invalidate(leadsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead deleted.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────
//  Leads table / mobile cards
// ─────────────────────────────────────────────────────────
class _LeadsTable extends ConsumerWidget {
  final List<Lead> leads;
  final bool isDesktop;

  const _LeadsTable({required this.leads, required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final double width = MediaQuery.of(context).size.width;

    if (leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('No leads found.', style: TextStyle(color: crm.textSecondary)),
        ),
      );
    }

    final int crossAxisCount = width < 600
        ? 1
        : (width < 1000
            ? 2
            : (width < 1400 ? 3 : 4));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 360,
      ),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        final lead = leads[index];
        return _LeadCard(
          lead: lead,
          onEdit: () => _showEditDialog(context, ref, lead),
          onDelete: () => _confirmDelete(context, ref, lead),
          onRecordOutcome: () => _showRecordOutcomeDialog(context, ref, lead),
          onViewDetails: () => context.go('/sales/leads/${lead.id}'),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Lead Card (fully responsive grid card with hover animation & eye icon)
// ─────────────────────────────────────────────────────────
class _LeadCard extends StatefulWidget {
  final Lead lead;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRecordOutcome;
  final VoidCallback onViewDetails;

  const _LeadCard({
    required this.lead,
    required this.onEdit,
    required this.onDelete,
    required this.onRecordOutcome,
    required this.onViewDetails,
  });

  @override
  State<_LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends State<_LeadCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final crm = context.crmColors;
    final color = _statusColor(lead.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? crm.primary.withValues(alpha: 0.5) : crm.border,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: crm.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onViewDetails,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: crm.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _fmtDate(lead.leadDate),
                            style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LeadPriorityChip(lead.priority, dense: true),
                          const SizedBox(width: 6),
                          _StatusBadge(status: lead.status),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lead.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _launchCall(context, lead.phone),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.call_rounded, size: 12, color: Color(0xFF22C55E)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lead.phone.isNotEmpty ? lead.phone : 'No phone',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            'Tap to call',
                            style: TextStyle(fontSize: 10, color: Color(0xFF22C55E)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.campaign_outlined, label: 'Source', value: lead.source),
                  const SizedBox(height: 6),
                  _InfoRow(icon: Icons.category_outlined, label: 'Type', value: lead.leadType),
                  const SizedBox(height: 6),
                  _InfoRow(icon: Icons.location_on_outlined, label: 'Location', value: lead.location.isNotEmpty ? lead.location : '-'),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Event Date',
                    value: _fmtDate(lead.enquiryDate),
                  ),
                  if (lead.bookedDate != null || lead.followUpDate != null) ...[
                    const SizedBox(height: 8),
                    if (lead.bookedDate != null)
                      _InfoRow(
                        icon: Icons.bookmark_added_outlined,
                        label: 'Booked',
                        value: _fmtDate(lead.bookedDate!),
                        valueColor: const Color(0xFF22C55E),
                      ),
                    if (lead.followUpDate != null)
                      Row(
                        children: [
                          const Icon(Icons.event_available_outlined, size: 14, color: Color(0xFFF97316)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Follow-up: ${_fmtDateTime(lead.followUpDate!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFF97316),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                  // How many times this lead has been followed up — shown even
                  // after it has moved off the Follow-up stage.
                  if (lead.followUpCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.repeat_rounded, size: 14, color: Color(0xFFF97316)),
                        const SizedBox(width: 4),
                        Text(
                          '${lead.followUpCount} follow-up${lead.followUpCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFF97316),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (lead.remarks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        lead.remarks,
                        style: TextStyle(fontSize: 11, color: crm.textSecondary, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ActionButton(
                        icon: Icons.visibility_outlined,
                        tooltip: 'View Details',
                        color: Colors.blue,
                        onPressed: widget.onViewDetails,
                      ),
                      _ActionButton(
                        icon: Icons.call_rounded,
                        tooltip: 'Call (Cloud/SIM)',
                        color: const Color(0xFF22C55E),
                        onPressed: () => _initiateCallFlow(context, lead.phone),
                      ),
                      _ActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        tooltip: 'WhatsApp Message',
                        color: const Color(0xFF25D366),
                        onPressed: () => _launchWhatsApp(context, lead.phone),
                      ),
                      _ActionButton(
                        icon: Icons.add_circle_outline_rounded,
                        tooltip: 'Record Outcome',
                        color: Colors.orange,
                        onPressed: widget.onRecordOutcome,
                      ),
                      _ActionButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        color: const Color(0xFF6C63FF),
                        onPressed: widget.onEdit,
                      ),
                      _ActionButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete',
                        color: Colors.red,
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        color: color,
        onPressed: onPressed,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Row(
      children: [
        Icon(icon, size: 15, color: crm.textSecondary),
        6.w,
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: crm.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

Future<void> _runWithReportLoader({
  required BuildContext context,
  required CrmTheme crmColors,
  required Future<void> Function() action,
}) async {
  NavigatorState? dialogNavigator;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      dialogNavigator = Navigator.of(dialogContext);
      return Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(crmColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Generating Report',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: crmColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please wait while the PDF is prepared...',
                  style: TextStyle(
                    color: crmColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  // Yield frame to render loading dialog
  await Future.delayed(const Duration(milliseconds: 100));

  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: crmColors.destructive,
        ),
      );
    }
  } finally {
    if (dialogNavigator != null && dialogNavigator!.mounted) {
      dialogNavigator!.pop();
    }
  }
}

// ─────────────────────────────────────────────────────────
//  WhatsApp helper
// ─────────────────────────────────────────────────────────
Future<void> _launchWhatsApp(BuildContext context, String phone) async {
  var cleaned = phone.replaceAll(RegExp(r'\D'), '');
  if (cleaned.startsWith('0')) {
    cleaned = cleaned.substring(1);
  }
  if (cleaned.length == 10) {
    cleaned = '91$cleaned';
  }
  if (cleaned.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
    }
    return;
  }
  final uri = Uri.parse('https://wa.me/$cleaned');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open WhatsApp for $cleaned')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────
//  Initiate Call flow (Cloud vs Standard)
// ─────────────────────────────────────────────────────────
void _initiateCallFlow(BuildContext context, String phone) {
  if (phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No phone number available')),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BottomSheetHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Initiate Call to $phone',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined, color: Colors.blue),
              title: const Text('Cloud Calling (Recorded)'),
              subtitle: const Text('Initiate call via cloud gateway with recording'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Initiating Cloud Call to $phone (Recording active)...'),
                    backgroundColor: Colors.blue[700],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined, color: Colors.green),
              title: const Text('Standard Phone Calling'),
              subtitle: const Text('Dial directly using your device SIM card'),
              onTap: () {
                Navigator.of(context).pop();
                _launchCall(context, phone);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────
//  Record Outcome Dialog helpers
// ─────────────────────────────────────────────────────────
void _showRecordOutcomeDialog(BuildContext context, WidgetRef ref, Lead lead) {
  showDialog(
    context: context,
    builder: (context) {
      return _RecordOutcomeDialog(lead: lead, onSaved: () => ref.invalidate(leadsProvider));
    },
  );
}

class _RecordOutcomeDialog extends HookConsumerWidget {
  final Lead lead;
  final VoidCallback onSaved;

  const _RecordOutcomeDialog({required this.lead, required this.onSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final canReview = isLostReviewer(session?.role);
    final isPendingLost = lead.status == 'Pending Lost Approval';
    final status = useState(coerceLeadStatus(lead.status));
    final followUpDate = useState<DateTime?>(lead.followUpDate);
    final remarksCtrl = useTextEditingController(text: lead.remarks);
    final reasonCtrl = useTextEditingController(text: lead.reason);
    final competitorCtrl = useTextEditingController(text: lead.competitorName);
    final reviewNoteCtrl = useTextEditingController();
    final reminderMinutes = useState<int>(0); // 0 = None, 5 = 5m prior, 10 = 10m prior
    final lostAttachmentPath = useState<String?>(null);
    final isSaving = useState(false);

    Future<void> pickAttachment() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        lostAttachmentPath.value = picked.path;
      }
    }

    Future<void> pickDateTime() async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: followUpDate.value ?? DateTime.now(),
        firstDate: DateTime(2015),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null) return;
      if (!context.mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime == null) return;
      followUpDate.value = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute,
      );
    }

    // Marking a lead Lost is a request that a Sales Manager / Regional Manager
    // (or Admin) must approve — it does NOT close the lead outright. Reason and
    // remarks are mandatory; competitor name is optional. Reviewers still go
    // through this call, but the server closes the lead for them immediately.
    Future<void> requestLost() async {
      if (reasonCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A Lost reason is required')),
        );
        return;
      }
      if (remarksCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remarks are required to mark a lead Lost')),
        );
        return;
      }
      isSaving.value = true;
      try {
        await ref.read(leadServiceProvider).requestLostApproval(
              lead.id,
              reason: reasonCtrl.text.trim(),
              remarks: remarksCtrl.text.trim(),
              competitorName: competitorCtrl.text.trim(),
              lostAttachment: lostAttachmentPath.value,
            );
        onSaved();
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(canReview
                  ? 'Lead marked as Lost.'
                  : 'Lost request submitted for approval.'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    // A reviewer approves (→ Lost) or rejects (→ back to the prior stage) a
    // pending lost request.
    Future<void> reviewLost(bool approve) async {
      isSaving.value = true;
      try {
        await ref.read(leadServiceProvider).reviewLostApproval(
              lead.id,
              approve: approve,
              note: reviewNoteCtrl.text.trim(),
            );
        onSaved();
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approve
                  ? 'Lost request approved — lead closed.'
                  : 'Lost request rejected — lead reopened.'),
              backgroundColor: approve ? Colors.green[700] : Colors.orange[800],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    Future<void> saveOutcome() async {
      // Lost is not a plain status change — it routes through the approval flow.
      if (status.value == 'Lost') {
        await requestLost();
        return;
      }
      isSaving.value = true;
      try {
        final dio = ref.read(dioProvider);

        // Append reminder info to remarks if any reminder selected
        var finalRemarks = remarksCtrl.text;
        if (status.value == 'Follow-up' && reminderMinutes.value > 0) {
          finalRemarks += '\n[Reminder set for ${reminderMinutes.value} minutes prior]';
        }

        final payload = {
          'name': lead.name,
          'phone': lead.phone,
          'source': lead.source,
          'location': lead.location,
          'leadType': lead.leadType,
          'eventType': lead.eventType,
          'alternateNumber': lead.alternateNumber,
          'enquiryDate': lead.enquiryDate.toIso8601String(),
          'bookedDate': lead.bookedDate?.toIso8601String(),
          'followUpDate': followUpDate.value?.toIso8601String(),
          'status': status.value,
          'reason': reasonCtrl.text,
          'remarks': finalRemarks,
        };

        await dio.put('/leads/${lead.id}', data: payload);
        onSaved();

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reminderMinutes.value > 0
                ? 'Outcome updated and reminder scheduled!'
                : 'Outcome updated successfully!'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Record Outcome',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // ── A lead awaiting lost approval: show the request + reviewer actions.
              if (isPendingLost) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.hourglass_top, size: 18, color: Color(0xFFB45309)),
                          SizedBox(width: 8),
                          Text(
                            'Pending Lost Approval',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _pendingLostRow('Reason', lead.reason),
                      _pendingLostRow('Remarks', lead.remarks),
                      if (lead.competitorName.trim().isNotEmpty)
                        _pendingLostRow('Competitor', lead.competitorName),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (canReview) ...[
                  TextFormField(
                    controller: reviewNoteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Review note (optional)',
                      prefixIcon: Icon(Icons.rate_review_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSaving.value ? null : () => reviewLost(false),
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                            side: const BorderSide(color: Color(0xFFB91C1C)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isSaving.value ? null : () => reviewLost(true),
                          icon: isSaving.value
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'This lead is awaiting a manager\'s approval before it can be '
                    'closed as Lost. You will be notified once it is reviewed.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ] else ...[
                // ── Normal outcome editor.
                // Status Dropdown
                DropdownButtonFormField<String>(
                  initialValue: status.value,
                  decoration: const InputDecoration(
                    labelText: 'Select Status / Outcome *',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  items: kOutcomeStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    status.value = v!;
                    if (v != 'Follow-up') followUpDate.value = null;
                  },
                ),
                const SizedBox(height: 16),

                // Follow-up Date/Time
                if (status.value == 'Follow-up') ...[
                  InkWell(
                    onTap: pickDateTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Follow-up Date & Time *',
                        prefixIcon: Icon(Icons.event_available_outlined, color: Color(0xFFF97316)),
                      ),
                      child: Text(
                        followUpDate.value != null
                            ? _fmtDateTime(followUpDate.value!)
                            : 'Tap to schedule',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reminder Offset
                  DropdownButtonFormField<int>(
                    initialValue: reminderMinutes.value,
                    decoration: const InputDecoration(
                      labelText: 'Set Reminder',
                      prefixIcon: Icon(Icons.alarm_on_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('No Reminder')),
                      DropdownMenuItem(value: 5, child: Text('5 minutes prior')),
                      DropdownMenuItem(value: 10, child: Text('10 minutes prior')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes prior')),
                    ],
                    onChanged: (v) {
                      if (v != null) reminderMinutes.value = v;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Lost workflow fields: reason + competitor (remarks below is
                // reused as the mandatory remark for a lost request).
                if (status.value == 'Lost') ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Text(
                      canReview
                          ? 'This will close the lead as Lost and record the reason in the audit log.'
                          : 'Marking Lost sends a request to your manager for approval. '
                              'The lead stays open until it is approved.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                    ),
                  ),
                  TextFormField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Lost *',
                      prefixIcon: Icon(Icons.help_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: competitorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Competitor Name (optional)',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: pickAttachment,
                        icon: const Icon(Icons.attach_file, size: 18),
                        label: const Text('Add Attachment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (lostAttachmentPath.value != null)
                        const Expanded(
                          child: Text('Attachment added',
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Remarks
                TextFormField(
                  controller: remarksCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: status.value == 'Lost'
                        ? 'Remarks *'
                        : 'Remarks / Call Context',
                    prefixIcon: const Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isSaving.value ? null : saveOutcome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: status.value == 'Lost'
                            ? const Color(0xFFB91C1C)
                            : crm.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: isSaving.value
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(status.value == 'Lost'
                              ? (canReview ? 'Mark Lost' : 'Request Lost Approval')
                              : 'Save Outcome'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled row inside the pending-lost-approval summary panel.
Widget _pendingLostRow(String label, String value) {
  final text = value.trim().isEmpty ? '—' : value.trim();
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF92400E),
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────
//  Lead Stats Dashboard Card
// ─────────────────────────────────────────────────────────
class _LeadStatsRow extends StatelessWidget {
  final Map<String, int> stats;
  /// Currently applied status filter, so the matching card reads as selected.
  final String activeStatus;
  /// Tapping a card filters the list to that status ('All' clears it).
  final ValueChanged<String>? onSelect;

  const _LeadStatsRow({
    required this.stats,
    this.activeStatus = 'All',
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final newCount = stats['New'] ?? 0;
    final followUpCount = stats['Follow-up'] ?? 0;
    final closedCount = stats['Closed'] ?? 0;
    final missedCount = stats['Missed'] ?? 0;

    Widget buildStatCard(String title, int count, IconData icon, Color color,
        {String? filterValue}) {
      final selected = filterValue != null && filterValue == activeStatus;
      final card = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.07) : crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : crm.border,
              width: selected ? 1.6 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count.toString(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.close, size: 15, color: color),
          ],
        ),
      );

      if (filterValue == null || onSelect == null) return card;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        // Tapping the active card clears the filter.
        onTap: () => onSelect!(selected ? 'All' : filterValue),
        child: card,
      );
    }

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: buildStatCard('New Leads', newCount,
                      Icons.star_border, Colors.blue,
                      filterValue: 'New')),
              const SizedBox(width: 10),
              Expanded(
                  child: buildStatCard('Follow-up', followUpCount, Icons.sync,
                      Colors.orange,
                      filterValue: 'Follow-up')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: buildStatCard('Closed', closedCount,
                      Icons.check_circle_outline, Colors.green,
                      filterValue: 'Converted')),
              const SizedBox(width: 10),
              Expanded(
                  child: buildStatCard('Missed', missedCount,
                      Icons.warning_amber_rounded, Colors.red)),
            ],
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 36) / 4;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
                width: itemWidth,
                child: buildStatCard('New Leads', newCount,
                    Icons.star_border, Colors.blue,
                    filterValue: 'New')),
            SizedBox(
                width: itemWidth,
                child: buildStatCard(
                    'Follow-up', followUpCount, Icons.sync, Colors.orange,
                    filterValue: 'Follow-up')),
            SizedBox(
                width: itemWidth,
                child: buildStatCard('Closed Leads', closedCount,
                    Icons.check_circle_outline, Colors.green,
                    filterValue: 'Converted')),
            SizedBox(
                width: itemWidth,
                child: buildStatCard('Missed Leads', missedCount,
                    Icons.warning_amber_rounded, Colors.red)),
          ],
        );
      },
    );
  }
}

