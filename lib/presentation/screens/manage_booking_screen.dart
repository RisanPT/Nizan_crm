import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class ManageBookingScreen extends HookConsumerWidget {
  final String bookingId;

  const ManageBookingScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isTablet = ResponsiveBuilder.isTablet(context);

    // Look up the booking from the provider by id
    final allBookings = ref.watch(bookingProvider);
    final Booking? booking = allBookings.cast<Booking?>().firstWhere(
      (b) => b?.id == bookingId,
      orElse: () => null,
    );

    // ── Editable state (pre-filled from booking, editable by user) ──────────
    final statusState = useState(booking?.id != null ? 'confirmed' : 'pending');
    final checklistCompleted = useState(false);
    final contentRequired = useState(false);
    final assignments = useState<List<Map<String, dynamic>>>([]);

    // Controllers pre-filled from real booking data
    final nameCtrl = useTextEditingController(text: booking?.customerName ?? '');
    final phoneCtrl = useTextEditingController(text: booking?.phone ?? '');
    final emailCtrl = useTextEditingController(text: booking?.email ?? '');
    final bookingDateCtrl = useTextEditingController(
      text: booking?.bookingDate.toString().split(' ')[0] ?? '',
    );
    final startTimeCtrl = useTextEditingController(
      text: booking != null ? _fmt(booking.serviceStart) : '',
    );
    final endTimeCtrl = useTextEditingController(
      text: booking != null ? _fmt(booking.serviceEnd) : '',
    );
    final totalAmountCtrl = useTextEditingController(
      text: booking?.totalPrice.toStringAsFixed(0) ?? '',
    );
    final advanceCtrl = useTextEditingController(
      text: booking?.advanceAmount.toStringAsFixed(0) ?? '',
    );
    final balanceCtrl = useTextEditingController(
      text: booking != null
          ? (booking.totalPrice - booking.advanceAmount).toStringAsFixed(0)
          : '',
    );
    final packageCtrl = useTextEditingController(text: booking?.service ?? '');
    final regionCtrl = useTextEditingController(text: booking?.region ?? '');

    // CRM-only fields (empty until filled by user)
    final mapUrlCtrl = useTextEditingController();
    final travelModeCtrl = useTextEditingController();
    final driverCtrl = useTextEditingController();
    final travelTimeCtrl = useTextEditingController();
    final pocCtrl = useTextEditingController();
    final roomCtrl = useTextEditingController();
    final secondaryPhoneCtrl = useTextEditingController();
    final outfitCtrl = useTextEditingController();
    final captureStaffCtrl = useTextEditingController();
    final addonCtrl = useTextEditingController();
    final staffNeedsCtrl = useTextEditingController();
    final remarksCtrl = useTextEditingController();

    final availableArtists = useMemoized(() => [
      {'id': '1', 'name': 'Aditi', 'type': 'Senior'},
      {'id': '2', 'name': 'Sneha', 'type': 'Junior'},
      {'id': '3', 'name': 'Priya', 'type': 'Senior'},
    ]);

    if (booking == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: crmColors.border),
            24.h,
            Text('Booking #$bookingId not found',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: crmColors.textSecondary)),
            16.h,
            ElevatedButton.icon(
              onPressed: () => context.go('/calendar'),
              icon: const Icon(Icons.calendar_today),
              label: const Text('Back to Calendar'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back)),
                  8.w,
                  Text(
                    'Manage Booking #$bookingId',
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (!isMobile)
                TextButton.icon(
                  onPressed: () => context.go('/calendar'),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to Calendar'),
                  style: TextButton.styleFrom(
                      foregroundColor: crmColors.textSecondary),
                ),
            ],
          ),
          24.h,

          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Core details ──────────────────────────────────────────
                _SectionCard(
                  title: 'Core Booking Management',
                  subtitle: 'Status, Customer & Financials',
                  titleColor: Colors.amber,
                  action: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('SHARE WITH ARTIST'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  child: Column(
                    children: [
                      LayoutBuilder(builder: (ctx, constraints) {
                        final narrow = constraints.maxWidth < 600;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: narrow ? 1 : 5,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: narrow ? 5 : 2.5,
                          children: [
                            _buildDropdown(
                              context,
                              'STATUS',
                              ['pending', 'confirmed', 'completed', 'cancelled'],
                              statusState.value,
                              (v) => statusState.value = v ?? statusState.value,
                            ),
                            _buildField(context, 'CUSTOMER NAME', nameCtrl),
                            _buildField(context, 'CONTACT NUMBER', phoneCtrl,
                                keyboardType: TextInputType.phone),
                            _buildField(context, 'EMAIL', emailCtrl,
                                keyboardType: TextInputType.emailAddress),
                            _buildField(context, 'BOOKING DATE', bookingDateCtrl),
                          ],
                        );
                      }),
                      24.h,
                      const Divider(),
                      24.h,
                      LayoutBuilder(builder: (ctx, constraints) {
                        final narrow = constraints.maxWidth < 600;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: narrow ? 1 : 4,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: narrow ? 5 : 2.5,
                          children: [
                            _buildInfoField(context, 'PACKAGE', packageCtrl.text),
                            _buildCurrencyField(context, 'TOTAL AMOUNT',
                                totalAmountCtrl, crmColors),
                            _buildCurrencyField(context, 'ADVANCE PAID',
                                advanceCtrl, crmColors,
                                textColor: Colors.green),
                            _buildCurrencyField(context, 'FORECAST BALANCE',
                                balanceCtrl, crmColors,
                                textColor: Colors.amber),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                24.h,

                // ── Logistics + Scheduled Dates ──────────────────────────
                if (isMobile) ...[
                  _buildLogistics(context, crmColors, regionCtrl, mapUrlCtrl,
                      travelModeCtrl, driverCtrl, travelTimeCtrl, pocCtrl,
                      roomCtrl, startTimeCtrl, endTimeCtrl),
                  24.h,
                  _buildScheduledDates(context, crmColors, booking,
                      secondaryPhoneCtrl),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildLogistics(
                            context, crmColors, regionCtrl, mapUrlCtrl,
                            travelModeCtrl, driverCtrl, travelTimeCtrl, pocCtrl,
                            roomCtrl, startTimeCtrl, endTimeCtrl),
                      ),
                      24.w,
                      Expanded(
                        flex: 1,
                        child: _buildScheduledDates(context, crmColors, booking,
                            secondaryPhoneCtrl),
                      ),
                    ],
                  ),
                ],
                24.h,

                // ── Artist Assignment ─────────────────────────────────────
                _buildArtistAssignment(
                    context, crmColors, isTablet || isMobile,
                    assignments, availableArtists),
                24.h,

                // ── Service Specifics ─────────────────────────────────────
                _SectionCard(
                  title: 'Service Specifics & Media',
                  child: Column(
                    children: [
                      Flex(
                        direction: isMobile ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: isMobile ? 0 : 1,
                            child: Column(
                              children: [
                                _buildField(context, 'OUTFIT DETAILS', outfitCtrl),
                                16.h,
                                _buildField(context, 'CAPTURE STAFF (PHOTO/VIDEO)',
                                    captureStaffCtrl),
                                16.h,
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: crmColors.surface,
                                    border: Border.all(color: crmColors.border),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: contentRequired.value,
                                        onChanged: (v) =>
                                            contentRequired.value = v!,
                                        activeColor: Colors.amber,
                                      ),
                                      Flexible(
                                        child: Text(
                                          'CONTENT CREATION REQUIRED (SOCIAL MEDIA)',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: crmColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMobile) 16.h else 32.w,
                          Expanded(
                            flex: isMobile ? 0 : 1,
                            child: Column(
                              children: [
                                _buildTextArea(context, 'PACKAGE / ADD-ON DETAILS',
                                    addonCtrl),
                                16.h,
                                _buildTextArea(context,
                                    'STAFF INSTRUCTIONS / NEEDS', staffNeedsCtrl),
                              ],
                            ),
                          ),
                        ],
                      ),
                      24.h,
                      const Divider(),
                      24.h,
                      _buildTextArea(context, 'CRM INTERNAL REMARKS', remarksCtrl,
                          hint: 'Any private notes...'),
                    ],
                  ),
                ),
                24.h,

                // ── Completion Action ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: crmColors.surface,
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Transform.scale(
                            scale: 1.5,
                            child: Checkbox(
                              value: checklistCompleted.value,
                              onChanged: (v) =>
                                  checklistCompleted.value = v!,
                              activeColor: Colors.green,
                            ),
                          ),
                          16.w,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MARK CHECKLIST COMPLETE',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2)),
                              Text(
                                'Verifies all logistics and staffing for export',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: crmColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1),
                              ),
                            ],
                          )
                        ],
                      ),
                      if (isMobile) 24.h,
                      SizedBox(
                        width: isMobile ? double.infinity : 250,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Changes Saved!')));
                            context.pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding:
                                const EdgeInsets.symmetric(vertical: 24),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('SAVE CHANGES',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                        ),
                      ),
                    ],
                  ),
                ),
                48.h,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Logistics section ────────────────────────────────────────────────────
  Widget _buildLogistics(
    BuildContext context,
    CrmTheme crmColors,
    TextEditingController regionCtrl,
    TextEditingController mapUrlCtrl,
    TextEditingController travelModeCtrl,
    TextEditingController driverCtrl,
    TextEditingController travelTimeCtrl,
    TextEditingController pocCtrl,
    TextEditingController roomCtrl,
    TextEditingController startCtrl,
    TextEditingController endCtrl,
  ) {
    return _SectionCard(
      title: 'Logistics & Location',
      child: Column(
        children: [
          LayoutBuilder(builder: (ctx, constraints) {
            final narrow = constraints.maxWidth < 400;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: narrow ? 1 : 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: narrow ? 4 : 3,
              children: [
                _buildField(ctx, 'LOCATION / REGION', regionCtrl),
                _buildField(ctx, 'MAP URL / COORDINATES', mapUrlCtrl,
                    hint: 'Google Maps Link'),
                Row(children: [
                  Expanded(
                      child: _buildField(ctx, 'TRAVEL MODE', travelModeCtrl)),
                  8.w,
                  Expanded(child: _buildField(ctx, 'DRIVER POV', driverCtrl)),
                ]),
                Row(children: [
                  Expanded(
                      child: _buildField(ctx, 'TRAVEL TIME', travelTimeCtrl)),
                  8.w,
                  Expanded(child: _buildField(ctx, 'POC AT VENUE', pocCtrl)),
                ]),
              ],
            );
          }),
          16.h,
          _buildField(context, 'REQUIRED ROOM DETAIL', roomCtrl,
              hint: 'e.g. NIL or Room 202'),
          24.h,
          const Divider(),
          24.h,
          Row(children: [
            Expanded(
                child: _buildField(context, 'SERVICE START TIME', startCtrl,
                    textColor: Colors.amber)),
            16.w,
            Expanded(
                child: _buildField(context, 'REQUIRED COMPLETION', endCtrl,
                    textColor: Colors.amber)),
          ]),
        ],
      ),
    );
  }

  // ── Scheduled Dates section ────────────────────────────────────────────
  Widget _buildScheduledDates(
    BuildContext context,
    CrmTheme crmColors,
    Booking booking,
    TextEditingController secondaryCtrl,
  ) {
    final dateStr = booking.bookingDate.toString().split(' ')[0];
    final endDateStr = booking.serviceEnd.toString().split(' ')[0];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.05),
        border:
            Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SCHEDULED DATES',
              style: TextStyle(
                  color: Colors.indigo.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2)),
          const Divider(color: Colors.indigoAccent),
          16.h,
          _dateBadge(context, dateStr, 'confirmed', crmColors),
          if (dateStr != endDateStr) ...[
            8.h,
            _dateBadge(context, endDateStr, 'pending', crmColors),
          ],
          24.h,
          const Divider(color: Colors.indigoAccent),
          16.h,
          _buildField(context, 'SECONDARY CONTACT', secondaryCtrl,
              hint: 'Alternative Phone',
              keyboardType: TextInputType.phone),
        ],
      ),
    );
  }

  Widget _dateBadge(BuildContext context, String date, String status,
      CrmTheme crmColors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Colors.indigo.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.indigo.shade400,
                  fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  // ── Artist Assignment section ──────────────────────────────────────────
  Widget _buildArtistAssignment(
    BuildContext context,
    CrmTheme crmColors,
    bool isNarrow,
    ValueNotifier<List<Map<String, dynamic>>> assignments,
    List<Map<String, dynamic>> availableArtists,
  ) {
    return _SectionCard(
      title: 'Artist Assignment Flow',
      child: Flex(
        direction: isNarrow ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CURRENT ASSIGNED TEAM',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: crmColors.textSecondary,
                        letterSpacing: 1.2)),
                16.h,
                if (assignments.value.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        border: Border.all(color: crmColors.border),
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(
                        child: Text('NO ARTISTS ASSIGNED YET',
                            style: TextStyle(
                                color: crmColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))),
                  )
                else
                  ...assignments.value.map(
                      (a) => _buildAssignmentBlock(a, crmColors, assignments)),
              ],
            ),
          ),
          if (isNarrow) 24.h else 32.w,
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: crmColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: crmColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 4, height: 16, color: Colors.indigo),
                    8.w,
                    Text('ASSIGN TEAM MEMBER',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: crmColors.textSecondary,
                            letterSpacing: 1.2)),
                  ]),
                  24.h,
                  _buildAssignForm(
                      context, crmColors, availableArtists, assignments),
                  24.h,
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: crmColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: crmColors.border)),
                    child: Text(
                      'Note: A booking must have one Lead Artist before Assistants can be added.',
                      style: TextStyle(
                          fontSize: 10,
                          color: crmColors.textSecondary,
                          fontStyle: FontStyle.italic),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentBlock(
    Map<String, dynamic> lead,
    CrmTheme crmColors,
    ValueNotifier<List<Map<String, dynamic>>> assignments,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: crmColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: const Border(
                left: BorderSide(color: Colors.amber, width: 4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(lead['artist_name'] as String,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    8.w,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('LEAD',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold)),
                    )
                  ]),
                  4.h,
                  Text(
                      '${lead["role"]} • ${lead["type"]}',
                      style: TextStyle(
                          fontSize: 10,
                          color: crmColors.textSecondary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton(
                onPressed: () {
                  assignments.value = assignments.value
                      .where((a) => a['id'] != lead['id'])
                      .toList();
                },
                child: const Text('REMOVE',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
        8.h,
      ],
    );
  }

  Widget _buildAssignForm(
    BuildContext context,
    CrmTheme crmColors,
    List<Map<String, dynamic>> availableArtists,
    ValueNotifier<List<Map<String, dynamic>>> assignments,
  ) {
    final selectedArtistId = ValueNotifier<String?>(null);
    final roleCtrl = TextEditingController();
    final hasLead =
        assignments.value.any((a) => a['role_type'] == 'lead');
    final isLead = !hasLead;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLead
            ? Colors.amber.withValues(alpha: 0.05)
            : Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLead
              ? Colors.amber.withValues(alpha: 0.2)
              : Colors.indigo.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLead ? 'ASSIGN LEAD ARTIST' : 'ADD ASSISTANT',
            style: TextStyle(
                fontSize: 9,
                color: isLead ? Colors.amber : Colors.indigoAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
          ),
          12.h,
          DropdownButtonFormField<String>(
            items: availableArtists
                .map((a) => DropdownMenuItem(
                    value: a['id'] as String,
                    child:
                        Text('${a["name"]} (${a["type"]})')))
                .toList(),
            onChanged: (v) => selectedArtistId.value = v,
            decoration: _inputDeco(
                'Select artist…', crmColors).copyWith(isDense: true),
          ),
          if (!isLead) ...[
            12.h,
            TextField(
              controller: roleCtrl,
              decoration: _inputDeco('Role, e.g. Hair / Draping',
                      crmColors)
                  .copyWith(isDense: true),
            ),
          ],
          12.h,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (selectedArtistId.value == null) return;
                final artist = availableArtists.firstWhere(
                    (a) => a['id'] == selectedArtistId.value);
                assignments.value = [
                  ...assignments.value,
                  {
                    'id': artist['id'],
                    'artist_name': artist['name'],
                    'role': isLead
                        ? 'Lead Artist'
                        : (roleCtrl.text.isEmpty
                            ? 'Assistant'
                            : roleCtrl.text),
                    'type': artist['type'],
                    'role_type': isLead ? 'lead' : 'assistant',
                  }
                ];
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isLead ? Colors.amber : Colors.indigo,
                foregroundColor:
                    isLead ? Colors.black : Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: Text(isLead ? 'ASSIGN LEAD' : 'ADD ASSISTANT'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Generic field helpers ─────────────────────────────────────────────
  static Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController ctrl, {
    String? hint,
    Color? textColor,
    TextInputType? keyboardType,
  }) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: crmColors.textSecondary,
                letterSpacing: 1.2)),
        4.h,
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: TextStyle(
              color: textColor,
              fontWeight:
                  textColor != null ? FontWeight.bold : FontWeight.normal),
          decoration: _inputDeco(hint ?? '', crmColors),
        ),
      ],
    );
  }

  static Widget _buildTextArea(
    BuildContext context,
    String label,
    TextEditingController ctrl, {
    String? hint,
  }) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: crmColors.textSecondary,
                letterSpacing: 1.2)),
        4.h,
        TextFormField(
          controller: ctrl,
          maxLines: 2,
          decoration: _inputDeco(hint ?? '', crmColors),
        ),
      ],
    );
  }

  static Widget _buildDropdown(
    BuildContext context,
    String label,
    List<String> items,
    String value,
    void Function(String?) onChanged,
  ) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: crmColors.textSecondary,
                letterSpacing: 1.2)),
        4.h,
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                      e[0].toUpperCase() + e.substring(1))))
              .toList(),
          onChanged: onChanged,
          decoration: _inputDeco('', crmColors),
        ),
      ],
    );
  }

  static Widget _buildInfoField(
      BuildContext context, String label, String value) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: crmColors.textSecondary,
                letterSpacing: 1.2)),
        4.h,
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: crmColors.surface.withValues(alpha: 0.5),
            border: Border.all(color: crmColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  static Widget _buildCurrencyField(
    BuildContext context,
    String label,
    TextEditingController ctrl,
    CrmTheme crmColors, {
    Color? textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: crmColors.textSecondary,
                letterSpacing: 1.2)),
        4.h,
        TextFormField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
              color: textColor ?? crmColors.textPrimary,
              fontWeight: FontWeight.bold),
          decoration: _inputDeco('', crmColors).copyWith(
            prefixIcon: const Padding(
              padding:
                  EdgeInsets.only(left: 12.0, top: 12, bottom: 12),
              child: Text('₹ ',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  static InputDecoration _inputDeco(String hint, CrmTheme crmColors) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: crmColors.textSecondary, fontSize: 12),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: crmColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: crmColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide:
              const BorderSide(color: Colors.amber, width: 1.5)),
      filled: true,
      fillColor: crmColors.surface,
    );
  }

  static String _fmt(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

// ── Section Card widget ────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color? titleColor;
  final Widget? action;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.titleColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Container(
      padding: EdgeInsets.all(ResponsiveBuilder.isMobile(context) ? 16 : 24),
      decoration: BoxDecoration(
        color: crmColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crmColors.border),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: titleColor ?? crmColors.textPrimary,
                          letterSpacing: 1.2),
                    ),
                    if (subtitle != null) ...[
                      4.h,
                      Text(
                        subtitle!.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: crmColors.textSecondary,
                            letterSpacing: 1.1),
                      ),
                    ]
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
