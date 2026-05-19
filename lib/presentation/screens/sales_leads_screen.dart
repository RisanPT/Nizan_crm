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
    // ── phone  ──────────────────────────────────────────────
    final phoneMatch = RegExp(r'[\+\d][\d\s\-]{7,14}').firstMatch(line);
    if (phoneMatch != null && phone.isEmpty) {
      phone = phoneMatch.group(0)!.replaceAll(RegExp(r'\s'), '');
    }

    // ── date  ───────────────────────────────────────────────
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

    // ── key:value style  ────────────────────────────────────
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
      // First unmatched readable line is likely a name
      if (!RegExp(r'\d').hasMatch(line) && !line.contains('@')) {
        name = line;
      }
    }
  }

  // Fallback: if no key:value, try to guess location from remaining lines
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

// ─────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────
class SalesLeadsScreen extends HookConsumerWidget {
  const SalesLeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final asyncLeads = ref.watch(leadsProvider);
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _QuickAddLeadCard(),
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
//  Quick-Add card  (with Smart Paste)
// ─────────────────────────────────────────────────────────
class _QuickAddLeadCard extends HookConsumerWidget {
  const _QuickAddLeadCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final nameCtrl      = useTextEditingController();
    final phoneCtrl     = useTextEditingController();
    final selectedSource   = useState('Instagram');
    final customSourceCtrl = useTextEditingController();
    final locationCtrl  = useTextEditingController();
    final leadTypeCtrl  = useTextEditingController(text: 'Individual');
    final reasonCtrl    = useTextEditingController();
    final remarksCtrl   = useTextEditingController();
    final enquiryDate   = useState(DateTime.now());
    final bookedDate    = useState<DateTime?>(null);
    final status        = useState('New');
    final isSaving      = useState(false);
    final isPasting     = useState(false);
    final sampleIndex   = useState(0);

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

    // ── save ─────────────────────────────────────────────
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
        await dio.post('/leads', data: {
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
        });

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

        ref.invalidate(leadsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lead added successfully!')),
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

    String fmtDate(DateTime d) {
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day.toString().padLeft(2,'0')}-${months[d.month-1]}-${d.year}';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crm.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Lead',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    4.h,
                    Text(
                      'Fill manually or paste from WhatsApp / clipboard',
                      style: TextStyle(color: crm.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                // ── Copy Sample button (cycles through all source types) ──
                Builder(builder: (ctx) {
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
                            '📋 "${current.label}" sample copied! Click Smart Paste →',
                          ),
                          backgroundColor: Colors.teal[700],
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 16),
                    label: Text('Copy: ${current.label}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }),
                12.w,
                // ── Smart Paste button ──────────────────
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


            // ── Paste format hint ────────────────────────
            16.h,
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
                      'Paste format (from WhatsApp):\n'
                      'Name: Aisha Khan  |  Phone: 9876543210  |  Location: Calicut  |  '
                      'Date: 15/06/2026  |  Remarks: Bridal makeup',
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

            20.h,
            // ── Form fields ─────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 250,
                  child: TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: enquiryDate.value,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) enquiryDate.value = picked;
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date Enquired For',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(fmtDate(enquiryDate.value)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: bookedDate.value ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) bookedDate.value = picked;
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Booked Date',
                        prefixIcon: Icon(Icons.bookmark_added_outlined),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(bookedDate.value != null ? fmtDate(bookedDate.value!) : 'Not Booked'),
                          if (bookedDate.value != null)
                            GestureDetector(
                              onTap: () => bookedDate.value = null,
                              child: const Icon(Icons.close, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
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
                ),
                if (selectedSource.value == 'Other')
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      controller: customSourceCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Specify Source',
                        prefixIcon: Icon(Icons.edit_outlined),
                        hintText: 'e.g. Google Ads',
                      ),
                    ),
                  ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: leadTypeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lead Type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: status.value,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    items: ['New', 'Contacted', 'Qualified', 'Follow-up', 'Converted', 'Lost']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => status.value = v!,
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: TextFormField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reason (if Lost)',
                      prefixIcon: Icon(Icons.help_outline),
                    ),
                  ),
                ),
                SizedBox(
                  width: 400,
                  child: TextFormField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                ),
              ],
            ),
            24.h,
            SizedBox(
              height: 52,
              width: 200,
              child: ElevatedButton.icon(
                onPressed: isSaving.value ? null : save,
                icon: isSaving.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Lead'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Leads table
// ─────────────────────────────────────────────────────────
class _LeadsTable extends StatelessWidget {
  final List<Lead> leads;
  final bool isDesktop;

  const _LeadsTable({required this.leads, required this.isDesktop});

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2,'0')}-${months[d.month-1]}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('No leads found.', style: TextStyle(color: crm.textSecondary)),
        ),
      );
    }

    if (!isDesktop) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: leads.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final lead = leads[index];
          return ListTile(
            title: Text(lead.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${lead.phone} • ${lead.source}'),
            trailing: _StatusBadge(status: lead.status),
          );
        },
      );
    }

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
              0: FixedColumnWidth(120),
              1: FixedColumnWidth(120),
              2: FixedColumnWidth(180),
              3: FixedColumnWidth(120),
              4: FixedColumnWidth(140),
              5: FixedColumnWidth(120),
              6: FixedColumnWidth(140),
              7: FixedColumnWidth(120),
              8: FixedColumnWidth(140),
              9: FixedColumnWidth(250),
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
//  Shared small widgets
// ─────────────────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
        ),
      );
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool bold;
  const _DataCell(this.text, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'converted': return Colors.green;
      case 'lost':      return Colors.red;
      case 'contacted': return Colors.blue;
      case 'qualified': return Colors.teal;
      case 'follow-up': return Colors.orange;
      default:          return Colors.orange;
    }
  }
}
