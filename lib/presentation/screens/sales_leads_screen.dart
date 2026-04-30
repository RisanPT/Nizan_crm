import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/lead_service.dart';
import '../../core/models/lead.dart';
import '../../providers/dio_provider.dart';

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

class _QuickAddLeadCard extends HookConsumerWidget {
  const _QuickAddLeadCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final nameCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final sourceCtrl = useTextEditingController(text: 'Walk-in');
    final locationCtrl = useTextEditingController();
    final leadTypeCtrl = useTextEditingController(text: 'Individual');
    final reasonCtrl = useTextEditingController();
    final remarksCtrl = useTextEditingController();
    final enquiryDate = useState(DateTime.now());
    final status = useState('New');
    final isSaving = useState(false);

    Future<void> _save() async {
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
          'source': sourceCtrl.text,
          'location': locationCtrl.text,
          'leadType': leadTypeCtrl.text,
          'enquiryDate': enquiryDate.value.toIso8601String(),
          'status': status.value,
          'reason': reasonCtrl.text,
          'remarks': remarksCtrl.text,
        });
        
        nameCtrl.clear();
        phoneCtrl.clear();
        locationCtrl.clear();
        reasonCtrl.clear();
        remarksCtrl.clear();
        enquiryDate.value = DateTime.now();
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

    String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

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
            const Text(
              'Add Existing Data / New Lead',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            16.h,
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 250,
                  child: TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person_outline)),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone_outlined)),
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
                      decoration: const InputDecoration(labelText: 'Date Enquired For', prefixIcon: Icon(Icons.calendar_today_outlined)),
                      child: Text(_fmt(enquiryDate.value)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: sourceCtrl,
                    decoration: const InputDecoration(labelText: 'Source', prefixIcon: Icon(Icons.campaign_outlined)),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_outlined)),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: leadTypeCtrl,
                    decoration: const InputDecoration(labelText: 'Lead Type', prefixIcon: Icon(Icons.category_outlined)),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: status.value,
                    decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline)),
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
                    decoration: const InputDecoration(labelText: 'Reason (if Lost)', prefixIcon: Icon(Icons.help_outline)),
                  ),
                ),
                SizedBox(
                  width: 400,
                  child: TextFormField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks', prefixIcon: Icon(Icons.notes)),
                  ),
                ),
              ],
            ),
            24.h,
            SizedBox(
              height: 52,
              width: 200,
              child: ElevatedButton.icon(
                onPressed: isSaving.value ? null : _save,
                icon: isSaving.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: const Text('Save Data Flow'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadsTable extends StatelessWidget {
  final List<Lead> leads;
  final bool isDesktop;

  const _LeadsTable({required this.leads, required this.isDesktop});

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
              0: FixedColumnWidth(100),
              1: FixedColumnWidth(180),
              2: FixedColumnWidth(120),
              3: FixedColumnWidth(140),
              4: FixedColumnWidth(120),
              5: FixedColumnWidth(140),
              6: FixedColumnWidth(120),
              7: FixedColumnWidth(140),
              8: FixedColumnWidth(250),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: crm.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                children: const [
                  _HeaderCell('DATE'),
                  _HeaderCell('Name'),
                  _HeaderCell('Enquired For'),
                  _HeaderCell('Phone'),
                  _HeaderCell('Source'),
                  _HeaderCell('Location'),
                  _HeaderCell('Lead Type'),
                  _HeaderCell('Status'),
                  _HeaderCell('Remarks'),
                ],
              ),
              ...leads.map((lead) {
                final d = lead.createdAt;
                final ed = lead.enquiryDate;
                return TableRow(
                  children: [
                    _DataCell('${d.day}/${d.month}/${d.year}'),
                    _DataCell(lead.name, bold: true),
                    _DataCell('${ed.day}/${ed.month}/${ed.year}'),
                    _DataCell(lead.phone),
                    _DataCell(lead.source),
                    _DataCell(lead.location),
                    _DataCell(lead.leadType),
                    Padding(padding: const EdgeInsets.all(12), child: _StatusBadge(status: lead.status)),
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

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
      );
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool bold;
  const _DataCell(this.text, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(status, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'converted': return Colors.green;
      case 'lost': return Colors.red;
      case 'contacted': return Colors.blue;
      default: return Colors.orange;
    }
  }
}
