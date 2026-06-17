import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/models/booking.dart';
import '../../core/utils/booking_print_service.dart';
import '../../services/addon_service_service.dart';
import '../../core/models/addon_service.dart';
import '../../services/district_service.dart';
import '../../core/models/district.dart';

// Opens a Google Maps URL in the default browser/maps app.
Future<void> _openMapUrl(String url, BuildContext context) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Google Maps link.')),
    );
  }
}

// Opens a phone call in the default phone app.
Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
  final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
  final uri = Uri.tryParse('tel:$cleanPhone');
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not launch phone call for $phoneNumber.')),
    );
  }
}

// Opens a WhatsApp chat.
Future<void> _openWhatsApp(String phoneNumber, BuildContext context) async {
  var cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
  if (cleanPhone.startsWith('0')) {
    cleanPhone = cleanPhone.substring(1);
  }
  if (cleanPhone.length == 10) {
    cleanPhone = '91$cleanPhone';
  }
  final uri = Uri.tryParse('https://wa.me/$cleanPhone');
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not launch WhatsApp for $phoneNumber.')),
    );
  }
}

// Shows a selection sheet for opening WhatsApp for primary or alternative number.
void _showWhatsAppSelectionBottomSheet(BuildContext context, Booking booking, String primary, String secondary) {
  final crm = context.crmColors;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Number for WhatsApp',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: crm.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.customerName,
                      style: TextStyle(
                        fontSize: 13,
                        color: crm.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _PhoneOptionTile(
              number: primary,
              label: 'Primary Number',
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.pop(context);
                _openWhatsApp(primary, context);
              },
            ),
            const SizedBox(height: 12),
            _PhoneOptionTile(
              number: secondary,
              label: 'Alternative Number',
              icon: Icons.chat_bubble_outline_rounded,
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.pop(context);
                _openWhatsApp(secondary, context);
              },
            ),
          ],
        ),
      );
    },
  );
}

// Shows a selection sheet for calling primary or alternative number.
void _showCallSelectionBottomSheet(BuildContext context, Booking booking, String primary, String secondary) {
  final crm = context.crmColors;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Number to Call',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: crm.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.customerName,
                      style: TextStyle(
                        fontSize: 13,
                        color: crm.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _PhoneOptionTile(
              number: primary,
              label: 'Primary Number',
              icon: Icons.phone_rounded,
              color: crm.primary,
              onTap: () {
                Navigator.pop(context);
                _makePhoneCall(primary, context);
              },
            ),
            const SizedBox(height: 12),
            _PhoneOptionTile(
              number: secondary,
              label: 'Alternative Number',
              icon: Icons.phone_android_rounded,
              color: const Color(0xFF22C55E),
              onTap: () {
                Navigator.pop(context);
                _makePhoneCall(secondary, context);
              },
            ),
          ],
        ),
      );
    },
  );
}

class _PhoneOptionTile extends StatelessWidget {
  final String number;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PhoneOptionTile({
    required this.number,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: crm.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: crm.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    number,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: crm.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Colour helpers
// ─────────────────────────────────────────────────────────────────────────────


Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return const Color(0xFF3B82F6);
    case 'completed':
      return const Color(0xFF22C55E);
    case 'pending':
      return const Color(0xFFF97316);
    case 'cancelled':
      return const Color(0xFFEF4444);
    case 'postponed':
      return const Color(0xFFF97316); // Orange
    default:
      return const Color(0xFF8B5CF6);
  }
}

IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return Icons.check_circle_rounded;
    case 'completed':
      return Icons.task_alt_rounded;
    case 'pending':
      return Icons.hourglass_top_rounded;
    case 'cancelled':
      return Icons.cancel_rounded;
    case 'postponed':
      return Icons.schedule_rounded;
    default:
      return Icons.info_rounded;
  }
}

String _fmt(DateTime d) {
  const months = [
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
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

String _fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ap';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────────────────────────────────────
BookingPageSummary _computeSummary(List<Booking> list) {
  double totalSales = 0;
  double totalAdvance = 0;
  int completed = 0;
  int cancelled = 0;
  for (final b in list) {
    totalSales += b.totalPrice;
    totalAdvance += b.advanceAmount;
    if (b.status.toLowerCase() == 'completed') completed++;
    if (b.status.toLowerCase() == 'cancelled') cancelled++;
  }
  return BookingPageSummary(
    totalSales: totalSales,
    totalAdvance: totalAdvance,
    completedCount: completed,
    cancelledCount: cancelled,
  );
}

void openFilterBottomSheet(
  BuildContext context,
  WidgetRef ref,
  List<District> districts,
  ValueNotifier<DateTime?> filterFromDate,
  ValueNotifier<DateTime?> filterToDate,
  ValueNotifier<String?> selectedDistrictId,
  ValueNotifier<bool> onlyWithMapLink,
  ValueNotifier<String> searchQuery,
) {
  final theme = Theme.of(context);
  final crm = context.crmColors;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        var tempFromDate = filterFromDate.value;
        var tempToDate = filterToDate.value;
        var tempDistrictId = selectedDistrictId.value;
        var tempMapLink = onlyWithMapLink.value;
        final searchCtrl = TextEditingController(text: searchQuery.value);

        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    24.h,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Works',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: crm.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    16.h,
                    Text(
                      'SEARCH LOCATION / CLIENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: crm.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    8.h,
                    TextFormField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        labelText: 'Search keyword',
                        hintText: 'e.g. client name, address, etc.',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: TextStyle(fontSize: 13, color: crm.textPrimary),
                    ),
                    16.h,
                    Text(
                      'DISTRICT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: crm.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    8.h,
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select District',
                        prefixIcon: const Icon(Icons.map_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      value: tempDistrictId,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Districts'),
                        ),
                        ...districts.map(
                          (d) => DropdownMenuItem<String>(
                            value: d.id,
                            child: Text(d.name),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => tempDistrictId = val);
                      },
                    ),
                    16.h,
                    Text(
                      'DATE RANGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: crm.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    8.h,
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: tempFromDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => tempFromDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'From Date',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                tempFromDate != null ? _fmt(tempFromDate!) : 'Select',
                                style: TextStyle(fontSize: 12, color: crm.textPrimary),
                              ),
                            ),
                          ),
                        ),
                        12.w,
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: tempToDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => tempToDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'To Date',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                tempToDate != null ? _fmt(tempToDate!) : 'Select',
                                style: TextStyle(fontSize: 12, color: crm.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    16.h,
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Only with Google Map link', style: TextStyle(fontSize: 13, color: crm.textPrimary)),
                      value: tempMapLink,
                      activeColor: crm.primary,
                      onChanged: (val) {
                        setState(() => tempMapLink = val);
                      },
                    ),
                    24.h,
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              filterFromDate.value = null;
                              filterToDate.value = null;
                              selectedDistrictId.value = null;
                              onlyWithMapLink.value = false;
                              searchQuery.value = '';
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✓ Filters Reset')),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('RESET'),
                          ),
                        ),
                        12.w,
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              filterFromDate.value = tempFromDate;
                              filterToDate.value = tempToDate;
                              selectedDistrictId.value = tempDistrictId;
                              onlyWithMapLink.value = tempMapLink;
                              searchQuery.value = searchCtrl.text.trim();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✓ Filters Applied')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: crm.primary,
                            ),
                            child: const Text('APPLY FILTERS'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class ArtistWorksScreen extends HookConsumerWidget {
  const ArtistWorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final employeeId = session?.employeeId ?? '';

    final asyncBookings = ref.watch(bookingProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final districts = asyncDistricts.value ?? [];

    final tabController = useTabController(initialLength: 2);

    final filterFromDate = useState<DateTime?>(null);
    final filterToDate = useState<DateTime?>(null);
    final selectedDistrictId = useState<String?>(null);
    final onlyWithMapLink = useState<bool>(false);
    final searchQuery = useState<String>('');
    final selectedMonth = useState<DateTime>(DateTime(DateTime.now().year, DateTime.now().month, 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Works', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: context.crmColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: (filterFromDate.value != null ||
                      filterToDate.value != null ||
                      selectedDistrictId.value != null ||
                      onlyWithMapLink.value ||
                      searchQuery.value.isNotEmpty)
                  ? context.crmColors.primary
                  : context.crmColors.textSecondary,
            ),
            onPressed: () => openFilterBottomSheet(
              context,
              ref,
              districts,
              filterFromDate,
              filterToDate,
              selectedDistrictId,
              onlyWithMapLink,
              searchQuery,
            ),
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          labelColor: context.crmColors.primary,
          unselectedLabelColor: context.crmColors.textSecondary,
          indicatorColor: context.crmColors.primary,
          tabs: const [
            Tab(text: 'UPCOMING WORKS'),
            Tab(text: 'COMPLETED WORKS'),
          ],
        ),
      ),
      backgroundColor: context.crmColors.background,
      body: SelectionArea(
        child: Column(
          children: [
            _buildMonthSelectorHeader(context, selectedMonth),
            Expanded(
              child: asyncBookings.when(
                loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(
            error: error.toString(),
            onRetry: () => ref.invalidate(bookingProvider),
          ),
          data: (bookings) {
            final filtered = bookings.where((b) {
              final isAssigned = b.assignedStaff.any((s) => s.employeeId == employeeId);
              if (!isAssigned) return false;

              final dateOnly = DateTime(b.bookingDate.year, b.bookingDate.month, b.bookingDate.day);
              if (dateOnly.year != selectedMonth.value.year || dateOnly.month != selectedMonth.value.month) return false;

              if (filterFromDate.value != null && dateOnly.isBefore(filterFromDate.value!)) return false;
              if (filterToDate.value != null && dateOnly.isAfter(dateOnly.add(const Duration(days: 0)))) return false;

              if (selectedDistrictId.value != null && b.districtId != selectedDistrictId.value) return false;

              if (onlyWithMapLink.value && b.mapUrl.trim().isEmpty) return false;

              if (searchQuery.value.isNotEmpty) {
                final query = searchQuery.value.toLowerCase();
                final match = b.customerName.toLowerCase().contains(query) ||
                    b.service.toLowerCase().contains(query) ||
                    b.address.toLowerCase().contains(query) ||
                    b.region.toLowerCase().contains(query) ||
                    b.district.toLowerCase().contains(query) ||
                    b.bookingNumber.toLowerCase().contains(query);
                if (!match) return false;
              }

              return true;
            }).toList();

            final upcomingList = filtered
                .where((b) =>
                    b.status.toLowerCase() != 'completed' &&
                    b.status.toLowerCase() != 'cancelled' &&
                    b.status.toLowerCase() != 'rejected')
                .toList()
              ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

            final completedList = filtered
                .where((b) => b.status.toLowerCase() == 'completed')
                .toList()
              ..sort((a, b) => b.serviceStart.compareTo(a.serviceStart));

            final upcomingSummary = _computeSummary(upcomingList);
            final completedSummary = _computeSummary(completedList);

            if (upcomingList.isEmpty && completedList.isEmpty && filtered.isEmpty) {
              return const _EmptyState();
            }

            return TabBarView(
              controller: tabController,
              children: [
                _BookingCardStack(
                  bookings: upcomingList,
                  summary: upcomingSummary,
                  isCompletedTab: false,
                  totalItems: upcomingList.length,
                ),
                _BookingCardStack(
                  bookings: completedList,
                  summary: completedSummary,
                  isCompletedTab: true,
                  totalItems: completedList.length,
                ),
              ],
            );
          },
        ),
      ),
    ],
  ),
      ),
    );
  }
}

class _BookingCardStack extends HookWidget {
  final List<Booking> bookings;
  final BookingPageSummary summary;
  final bool isCompletedTab;
  final int totalItems;

  const _BookingCardStack({
    required this.bookings,
    required this.summary,
    this.isCompletedTab = false,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final expandedIndex = useState<int?>(null);
    final now = DateTime.now();

    if (isCompletedTab) {
      return Column(
        children: [
          _SummaryStrip(summary: summary, total: totalItems),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (bookings.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No completed works found.'),
                    ),
                  )
                else ...[
                  _SectionLabel(
                    label: "Completed Works",
                    icon: Icons.task_alt_rounded,
                    color: const Color(0xFF22C55E),
                  ),
                  8.h,
                  ...bookings.asMap().entries.map(
                    (e) => _AnimatedWorkCard(
                      booking: e.value,
                      index: e.key,
                      isExpanded: expandedIndex.value == e.value.id.hashCode,
                      onTap: () {
                        expandedIndex.value =
                            expandedIndex.value == e.value.id.hashCode
                            ? null
                            : e.value.id.hashCode;
                      },
                      isToday: false,
                      isPast: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final todayBookings = bookings
        .where(
          (b) =>
              b.bookingDate.year == now.year &&
              b.bookingDate.month == now.month &&
              b.bookingDate.day == now.day,
        )
        .toList();

    final upcomingBookings = bookings
        .where(
          (b) =>
              b.bookingDate.isAfter(DateTime(now.year, now.month, now.day)) &&
              !(b.bookingDate.year == now.year &&
                  b.bookingDate.month == now.month &&
                  b.bookingDate.day == now.day),
        )
        .toList();

    final pastBookings = bookings
        .where(
          (b) =>
              b.bookingDate.isBefore(DateTime(now.year, now.month, now.day)),
        )
        .toList();

    return Column(
      children: [
        _SummaryStrip(summary: summary, total: totalItems),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (todayBookings.isEmpty && upcomingBookings.isEmpty && pastBookings.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No upcoming works found.'),
                  ),
                ),

              if (todayBookings.isNotEmpty) ...[
                _SectionLabel(
                  label: "Today's Work",
                  icon: Icons.wb_sunny_rounded,
                  color: Colors.orange,
                ),
                8.h,
                ...todayBookings.asMap().entries.map(
                  (e) => _AnimatedWorkCard(
                    booking: e.value,
                    index: e.key,
                    isExpanded: expandedIndex.value == e.value.id.hashCode,
                    onTap: () {
                      expandedIndex.value =
                          expandedIndex.value == e.value.id.hashCode
                          ? null
                          : e.value.id.hashCode;
                    },
                    isToday: true,
                  ),
                ),
                20.h,
              ],

              if (upcomingBookings.isNotEmpty) ...[
                _SectionLabel(
                  label: 'Upcoming',
                  icon: Icons.upcoming_rounded,
                  color: const Color(0xFF3B82F6),
                ),
                8.h,
                ...upcomingBookings.asMap().entries.map(
                  (e) => _AnimatedWorkCard(
                    booking: e.value,
                    index: e.key,
                    isExpanded: expandedIndex.value == e.value.id.hashCode,
                    onTap: () {
                      expandedIndex.value =
                          expandedIndex.value == e.value.id.hashCode
                          ? null
                          : e.value.id.hashCode;
                    },
                    isToday: false,
                  ),
                ),
                20.h,
              ],

              if (pastBookings.isNotEmpty) ...[
                _SectionLabel(
                  label: 'Past Works',
                  icon: Icons.history_rounded,
                  color: crm.textSecondary,
                ),
                8.h,
                ...pastBookings.asMap().entries.map(
                  (e) => _AnimatedWorkCard(
                    booking: e.value,
                    index: e.key,
                    isExpanded: expandedIndex.value == e.value.id.hashCode,
                    onTap: () {
                      expandedIndex.value =
                          expandedIndex.value == e.value.id.hashCode
                          ? null
                          : e.value.id.hashCode;
                    },
                    isToday: false,
                    isPast: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Summary Strip
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final BookingPageSummary summary;
  final int total;

  const _SummaryStrip({required this.summary, required this.total});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      color: crm.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _StripStat(
            label: 'Total',
            value: '$total',
            color: crm.primary,
            icon: Icons.assignment_rounded,
          ),
          const _Divider(),
          _StripStat(
            label: 'Done',
            value: '${summary.completedCount}',
            color: const Color(0xFF22C55E),
            icon: Icons.task_alt_rounded,
          ),
          const _Divider(),
          _StripStat(
            label: 'Earnings',
            value: '₹${summary.totalSales.toStringAsFixed(0)}',
            color: const Color(0xFF8B5CF6),
            icon: Icons.account_balance_wallet_rounded,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(height: 28, width: 1, color: context.crmColors.border),
  );
}

class _StripStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StripStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    flex: 3,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        6.w,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.crmColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SectionLabel({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      10.w,
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Animated Work Card  (boarding-pass / stacked style)
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedWorkCard extends ConsumerWidget {
  final Booking booking;
  final int index;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool isToday;
  final bool isPast;

  const _AnimatedWorkCard({
    required this.booking,
    required this.index,
    required this.isExpanded,
    required this.onTap,
    required this.isToday,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final statusColor = _statusColor(booking.status);
    final balance =
        (booking.totalPrice - booking.advanceAmount - booking.discountAmount)
            .clamp(0, double.infinity)
            .toDouble();

    // Get the logged in artist's employeeId to only show their assigned works
    final authSession = ref.watch(authSessionProvider);
    final employeeId = authSession?.employeeId ?? '';

    // My assigned works for this booking
    final myWorks = booking.assignedStaff
        .where((s) => (employeeId.isEmpty || s.employeeId == employeeId) && s.works.isNotEmpty)
        .expand((s) => s.works)
        .toSet()
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isPast ? crm.surface.withValues(alpha: 0.7) : crm.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: crm.border),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          children: [
            // ── Card Header ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.9),
                              statusColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          booking.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      14.w,

                      // Name + service + quick actions
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isPast
                                    ? crm.textSecondary
                                    : crm.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            4.h,
                            Text(
                              booking.service,
                              style: TextStyle(
                                fontSize: 12,
                                color: crm.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (booking.pocName.trim().isNotEmpty || booking.captureStaffDetails.trim().isNotEmpty) ...[
                              6.h,
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (booking.pocName.trim().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: crm.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: crm.primary.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.person_pin_rounded,
                                            size: 10,
                                            color: crm.primary,
                                          ),
                                          4.w,
                                          Text(
                                            'POC: ${booking.pocName}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: crm.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (booking.captureStaffDetails.trim().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.orange.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.camera_enhance_rounded,
                                            size: 10,
                                            color: Colors.orange,
                                          ),
                                          4.w,
                                          Text(
                                            'CAPTURE: ${booking.captureStaffDetails}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            if (booking.phone.trim().isNotEmpty || booking.mapUrl.isNotEmpty) ...[
                              8.h,
                              Row(
                                children: [
                                  if (booking.phone.trim().isNotEmpty) ...[
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () {
                                          final primary = booking.phone.trim();
                                          final secondary = booking.secondaryContact.trim();
                                          if (secondary.isNotEmpty) {
                                            _showCallSelectionBottomSheet(context, booking, primary, secondary);
                                          } else {
                                            _makePhoneCall(primary, context);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: crm.primary.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.call_rounded,
                                            size: 15,
                                            color: crm.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    6.w,
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () {
                                          final primary = booking.phone.trim();
                                          final secondary = booking.secondaryContact.trim();
                                          if (secondary.isNotEmpty) {
                                            _showWhatsAppSelectionBottomSheet(context, booking, primary, secondary);
                                          } else {
                                            _openWhatsApp(primary, context);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.chat_outlined,
                                            size: 15,
                                            color: Color(0xFF25D366),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (booking.mapUrl.isNotEmpty) ...[
                                    if (booking.phone.trim().isNotEmpty) 8.w,
                                    GestureDetector(
                                      onTap: () => _openMapUrl(booking.mapUrl, context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF34A853).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: const Color(0xFF34A853).withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 10,
                                              color: Color(0xFF34A853),
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              'MAP',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF34A853),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      12.w,

                      // Status + expand arrow
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusChip(status: booking.status),
                          12.h,
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: crm.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),

                  14.h,
                  // ── Date / Time Row ──────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? statusColor.withValues(alpha: 0.06)
                          : crm.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday
                            ? statusColor.withValues(alpha: 0.2)
                            : crm.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Date block
                        _IconInfo(
                          icon: Icons.calendar_today_rounded,
                          text: _fmt(booking.bookingDate),
                          color: isToday ? statusColor : crm.textSecondary,
                        ),
                        const Spacer(),
                        Container(width: 1, height: 28, color: crm.border),
                        const Spacer(),
                        // Time block
                        _IconInfo(
                          icon: Icons.access_time_rounded,
                          text:
                              '${_fmtTime(booking.serviceStart)} – ${_fmtTime(booking.serviceEnd)}',
                          color: isToday ? statusColor : crm.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded Details ─────────────────────────
            if (isExpanded)
              _ExpandedDetails(
                booking: booking,
                balance: balance,
                myWorks: myWorks,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Expanded Details (shown when card is tapped)
// ─────────────────────────────────────────────────────────────────────────────
class _ExpandedDetails extends ConsumerWidget {
  final Booking booking;
  final double balance;
  final List<String> myWorks;

  const _ExpandedDetails({
    required this.booking,
    required this.balance,
    required this.myWorks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isPostponed = booking.status.toLowerCase() == 'postponed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Dashed separator (like a boarding pass tear line) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dashCount = (constraints.constrainWidth() / 8).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  dashCount,
                  (_) => Container(width: 4, height: 1, color: crm.border),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isPostponed) WorkTimerWidget(booking: booking),
              if (isPostponed) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                      12.w,
                      Expanded(
                        child: Text(
                          'This booking has been postponed. Timer is unavailable.',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                12.h,
              ],
              12.h,
              // Contact details
              if (booking.phone.trim().isNotEmpty || booking.secondaryContact.trim().isNotEmpty) ...[
                _DetailLabel('Contact Information'),
                6.h,
                Row(
                  children: [
                    if (booking.phone.trim().isNotEmpty)
                      Expanded(
                        child: InkWell(
                          onTap: () => _makePhoneCall(booking.phone.trim(), context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: crm.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: crm.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.phone_rounded, size: 14, color: crm.primary),
                                8.w,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Primary Mobile',
                                        style: TextStyle(fontSize: 10, color: crm.textSecondary),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        booking.phone,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: crm.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _openWhatsApp(booking.phone.trim(), context),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chat_outlined,
                                      size: 14,
                                      color: Color(0xFF25D366),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (booking.phone.trim().isNotEmpty && booking.secondaryContact.trim().isNotEmpty)
                      8.w,
                    if (booking.secondaryContact.trim().isNotEmpty)
                      Expanded(
                        child: InkWell(
                          onTap: () => _makePhoneCall(booking.secondaryContact.trim(), context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: crm.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: crm.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.phone_android_rounded, size: 14, color: const Color(0xFF22C55E)),
                                8.w,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Alternative Mobile',
                                        style: TextStyle(fontSize: 10, color: crm.textSecondary),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        booking.secondaryContact,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: crm.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _openWhatsApp(booking.secondaryContact.trim(), context),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chat_outlined,
                                      size: 14,
                                      color: Color(0xFF25D366),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                14.h,
              ],
              // My assigned tasks
              if (myWorks.isNotEmpty) ...[
                _DetailLabel('My Assigned Tasks'),
                8.h,
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: myWorks.map((w) => _WorkTag(text: w)).toList(),
                ),
                16.h,
              ],

              // Location
              if (booking.region.isNotEmpty || booking.district.isNotEmpty) ...[
                _DetailLabel('Location'),
                6.h,
                _IconInfo(
                  icon: Icons.location_on_rounded,
                  text: [
                    booking.district,
                    booking.region,
                  ].where((s) => s.isNotEmpty).join(', '),
                  color: crm.textSecondary,
                  fontSize: 13,
                ),
                14.h,
              ],

              // POC & Capture Staff
              if (booking.pocName.trim().isNotEmpty || booking.captureStaffDetails.trim().isNotEmpty) ...[
                _DetailLabel('Coordination & Logistics'),
                6.h,
                Row(
                  children: [
                    if (booking.pocName.trim().isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: crm.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: crm.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_pin_rounded, size: 16, color: crm.primary),
                              8.w,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Point of Contact (POC)',
                                      style: TextStyle(fontSize: 10, color: crm.textSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      booking.pocName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: crm.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (booking.pocPhone.trim().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      InkWell(
                                        onTap: () => _makePhoneCall(booking.pocPhone.trim(), context),
                                        child: Text(
                                          booking.pocPhone,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: crm.primary,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (booking.pocName.trim().isNotEmpty && booking.captureStaffDetails.trim().isNotEmpty)
                      8.w,
                    if (booking.captureStaffDetails.trim().isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: crm.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: crm.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.camera_enhance_rounded, size: 16, color: Colors.orange),
                              8.w,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Capture Staff',
                                      style: TextStyle(fontSize: 10, color: crm.textSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      booking.captureStaffDetails,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: crm.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                14.h,
              ],

              // Travel info
              if (booking.travelMode.isNotEmpty) ...[
                _DetailLabel('Travel'),
                6.h,
                _IconInfo(
                  icon: Icons.directions_car_rounded,
                  text:
                      '${booking.travelMode}'
                      '${booking.travelTime.isNotEmpty ? ' • ${booking.travelTime}' : ''}'
                      '${booking.travelDistanceKm > 0 ? ' • ${booking.travelDistanceKm.toStringAsFixed(1)} km' : ''}',
                  color: Colors.black,
                  fontSize: 13,
                ),
                14.h,
              ],

              // Outfit details
              if (booking.outfitDetails.isNotEmpty) ...[
                _DetailLabel('Outfit Details'),
                6.h,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.checkroom_rounded,
                        size: 16,
                        color: Color(0xFF8B5CF6),
                      ),
                      8.w,
                      Expanded(
                        child: Text(
                          booking.outfitDetails,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4C1D95),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                14.h,
              ],

              if (booking.staffInstructions.isNotEmpty) ...[
                _DetailLabel('Instructions'),
                6.h,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF97316).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Color(0xFFF97316),
                      ),
                      8.w,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.staffInstructions,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF92400E),
                                height: 1.4,
                              ),
                            ),
                            ...() {
                              final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
                              final matches = urlRegExp.allMatches(booking.staffInstructions);
                              if (matches.isEmpty) return <Widget>[];
                              return <Widget>[
                                8.h,
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: matches.map((m) {
                                    final url = m.group(0)!;
                                    final isMap = url.contains('maps') || url.contains('goo.gl');
                                    return ActionChip(
                                      avatar: Icon(isMap ? Icons.location_on : Icons.link, size: 14, color: const Color(0xFFF97316)),
                                      label: Text(isMap ? 'Open Map' : 'Open Link', style: const TextStyle(fontSize: 10, color: Color(0xFF92400E))),
                                      backgroundColor: const Color(0xFFFFF7ED),
                                      side: BorderSide(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
                                      onPressed: () => _openMapUrl(url, context),
                                    );
                                  }).toList(),
                                )
                              ];
                            }(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                14.h,
              ],

              // Add-ons list
              _DetailLabel('Add-ons'),
              8.h,
              if (booking.addons.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'No add-ons added yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: crm.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Column(
                  children: booking.addons.map((addon) {
                    final itemTotal = addon.amount * addon.persons;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: crm.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: crm.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addon.service,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                2.h,
                                Text(
                                  '${addon.persons} person(s) • ₹${addon.amount.toStringAsFixed(0)} each',
                                  style: TextStyle(color: crm.textSecondary, fontSize: 11),
                                ),
                                if (addon.description.isNotEmpty) ...[
                                  2.h,
                                  Text(
                                    addon.description,
                                    style: TextStyle(color: crm.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '₹${itemTotal.toStringAsFixed(0)}',
                            style: TextStyle(fontWeight: FontWeight.w900, color: crm.primary, fontSize: 13),
                          ),
                          12.w,
                          // Edit Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showEditAddonModal(context, ref, booking, addon),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                          6.w,
                          // Delete Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _confirmDeleteAddon(context, ref, booking, addon),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: booking.status.toLowerCase() == 'cancelled'
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : booking.status.toLowerCase() == 'postponed'
                                      ? Colors.orange.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              8.h,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddAddonModal(context, ref, booking),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Add-on'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: crm.primary,
                    side: BorderSide(color: crm.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              14.h,

              // Payment breakdown
              _DetailLabel('Payment'),
              12.h,
              Row(
                children: [
                  _PayCard(
                    label: 'Total',
                    value: '₹${booking.totalPrice.toStringAsFixed(0)}',
                    color: crm.primary,
                    icon: Icons.receipt_rounded,
                  ),
                  8.w,
                  _PayCard(
                    label: 'Advance',
                    value: '₹${booking.advanceAmount.toStringAsFixed(0)}',
                    color: const Color(0xFF22C55E),
                    icon: Icons.check_circle_rounded,
                  ),
                  8.w,
                  _PayCard(
                    label: 'Balance',
                    value: '₹${balance.toStringAsFixed(0)}',
                    color: balance > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22C55E),
                    icon: balance > 0
                        ? Icons.pending_rounded
                        : Icons.done_all_rounded,
                  ),
                ],
              ),

              // PDF client details download option
              14.h,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await printBookingDetails(
                        booking,
                        variant: BookingPrintVariant.client,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error downloading PDF: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Download Client Details (PDF)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crm.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // Google Maps link
              if (booking.mapUrl.isNotEmpty) ...[
                14.h,
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMapUrl(booking.mapUrl, context),
                    icon: const Icon(Icons.location_on_rounded, size: 16),
                    label: const Text('Open in Google Maps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF34A853),
                      side: const BorderSide(color: Color(0xFF34A853)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showAddAddonModal(BuildContext context, WidgetRef ref, Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddAddonSheet(booking: booking),
    );
  }

  void _showEditAddonModal(BuildContext context, WidgetRef ref, Booking booking, BookingAddon addon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddAddonSheet(booking: booking, existingAddon: addon),
    );
  }

  Future<void> _confirmDeleteAddon(BuildContext context, WidgetRef ref, Booking booking, BookingAddon addon) async {
    final crm = context.crmColors;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Add-on'),
        content: Text('Are you sure you want to delete "${addon.service}" from this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final updatedAddons = booking.addons.where((a) => a != addon).toList();
      final newTotalPrice = booking.totalPrice - (addon.amount * addon.persons);

      final updatedBooking = booking.copyWith(
        addons: updatedAddons,
        totalPrice: newTotalPrice,
      );

      await ref.read(bookingProvider.notifier).updateBooking(updatedBooking);

      // Invalidate the cache to reload
      ref.invalidate(paginatedBookingsProvider);
      ref.invalidate(artistAssignedWorksProvider);
      ref.invalidate(bookingProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully removed "${addon.service}" from the booking.'),
            backgroundColor: crm.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete add-on: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _AddAddonSheet extends ConsumerStatefulWidget {
  final Booking booking;
  final BookingAddon? existingAddon;
  const _AddAddonSheet({required this.booking, this.existingAddon});

  @override
  ConsumerState<_AddAddonSheet> createState() => _AddAddonSheetState();
}

class _AddAddonSheetState extends ConsumerState<_AddAddonSheet> {
  AddonService? _selectedService;
  int _persons = 1;
  String _description = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingAddon != null) {
      _persons = widget.existingAddon!.persons;
      _description = widget.existingAddon!.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final theme = Theme.of(context);
    final asyncAddons = ref.watch(addonServicesProvider);
    final isEditing = widget.existingAddon != null;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'Edit Service Add-on' : 'Add Service Add-on',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: crm.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          16.h,
          asyncAddons.when(
            data: (services) {
              final activeServices = services.where((s) => s.status.toLowerCase() == 'active' && s.status.toLowerCase() != 'postponed').toList();
              if (activeServices.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('No active add-on services available.'),
                );
              }

              // Set default selected if not set
              if (_selectedService == null) {
                if (isEditing) {
                  _selectedService = activeServices.firstWhere(
                    (s) => s.id == widget.existingAddon!.addonServiceId || s.name == widget.existingAddon!.service,
                    orElse: () => activeServices.first,
                  );
                } else {
                  _selectedService = activeServices.first;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<AddonService>(
                    value: _selectedService,
                    decoration: InputDecoration(
                      labelText: 'Select Service',
                      labelStyle: TextStyle(color: crm.textSecondary),
                      fillColor: crm.background,
                    ),
                    items: activeServices.map((service) {
                      return DropdownMenuItem<AddonService>(
                        value: service,
                        child: Text('${service.name} (₹${service.price.toStringAsFixed(0)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedService = val;
                        if (val != null && _description.trim().isEmpty) {
                          _description = val.description;
                        }
                      });
                    },
                  ),
                  16.h,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Number of Persons',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: crm.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                            color: crm.primary,
                            onPressed: _persons > 1
                                ? () => setState(() => _persons--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '$_persons',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            color: crm.primary,
                            onPressed: () => setState(() => _persons++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  16.h,
                  Text(
                    'Description / Notes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: crm.textSecondary,
                    ),
                  ),
                  4.h,
                  TextFormField(
                    initialValue: _description,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g., Saree draping for sister',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (val) => setState(() => _description = val),
                  ),
                  20.h,
                  const Divider(),
                  12.h,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Add-on Cost:',
                        style: TextStyle(color: crm.textSecondary, fontSize: 13),
                      ),
                      Text(
                        '₹${((_selectedService?.price ?? 0) * _persons).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: crm.primary,
                        ),
                      ),
                    ],
                  ),
                  20.h,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _confirmAddon(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crm.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              isEditing ? 'Confirm & Update Booking' : 'Confirm & Add to Booking',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text('Error loading services: $err'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAddon(BuildContext context) async {
    if (_selectedService == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final isEditing = widget.existingAddon != null;
      final newAddon = BookingAddon(
        addonServiceId: _selectedService!.id,
        service: _selectedService!.name,
        amount: _selectedService!.price,
        persons: _persons,
        description: _description,
      );

      final currentBooking = widget.booking;
      List<BookingAddon> updatedAddons;
      double newTotalPrice;

      if (isEditing) {
        // Find the index of the existing addon and replace it
        final index = currentBooking.addons.indexOf(widget.existingAddon!);
        updatedAddons = [...currentBooking.addons];
        if (index != -1) {
          updatedAddons[index] = newAddon;
        } else {
          updatedAddons.add(newAddon);
        }
        
        // Recalculate price: subtract old addon price, add new addon price
        final oldAddonTotal = widget.existingAddon!.amount * widget.existingAddon!.persons;
        final newAddonTotal = newAddon.amount * newAddon.persons;
        newTotalPrice = currentBooking.totalPrice - oldAddonTotal + newAddonTotal;
      } else {
        updatedAddons = [...currentBooking.addons, newAddon];
        newTotalPrice = currentBooking.totalPrice + (newAddon.amount * newAddon.persons);
      }

      final updatedBooking = currentBooking.copyWith(
        addons: updatedAddons,
        totalPrice: newTotalPrice,
      );

      await ref.read(bookingProvider.notifier).updateBooking(updatedBooking);

      // Invalidate the cache to reload
      ref.invalidate(paginatedBookingsProvider);
      ref.invalidate(artistAssignedWorksProvider);
      ref.invalidate(bookingProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing 
                  ? 'Successfully updated "${_selectedService!.name}" x$_persons in the booking.'
                  : 'Successfully added "${_selectedService!.name}" x$_persons to the booking.'
            ),
            backgroundColor: context.crmColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingAddon != null
                  ? 'Failed to update add-on: $e'
                  : 'Failed to add add-on: $e'
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 11, color: color),
          4.w,
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final double fontSize;

  const _IconInfo({
    required this.icon,
    required this.text,
    required this.color,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
    overflow: TextOverflow.ellipsis,
  );
}

class _DetailLabel extends StatelessWidget {
  final String text;
  const _DetailLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: context.crmColors.textSecondary,
      letterSpacing: 0.8,
    ),
  );
}

class _WorkTag extends StatelessWidget {
  final String text;
  const _WorkTag({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8B5CF6),
      ),
    ),
  );
}

class _PayCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _PayCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            6.h,
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            3.h,
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: crm.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enabled ? crm.primary.withValues(alpha: 0.1) : crm.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? crm.primary.withValues(alpha: 0.3) : crm.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? crm.primary : crm.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration_rounded,
                size: 48,
                color: crm.primary.withValues(alpha: 0.5),
              ),
            ),
            24.h,
            Text(
              'All Clear! 🎉',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: crm.textPrimary,
              ),
            ),
            12.h,
            Text(
              'You have no assigned works right now.\nEnjoy your free time!',
              style: TextStyle(
                color: crm.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Error State
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: crm.destructive.withValues(alpha: 0.6),
            ),
            20.h,
            Text(
              'Could not load works',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            10.h,
            Text(
              error,
              style: TextStyle(color: crm.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            20.h,
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Work Timer Widget
// ─────────────────────────────────────────────────────────────────────────────
class WorkTimerWidget extends ConsumerStatefulWidget {
  final Booking booking;

  const WorkTimerWidget({
    super.key,
    required this.booking,
  });

  @override
  ConsumerState<WorkTimerWidget> createState() => _WorkTimerWidgetState();
}

class _WorkTimerWidgetState extends ConsumerState<WorkTimerWidget> {
  static const int _threeHoursSeconds = 3 * 3600; // 10800 seconds
  
  String get _stateKey => 'work_timer_state_${widget.booking.id}';
  String get _dataKey => 'work_timer_data_${widget.booking.id}';

  String _timerState = 'idle'; // 'idle', 'running', 'paused', 'completed'
  int _remainingSeconds = _threeHoursSeconds;
  DateTime? _startTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_stateKey) ?? 'idle';
    
    // If the booking is already completed in backend, make sure we reflect that
    if (widget.booking.status.toLowerCase() == 'completed') {
      if (mounted) {
        setState(() {
          _timerState = 'completed';
        });
      }
      return;
    }

    if (savedState == 'running') {
      final savedStartStr = prefs.getString(_dataKey);
      if (savedStartStr != null) {
        final savedStart = DateTime.tryParse(savedStartStr);
        if (savedStart != null) {
          final elapsed = DateTime.now().difference(savedStart).inSeconds;
          final remaining = _threeHoursSeconds - elapsed;
          if (remaining > 0) {
            _timerState = 'running';
            _startTime = savedStart;
            _remainingSeconds = remaining;
            _startTicker();
          } else {
            // Timer expired while app was closed/minimized
            _timerState = 'running';
            _startTime = savedStart;
            _remainingSeconds = 0;
            _startTicker();
          }
        }
      }
    } else if (savedState == 'paused') {
      final savedRemaining = prefs.getInt(_dataKey) ?? _threeHoursSeconds;
      _timerState = 'paused';
      _remainingSeconds = savedRemaining;
    } else if (savedState == 'completed') {
      _timerState = 'completed';
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime == null) return;
      final elapsed = DateTime.now().difference(_startTime!).inSeconds;
      final remaining = _threeHoursSeconds - elapsed;
      if (remaining <= 0) {
        if (mounted) {
          setState(() {
            _remainingSeconds = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _remainingSeconds = remaining;
          });
        }
      }
    });
  }

  Future<void> _startTimer() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, 'running');
    await prefs.setString(_dataKey, now.toIso8601String());

    if (mounted) {
      setState(() {
        _timerState = 'running';
        _startTime = now;
        _remainingSeconds = _threeHoursSeconds;
      });
      _startTicker();
    }
  }

  Future<void> _pauseTimer() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, 'paused');
    await prefs.setInt(_dataKey, _remainingSeconds);

    if (mounted) {
      setState(() {
        _timerState = 'paused';
      });
    }
  }

  Future<void> _resumeTimer() async {
    final elapsed = _threeHoursSeconds - _remainingSeconds;
    final effectiveStart = DateTime.now().subtract(Duration(seconds: elapsed));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, 'running');
    await prefs.setString(_dataKey, effectiveStart.toIso8601String());

    if (mounted) {
      setState(() {
        _timerState = 'running';
        _startTime = effectiveStart;
      });
      _startTicker();
    }
  }

  Future<void> _completeTimer() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, 'completed');

    if (mounted) {
      setState(() {
        _timerState = 'completed';
      });
    }

    try {
      await ref.read(bookingProvider.notifier).updateBooking(
        widget.booking.copyWith(status: 'completed'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Work Marked as Completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    
    if (widget.booking.status.toLowerCase() == 'cancelled' || widget.booking.status.toLowerCase() == 'postponed') {
      return const SizedBox.shrink();
    }

    if (_timerState == 'idle') {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: crm.primary, size: 20),
                8.w,
                Expanded(
                  child: Text(
                    'Standard duration: 3 Hours',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: crm.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            12.h,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startTimer,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('START WORK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_timerState == 'completed' || widget.booking.status.toLowerCase() == 'completed') {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.task_alt_rounded, color: Colors.green, size: 22),
            10.w,
            const Text(
              'Work Completed Successfully',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    final progress = (_threeHoursSeconds - _remainingSeconds) / _threeHoursSeconds;
    final isRunning = _timerState == 'running';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRunning 
            ? crm.primary.withValues(alpha: 0.05)
            : Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning 
              ? crm.primary.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _PulsingDot(color: isRunning ? Colors.green : Colors.orange),
                  8.w,
                  Text(
                    isRunning ? 'WORK IN PROGRESS' : 'WORK PAUSED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isRunning ? Colors.green : Colors.orange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                _remainingSeconds > 0 ? 'Remaining' : 'Time Over limit',
                style: TextStyle(
                  fontSize: 11,
                  color: crm.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          10.h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatDuration(_remainingSeconds),
                style: TextStyle(
                  fontSize: 26,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  color: isRunning ? crm.textPrimary : Colors.orange,
                ),
              ),
              Text(
                'Goal: 03:00:00',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: crm.textSecondary,
                ),
              ),
            ],
          ),
          12.h,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: crm.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                _remainingSeconds > 0 
                    ? (isRunning ? crm.primary : Colors.orange) 
                    : Colors.red,
              ),
            ),
          ),
          16.h,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRunning ? _pauseTimer : _resumeTimer,
                  icon: Icon(
                    isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 16,
                  ),
                  label: Text(isRunning ? 'PAUSE' : 'RESUME'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isRunning ? Colors.orange : Colors.green,
                    side: BorderSide(
                      color: isRunning ? Colors.orange : Colors.green,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              12.w,
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _completeTimer,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('FINISH WORK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulsing Dot Component
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingDot extends HookWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1000),
    );

    useEffect(() {
      controller.repeat(reverse: true);
      return null;
    }, []);

    final animation = useAnimation(
      ColorTween(
        begin: color.withValues(alpha: 0.3),
        end: color,
      ).animate(controller),
    );

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: animation,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Month Selection Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildMonthSelectorHeader(
  BuildContext context,
  ValueNotifier<DateTime> selectedMonth,
) {
  final theme = Theme.of(context);
  final crmColors = context.crmColors;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: crmColors.surface,
      border: Border(
        bottom: BorderSide(color: crmColors.border),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () {
            selectedMonth.value = DateTime(
              selectedMonth.value.year,
              selectedMonth.value.month - 1,
              1,
            );
          },
          icon: const Icon(Icons.chevron_left_rounded),
          color: crmColors.textPrimary,
        ),
        Expanded(
          child: Center(
            child: InkWell(
              onTap: () => _openMonthPickerDialog(context, selectedMonth),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: crmColors.primary,
                    ),
                    6.w,
                    Text(
                      _getMonthYearLabel(selectedMonth.value),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: crmColors.textPrimary,
                      ),
                    ),
                    2.w,
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: crmColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            selectedMonth.value = DateTime(
              selectedMonth.value.year,
              selectedMonth.value.month + 1,
              1,
            );
          },
          icon: const Icon(Icons.chevron_right_rounded),
          color: crmColors.textPrimary,
        ),
        12.w,
        OutlinedButton(
          onPressed: () {
            selectedMonth.value = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              1,
            );
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Today', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}

String _getMonthYearLabel(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

Future<void> _openMonthPickerDialog(
  BuildContext context,
  ValueNotifier<DateTime> selectedMonth,
) async {
  final theme = Theme.of(context);
  final crmColors = context.crmColors;

  final pickedMonth = await showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      var selectedYear = selectedMonth.value.year;
      const monthLabels = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];

      return StatefulBuilder(
        builder: (context, dialogSetState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jump To Month',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    16.h,
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              dialogSetState(() => selectedYear -= 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$selectedYear',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              dialogSetState(() => selectedYear += 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    16.h,
                    GridView.builder(
                      shrinkWrap: true,
                      itemCount: monthLabels.length,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.2,
                      ),
                      itemBuilder: (context, index) {
                        final monthNumber = index + 1;
                        final isActive =
                            selectedYear == selectedMonth.value.year &&
                            monthNumber == selectedMonth.value.month;
                        return InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(
                            DateTime(selectedYear, monthNumber, 1),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? crmColors.primary
                                  : crmColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: crmColors.border),
                            ),
                            child: Text(
                              monthLabels[index],
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : crmColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (pickedMonth != null) {
    selectedMonth.value = pickedMonth;
  }
}
