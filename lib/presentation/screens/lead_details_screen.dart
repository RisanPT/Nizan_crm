import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/models/lead.dart';
import '../../core/models/lead_activity.dart';
import '../../services/lead_service.dart';
import '../../services/lead_activity_service.dart';
import '../../services/user_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../providers/dio_provider.dart';

// Formatting helpers
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

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'converted': return const Color(0xFF22C55E);
    case 'lost':      return const Color(0xFFEF4444);
    case 'contacted': return const Color(0xFF3B82F6);
    case 'qualified': return const Color(0xFF14B8A6);
    case 'follow-up': return const Color(0xFFF97316);
    default:          return const Color(0xFF6B7280); // New / Grey
  }
}

class LeadDetailsScreen extends HookConsumerWidget {
  final String leadId;

  const LeadDetailsScreen({super.key, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final selectedTab = useState('followup'); // 'followup' | 'call' | 'activity'

    final asyncLeads = ref.watch(leadsProvider);
    final asyncActivities = ref.watch(leadActivitiesProvider(leadId));
    final session = ref.watch(authSessionProvider);
    final isAdminOrManager = session != null && (session.role == 'admin' || session.role == 'manager');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/sales/leads'),
        ),
        title: const Text('Lead Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(leadsProvider);
              ref.invalidate(leadActivitiesProvider(leadId));
            },
          ),
        ],
      ),
      body: asyncLeads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading lead: $err')),
        data: (leads) {
          final leadIndex = leads.indexWhere((l) => l.id == leadId);
          if (leadIndex == -1) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Lead not found.'),
                  16.h,
                  ElevatedButton(
                    onPressed: () => context.go('/sales/leads'),
                    child: const Text('Back to Leads'),
                  ),
                ],
              ),
            );
          }

          final lead = leads[leadIndex];

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Lead Header Details Card
                _buildHeaderCard(context, ref, lead, crm, isAdminOrManager),
                24.h,

                // 2. Tab Bar Selector
                _buildTabBar(context, selectedTab, crm),
                20.h,

                // 3. Timeline / Vertical Logs list
                asyncActivities.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error loading logs: $err')),
                  data: (activities) {
                    final filtered = activities.where((act) => act.type == selectedTab.value).toList();
                    return _buildTimelineList(context, ref, filtered, crm, leadId);
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'upload_btn',
            onPressed: () => _showUploadDialog(context, ref, leadId),
            backgroundColor: const Color(0xFF8B5CF6),
            child: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
          ),
          8.h,
          FloatingActionButton(
            heroTag: 'add_followup_btn',
            onPressed: () => _showAddLogDialog(context, ref, leadId, selectedTab.value),
            backgroundColor: const Color(0xFF22C55E),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ── Header Card widget ──────────────────────────────────────────────────────
  Widget _buildHeaderCard(BuildContext context, WidgetRef ref, Lead lead, CrmTheme crm, bool isAdminOrManager) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crm.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor(lead.status),
                    shape: BoxShape.circle,
                  ),
                ),
                10.w,
                Expanded(
                  child: Text(
                    lead.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(lead.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(lead.status).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    lead.status,
                    style: TextStyle(
                      color: _statusColor(lead.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            12.h,
            Text(
              lead.phone,
              style: TextStyle(fontSize: 15, color: crm.textSecondary, fontWeight: FontWeight.w500),
            ),
            12.h,
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _buildHeaderMeta(Icons.assignment_ind_outlined, 'Assigned', lead.assignedTo != null ? 'Sales Staff' : 'Unassigned'),
                _buildHeaderMeta(Icons.calendar_today_outlined, 'Created Date', _fmtDate(lead.leadDate)),
                _buildHeaderMeta(Icons.campaign_outlined, 'Source', lead.source),
                _buildHeaderMeta(Icons.category_outlined, 'Type', lead.leadType),
              ],
            ),
            16.h,
            const Divider(),
            12.h,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _launchCall(context, lead.phone),
                  icon: const Icon(Icons.call, size: 16, color: Color(0xFF22C55E)),
                  label: const Text('Call', style: TextStyle(color: Color(0xFF22C55E))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF22C55E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _launchWhatsApp(context, lead.phone),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF25D366)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showEditDialog(context, ref, lead),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6C63FF)),
                  label: const Text('Edit', style: TextStyle(color: Color(0xFF6C63FF))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (isAdminOrManager)
                  OutlinedButton.icon(
                    onPressed: () => _showTransferDialog(context, ref, lead),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFFF97316)),
                    label: const Text('Transfer', style: TextStyle(color: Color(0xFFF97316))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF97316)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMeta(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        6.w,
        Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Tab Bar selector ────────────────────────────────────────────────────────
  Widget _buildTabBar(BuildContext context, ValueNotifier<String> selectedTab, CrmTheme crm) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTabChip('Followup', 'followup', selectedTab, crm),
          10.w,
          _buildTabChip('Call History', 'call', selectedTab, crm),
          10.w,
          _buildTabChip('Activities', 'activity', selectedTab, crm),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String value, ValueNotifier<String> selectedTab, CrmTheme crm) {
    final isSelected = selectedTab.value == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) selectedTab.value = value;
      },
      selectedColor: crm.primary.withValues(alpha: 0.12),
      checkmarkColor: crm.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        color: isSelected ? crm.primary : crm.textSecondary,
      ),
      side: BorderSide(color: isSelected ? crm.primary : crm.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ── Timeline list widget ────────────────────────────────────────────────────
  Widget _buildTimelineList(BuildContext context, WidgetRef ref, List<LeadActivity> activities, CrmTheme crm, String leadId) {
    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No records found for this category.',
            style: TextStyle(color: crm.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildTimelineItem(context, ref, activity, crm, leadId);
      },
    );
  }

  Widget _buildTimelineItem(BuildContext context, WidgetRef ref, LeadActivity activity, CrmTheme crm, String leadId) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Date Bubble + Vertical Line
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: crm.background,
                border: Border.all(color: crm.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _fmtDate(activity.scheduledDate),
                style: TextStyle(fontSize: 10, color: crm.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              width: 2,
              height: 100,
              color: crm.primary.withValues(alpha: 0.3),
            ),
          ],
        ),
        16.w,
        // Right Column: Timeline Log Card
        Expanded(
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: crm.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        child: Icon(Icons.person, size: 12),
                      ),
                      8.w,
                      Expanded(
                        child: Text(
                          activity.createdByName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        onPressed: () => _confirmDeleteActivity(context, ref, leadId, activity.id),
                      ),
                    ],
                  ),
                  8.h,
                  Text(
                    'Scheduled: ${_fmtDateTime(activity.scheduledDate)}',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  if (activity.remark.isNotEmpty) ...[
                    6.h,
                    Text(
                      'Remark: ${activity.remark}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                  if (activity.type == 'call' && activity.callResponse != 'N/A') ...[
                    6.h,
                    Text(
                      'Response: ${activity.callResponse}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF22C55E)),
                    ),
                  ],
                  8.h,
                  Row(
                    children: [
                      const Text('Status: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getActivityStatusColor(activity.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          activity.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getActivityStatusColor(activity.status),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getActivityStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return const Color(0xFF22C55E);
      case 'cancelled': return const Color(0xFFEF4444);
      default:          return const Color(0xFFF97316); // Pending / Orange
    }
  }

  // ── Action Handlers ─────────────────────────────────────────────────────────
  Future<void> _launchCall(BuildContext context, String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch dialer.')),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp.')),
        );
      }
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Lead lead) {
    // Navigate to edit using the existing form inside a Dialog or delegate to page
    // For simplicity, we can reuse the edit dialog from sales_leads_screen
    // We will show a SnackBar or navigate
    context.push('/sales/leads');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap Edit on the lead in the table to modify.')),
    );
  }

  void _showTransferDialog(BuildContext context, WidgetRef ref, Lead lead) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _TransferLeadDialog(lead: lead, onSaved: () {
          ref.invalidate(leadsProvider);
        });
      },
    );
  }

  void _confirmDeleteActivity(BuildContext context, WidgetRef ref, String leadId, String activityId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Log?'),
        content: const Text('Are you sure you want to remove this log entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(leadActivityServiceProvider).deleteActivity(leadId, activityId);
                ref.invalidate(leadActivitiesProvider(leadId));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showUploadDialog(BuildContext context, WidgetRef ref, String leadId) {
    // Placeholder upload screenshots dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Screenshots'),
        content: const Text('Cloudinary upload capability is running on backend. Select document or screenshot to attach to this lead.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showAddLogDialog(BuildContext context, WidgetRef ref, String leadId, String initialType) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _AddActivityLogDialog(leadId: leadId, initialType: initialType, onSaved: () {
          ref.invalidate(leadsProvider); // refresh parent status
          ref.invalidate(leadActivitiesProvider(leadId)); // refresh timeline
        });
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Transfer Lead Dialog
// ─────────────────────────────────────────────────────────
class _TransferLeadDialog extends HookConsumerWidget {
  final Lead lead;
  final VoidCallback onSaved;

  const _TransferLeadDialog({required this.lead, required this.onSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUsers = ref.watch(crmUsersProvider);
    final selectedUser = useState<String?>(lead.assignedTo);
    final isSaving = useState(false);

    return AlertDialog(
      title: const Text('Transfer Lead'),
      content: asyncUsers.when(
        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Text('Error loading users: $err'),
        data: (users) {
          final salesStaff = users.where((u) => u.role == 'sales').toList();
          return DropdownButtonFormField<String?>(
            initialValue: selectedUser.value,
            decoration: const InputDecoration(
              labelText: 'Select Sales Executive',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Unassigned'),
              ),
              ...salesStaff.map((u) => DropdownMenuItem<String?>(
                    value: u.id,
                    child: Text(u.name),
                  )),
            ],
            onChanged: (val) => selectedUser.value = val,
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: isSaving.value
              ? null
              : () async {
                  isSaving.value = true;
                  try {
                    final dio = ref.read(dioProvider);
                    await dio.put('/leads/${lead.id}', data: {
                      'assignedTo': selectedUser.value,
                    });
                    onSaved();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lead reassigned successfully!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  } finally {
                    isSaving.value = false;
                  }
                },
          child: const Text('Transfer'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Add Activity Log Dialog
// ─────────────────────────────────────────────────────────
class _AddActivityLogDialog extends HookConsumerWidget {
  final String leadId;
  final String initialType;
  final VoidCallback onSaved;

  const _AddActivityLogDialog({required this.leadId, required this.initialType, required this.onSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = useState(initialType);
    final remarkCtrl = useTextEditingController();
    final callResponse = useState('Connected');
    final status = useState('Pending');
    final scheduledDate = useState(DateTime.now());
    final leadStatus = useState<String?>('Follow-up');
    final isSaving = useState(false);

    Future<void> pickDateTime() async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: scheduledDate.value,
        firstDate: DateTime(2015),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null) return;
      if (!context.mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(scheduledDate.value),
      );
      if (pickedTime == null) return;
      scheduledDate.value = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute,
      );
    }

    return AlertDialog(
      title: const Text('Add Activity Log'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type.value,
              decoration: const InputDecoration(labelText: 'Log Type'),
              items: const [
                DropdownMenuItem(value: 'followup', child: Text('Followup')),
                DropdownMenuItem(value: 'call', child: Text('Call History')),
                DropdownMenuItem(value: 'activity', child: Text('Activities/Remarks')),
              ],
              onChanged: (val) {
                if (val != null) {
                  type.value = val;
                  // Auto defaults
                  if (val == 'followup') {
                    status.value = 'Pending';
                    leadStatus.value = 'Follow-up';
                  } else {
                    status.value = 'Completed';
                    leadStatus.value = null;
                  }
                }
              },
            ),
            12.h,
            InkWell(
              onTap: pickDateTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Scheduled Time',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_fmtDateTime(scheduledDate.value)),
              ),
            ),
            if (type.value == 'call') ...[
              12.h,
              DropdownButtonFormField<String>(
                initialValue: callResponse.value,
                decoration: const InputDecoration(labelText: 'Call Response'),
                items: const [
                  DropdownMenuItem(value: 'Connected', child: Text('Connected')),
                  DropdownMenuItem(value: 'No Answer', child: Text('No Answer')),
                  DropdownMenuItem(value: 'Busy', child: Text('Busy')),
                  DropdownMenuItem(value: 'Switched Off', child: Text('Switched Off')),
                ],
                onChanged: (val) => callResponse.value = val!,
              ),
            ],
            12.h,
            DropdownButtonFormField<String>(
              initialValue: status.value,
              decoration: const InputDecoration(labelText: 'Log Status'),
              items: const [
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
              ],
              onChanged: (val) => status.value = val!,
            ),
            12.h,
            DropdownButtonFormField<String?>(
              initialValue: leadStatus.value,
              decoration: const InputDecoration(
                labelText: 'Change Lead Status To',
                helperText: 'Select to update current lead status',
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Do Not Change')),
                DropdownMenuItem(value: 'New', child: Text('New')),
                DropdownMenuItem(value: 'Contacted', child: Text('Contacted')),
                DropdownMenuItem(value: 'Qualified', child: Text('Qualified')),
                DropdownMenuItem(value: 'Follow-up', child: Text('Follow-up')),
                DropdownMenuItem(value: 'Converted', child: Text('Converted')),
                DropdownMenuItem(value: 'Lost', child: Text('Lost')),
              ],
              onChanged: (val) => leadStatus.value = val,
            ),
            12.h,
            TextFormField(
              controller: remarkCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remark / Notes',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: isSaving.value
              ? null
              : () async {
                  if (remarkCtrl.text.trim().isEmpty && type.value == 'activity') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Remark is required for activities.')),
                    );
                    return;
                  }
                  isSaving.value = true;
                  try {
                    await ref.read(leadActivityServiceProvider).createActivity(leadId, {
                      'type': type.value,
                      'scheduledDate': scheduledDate.value.toIso8601String(),
                      'remark': remarkCtrl.text.trim(),
                      'status': status.value,
                      'callResponse': type.value == 'call' ? callResponse.value : 'N/A',
                      'leadStatus': leadStatus.value,
                    });
                    onSaved();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Log entry saved successfully!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  } finally {
                    isSaving.value = false;
                  }
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
