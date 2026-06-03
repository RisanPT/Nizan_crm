import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/lead_service.dart';
import '../../core/models/lead.dart';
import '../../providers/dio_provider.dart';

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

String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}';
}

// ─────────────────────────────────────────────────────────
//  Status color helper (top-level so shared everywhere)
// ─────────────────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'converted': return const Color(0xFF22C55E);
    case 'lost':      return const Color(0xFFEF4444);
    case 'contacted': return const Color(0xFF3B82F6);
    case 'qualified': return const Color(0xFF14B8A6);
    case 'follow-up': return const Color(0xFFF97316);
    default:          return const Color(0xFFF97316);
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
    final asyncLeads = ref.watch(leadsProvider);
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isDesktop = ResponsiveBuilder.isDesktop(context);

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
            asyncLeads.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (leads) => _LeadsTable(leads: leads, isDesktop: isDesktop),
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
                  Column(
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
                  const Spacer(),
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
    final selectedSource   = useState(initialLead?.source ?? 'Instagram');
    final customSourceCtrl = useTextEditingController(
      text: _isKnownSource(initialLead?.source) ? '' : (initialLead?.source ?? ''),
    );
    final locationCtrl  = useTextEditingController(text: initialLead?.location ?? '');
    final leadTypeCtrl  = useTextEditingController(text: initialLead?.leadType ?? 'Individual');
    final reasonCtrl    = useTextEditingController(text: initialLead?.reason ?? '');
    final remarksCtrl   = useTextEditingController(text: initialLead?.remarks ?? '');
    final enquiryDate   = useState(initialLead?.enquiryDate ?? DateTime.now());
    final bookedDate    = useState<DateTime?>(initialLead?.bookedDate);
    final status        = useState(initialLead?.status ?? 'New');
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
        final payload = {
          'name': nameCtrl.text,
          'phone': phoneCtrl.text,
          'source': selectedSource.value == 'Other'
              ? customSourceCtrl.text.trim()
              : selectedSource.value,
          'location': locationCtrl.text,
          'leadType': leadTypeCtrl.text,
          'enquiryDate': enquiryDate.value.toIso8601String(),
          'bookedDate': bookedDate.value?.toIso8601String(),
          'status': status.value,
          'reason': reasonCtrl.text,
          'remarks': remarksCtrl.text,
        };

        if (isEditing) {
          await dio.put('/leads/${initialLead!.id}', data: payload);
        } else {
          await dio.post('/leads', data: payload);
          // Reset form after add
          nameCtrl.clear();
          phoneCtrl.clear();
          locationCtrl.clear();
          reasonCtrl.clear();
          remarksCtrl.clear();
          customSourceCtrl.clear();
          leadTypeCtrl.text = 'Individual';
          selectedSource.value = 'Instagram';
          enquiryDate.value = DateTime.now();
          bookedDate.value = null;
          status.value = 'New';
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

    // ── date picker helper ─────────────────────────────────
    Future<void> pickDate({
      required DateTime initial,
      required void Function(DateTime) onPicked,
    }) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) onPicked(picked);
    }

    // ── UI ────────────────────────────────────────────────
    Widget buildField(Widget child) => child;

    // Full-width on mobile, fixed-width on desktop
    Widget responsiveField(Widget field, {double desktopWidth = 220}) {
      if (isMobile) return field;
      return SizedBox(width: desktopWidth, child: field);
    }

    final fields = [
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

      // Phone
      responsiveField(
        TextFormField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number *',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        desktopWidth: 200,
      ),

      // Enquiry Date
      responsiveField(
        InkWell(
          onTap: () => pickDate(
            initial: enquiryDate.value,
            onPicked: (d) => enquiryDate.value = d,
          ),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date Enquired For',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(_fmtDate(enquiryDate.value)),
          ),
        ),
        desktopWidth: 200,
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
          value: selectedSource.value,
          decoration: const InputDecoration(
            labelText: 'Source',
            prefixIcon: Icon(Icons.campaign_outlined),
          ),
          items: ['Instagram', 'YouTube', 'Reference', 'Walk-in', 'Other']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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

      // Lead Type
      responsiveField(
        TextFormField(
          controller: leadTypeCtrl,
          decoration: const InputDecoration(
            labelText: 'Lead Type',
            prefixIcon: Icon(Icons.category_outlined),
          ),
        ),
        desktopWidth: 180,
      ),

      // Status
      responsiveField(
        DropdownButtonFormField<String>(
          value: status.value,
          decoration: const InputDecoration(
            labelText: 'Status',
            prefixIcon: Icon(Icons.info_outline),
          ),
          items: ['New', 'Contacted', 'Qualified', 'Follow-up', 'Converted', 'Lost']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => status.value = v!,
        ),
        desktopWidth: 180,
      ),

      // Reason
      responsiveField(
        TextFormField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (if Lost)',
            prefixIcon: Icon(Icons.help_outline),
          ),
        ),
        desktopWidth: 250,
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
              children: fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: f,
              )).toList(),
            )
          else
            // Wrap horizontally on desktop/tablet
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: fields,
            ),

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
    final isMobile = ResponsiveBuilder.isMobile(context);

    if (leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('No leads found.', style: TextStyle(color: crm.textSecondary)),
        ),
      );
    }

    // ── Mobile: rich cards ──────────────────────────────
    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: leads.length,
        separatorBuilder: (context, index) => 10.h,
        itemBuilder: (context, index) {
          final lead = leads[index];
          return _MobileLeadCard(
            lead: lead,
            onEdit: () => _showEditDialog(context, ref, lead),
            onDelete: () => _confirmDelete(context, ref, lead),
          );
        },
      );
    }

    // ── Desktop: table ──────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1200),
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(110),
              1: FixedColumnWidth(110),
              2: FixedColumnWidth(180),
              3: FixedColumnWidth(110),
              4: FixedColumnWidth(140),
              5: FixedColumnWidth(110),
              6: FixedColumnWidth(130),
              7: FixedColumnWidth(110),
              8: FixedColumnWidth(130),
              9: FixedColumnWidth(220),
              10: FixedColumnWidth(100),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: crm.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                children: const [
                  _HeaderCell('DATE'),
                  _HeaderCell('BOOKED'),
                  _HeaderCell('NAME'),
                  _HeaderCell('ENQUIRED FOR'),
                  _HeaderCell('PHONE'),
                  _HeaderCell('SOURCE'),
                  _HeaderCell('LOCATION'),
                  _HeaderCell('LEAD TYPE'),
                  _HeaderCell('STATUS'),
                  _HeaderCell('REMARKS'),
                  _HeaderCell('ACTIONS'),
                ],
              ),
              ...leads.map((lead) {
                return TableRow(
                  children: [
                    _DataCell(_fmtDate(lead.createdAt)),
                    _DataCell(lead.bookedDate != null ? _fmtDate(lead.bookedDate!) : '-'),
                    _DataCell(lead.name, bold: true),
                    _DataCell(_fmtDate(lead.enquiryDate)),
                    _DataCell(lead.phone),
                    _DataCell(lead.source),
                    _DataCell(lead.location),
                    _DataCell(lead.leadType),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _StatusBadge(status: lead.status),
                    ),
                    _DataCell(lead.remarks),
                    // Actions column
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit',
                            color: const Color(0xFF6C63FF),
                            onPressed: () => _showEditDialog(context, ref, lead),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: 'Delete',
                            color: Colors.red,
                            onPressed: () => _confirmDelete(context, ref, lead),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Mobile Lead Card
// ─────────────────────────────────────────────────────────
class _MobileLeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileLeadCard({
    required this.lead,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = _statusColor(lead.status);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: crm.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: name + status + actions ─────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    lead.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                8.w,
                _StatusBadge(status: lead.status),
                4.w,
                // Edit button
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6C63FF)),
                  ),
                ),
                4.w,
                // Delete button
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  ),
                ),
              ],
            ),
            10.h,

            // ── Details grid ──────────────────────────────
            _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: lead.phone),
            6.h,
            _InfoRow(icon: Icons.campaign_outlined, label: 'Source', value: lead.source),
            6.h,
            _InfoRow(icon: Icons.location_on_outlined, label: 'Location', value: lead.location.isNotEmpty ? lead.location : '-'),
            6.h,
            _InfoRow(icon: Icons.category_outlined, label: 'Type', value: lead.leadType),
            6.h,
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Enquired For',
              value: _fmtDate(lead.enquiryDate),
            ),
            if (lead.bookedDate != null) ...[
              6.h,
              _InfoRow(
                icon: Icons.bookmark_added_outlined,
                label: 'Booked',
                value: _fmtDate(lead.bookedDate!),
                valueColor: const Color(0xFF22C55E),
              ),
            ],
            if (lead.remarks.isNotEmpty) ...[
              10.h,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Text(
                  lead.remarks,
                  style: TextStyle(fontSize: 13, color: crm.textSecondary, height: 1.4),
                ),
              ),
            ],
          ],
        ),
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
class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
        ),
      );
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool bold;
  const _DataCell(this.text, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      );
}

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
