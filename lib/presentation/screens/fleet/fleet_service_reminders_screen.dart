import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../services/fleet_service.dart';
import '../../../models/fleet_models.dart';
import '../../../services/vehicle_service.dart';
import 'fleet_mobile_ui.dart';
import 'package:intl/intl.dart';

enum _Urgency { completed, overdue, dueSoon, upcoming }

_Urgency _urgencyOf(ServiceReminder r) {
  if (r.status == 'completed') return _Urgency.completed;
  var overdue = false;
  var urgent = false;
  if (r.dueDate != null) {
    final diff = r.dueDate!.difference(DateTime.now()).inDays;
    if (diff < 0) {
      overdue = true;
    } else if (diff <= 3) {
      urgent = true;
    }
  }
  if (r.dueKm != null && r.vehicle is Map) {
    final currentKm = ((r.vehicle as Map)['currentKm'] as num?)?.toDouble() ?? 0.0;
    final diffKm = r.dueKm! - currentKm;
    if (diffKm < 0) {
      overdue = true;
    } else if (diffKm <= 500) {
      urgent = true;
    }
  }
  if (overdue) return _Urgency.overdue;
  if (urgent) return _Urgency.dueSoon;
  return _Urgency.upcoming;
}

Color _urgencyColor(_Urgency u, CrmTheme c) {
  switch (u) {
    case _Urgency.completed:
      return c.success;
    case _Urgency.overdue:
      return c.destructive;
    case _Urgency.dueSoon:
      return c.warning;
    case _Urgency.upcoming:
      return c.accent;
  }
}

String _urgencyText(_Urgency u) {
  switch (u) {
    case _Urgency.completed:
      return 'Completed';
    case _Urgency.overdue:
      return 'Overdue';
    case _Urgency.dueSoon:
      return 'Due Soon';
    case _Urgency.upcoming:
      return 'Upcoming';
  }
}

IconData _iconForType(String type) {
  switch (type.toLowerCase()) {
    case 'pollution':
      return Icons.cloud_outlined;
    case 'insurance':
      return Icons.shield_outlined;
    case 'tax':
      return Icons.receipt_long_outlined;
    case 'maintenance':
      return Icons.build_outlined;
    case 'oil change':
      return Icons.water_drop_outlined;
    default:
      return Icons.car_repair_outlined;
  }
}

String _extractVehicleName(dynamic obj) {
  if (obj is Map) {
    final name = obj['name'];
    final reg = obj['registrationNumber'];
    if (name != null && reg != null) return '$name ($reg)';
    if (name != null) return name.toString();
    if (reg != null) return reg.toString();
  }
  return 'Unknown Vehicle';
}

class FleetServiceRemindersScreen extends ConsumerStatefulWidget {
  const FleetServiceRemindersScreen({super.key});

  @override
  ConsumerState<FleetServiceRemindersScreen> createState() =>
      _FleetServiceRemindersScreenState();
}

class _FleetServiceRemindersScreenState
    extends ConsumerState<FleetServiceRemindersScreen> {
  bool _hasShownPopup = false;

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final remindersAsync = ref.watch(managerServiceRemindersProvider);

    // Show popup for urgent reminders after the build phase.
    if (remindersAsync.hasValue && !_hasShownPopup) {
      final urgent = remindersAsync.value!.where((r) {
        final u = _urgencyOf(r);
        return u == _Urgency.overdue || u == _Urgency.dueSoon;
      }).toList();
      if (urgent.isNotEmpty) {
        _hasShownPopup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showUrgentRemindersPopup(urgent);
        });
      }
    }

    return Scaffold(
      backgroundColor: crmColors.background,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: remindersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text(
              'Failed to load reminders: $err',
              style: TextStyle(color: crmColors.textSecondary),
            ),
          ),
          data: (reminders) {
            final overdue = reminders
                .where((r) => _urgencyOf(r) == _Urgency.overdue)
                .length;
            final dueSoon = reminders
                .where((r) => _urgencyOf(r) == _Urgency.dueSoon)
                .length;
            final completed = reminders
                .where((r) => _urgencyOf(r) == _Urgency.completed)
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FleetMobileHeader(
                  title: 'Service Reminders',
                  stats: [
                    FleetStat(
                        value: '${reminders.length}',
                        label: 'Total',
                        color: crmColors.primary),
                    FleetStat(
                        value: '$overdue',
                        label: 'Overdue',
                        color: crmColors.destructive),
                    FleetStat(
                        value: '$dueSoon',
                        label: 'Due Soon',
                        color: crmColors.warning),
                    FleetStat(
                        value: '$completed',
                        label: 'Done',
                        color: crmColors.success),
                  ],
                ),
                16.h,
                Expanded(
                  child: reminders.isEmpty
                      ? const FleetEmptyState(
                          icon: Icons.build_circle_outlined,
                          title: 'No service reminders',
                          subtitle:
                              'Tap the + button to schedule maintenance, tax, insurance and more.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: reminders.length,
                          separatorBuilder: (_, _) => 12.h,
                          itemBuilder: (context, index) =>
                              _buildReminderCard(context, reminders[index]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderDialog(context),
        backgroundColor: crmColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Reminder'),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, ServiceReminder reminder) {
    final crmColors = context.crmColors;
    final dateFormat = DateFormat('MMM d, yyyy');
    final urgency = _urgencyOf(reminder);
    final color = _urgencyColor(urgency, crmColors);
    final isCompleted = urgency == _Urgency.completed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForType(reminder.serviceType),
                    color: color, size: 21),
              ),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.serviceType,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: crmColors.textPrimary,
                      ),
                    ),
                    2.h,
                    Text(
                      _extractVehicleName(reminder.vehicle),
                      style: TextStyle(
                          fontSize: 12.5, color: crmColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              8.w,
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.30)),
                ),
                child: Text(
                  _urgencyText(urgency),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          12.h,
          if (reminder.dueDate != null)
            _buildDetailRow(context, Icons.calendar_month_outlined, 'Due date',
                dateFormat.format(reminder.dueDate!)),
          if (reminder.dueKm != null)
            _buildDetailRow(context, Icons.speed_outlined, 'Due at',
                '${reminder.dueKm!.toStringAsFixed(0)} km'),
          if (reminder.notes != null && reminder.notes!.isNotEmpty)
            _buildDetailRow(
                context, Icons.notes_outlined, 'Notes', reminder.notes!),
          if (!isCompleted) ...[
            12.h,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _completeReminder(reminder.id),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Mark as Completed'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: crmColors.success,
                  side: BorderSide(color: crmColors.success.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, String value) {
    final crmColors = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: crmColors.textSecondary),
          8.w,
          Text('$label: ',
              style: TextStyle(fontSize: 13, color: crmColors.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: crmColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUrgentRemindersPopup(List<ServiceReminder> urgentReminders) {
    final crmColors = context.crmColors;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: crmColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: crmColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notification_important_rounded,
                        color: crmColors.warning, size: 24),
                  ),
                  16.w,
                  Expanded(
                    child: Text(
                      'Urgent Service Reminders',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textPrimary),
                    ),
                  ),
                ],
              ),
              20.h,
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: urgentReminders.length,
                  separatorBuilder: (_, _) => 12.h,
                  itemBuilder: (context, index) {
                    final r = urgentReminders[index];
                    final color = _urgencyColor(_urgencyOf(r), crmColors);
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(_iconForType(r.serviceType), color: color, size: 26),
                          14.w,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.serviceType} · ${_extractVehicleName(r.vehicle)}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: crmColors.textPrimary),
                                ),
                                4.h,
                                Row(
                                  children: [
                                    Icon(Icons.warning_rounded,
                                        color: color, size: 14),
                                    4.w,
                                    Text(
                                      r.dueDate != null
                                          ? 'Due: ${DateFormat('MMM d, yyyy').format(r.dueDate!)}'
                                          : 'Due at ${r.dueKm?.toStringAsFixed(0)} km',
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              22.h,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: crmColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Acknowledge',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeReminder(String id) async {
    try {
      await ref.read(fleetServiceProvider).completeServiceReminder(id);
      ref.invalidate(managerServiceRemindersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showAddReminderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _AddReminderDialog(),
    );
  }
}

class _AddReminderDialog extends ConsumerStatefulWidget {
  const _AddReminderDialog();

  @override
  ConsumerState<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends ConsumerState<_AddReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedVehicleId;
  String _selectedType = 'Maintenance';
  DateTime? _dueDate;
  final _kmController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  final _serviceTypes = [
    'Pollution',
    'Insurance',
    'Tax',
    'Maintenance',
    'Oil Change',
    'Other'
  ];

  @override
  void dispose() {
    _kmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dueDate == null && _kmController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide either a Due Date or a Due KM.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dueKm = _kmController.text.trim().isNotEmpty
          ? double.tryParse(_kmController.text.trim())
          : null;

      await ref.read(fleetServiceProvider).addServiceReminder(
            vehicleId: _selectedVehicleId!,
            serviceType: _selectedType,
            dueDate: _dueDate,
            dueKm: dueKm,
            notes: _notesController.text.trim(),
          );

      ref.invalidate(managerServiceRemindersProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return AlertDialog(
      title: const Text('Add Service Reminder'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                vehiclesAsync.when(
                  data: (vehicles) {
                    if (vehicles.isEmpty) {
                      return const Text('No vehicles available. Add vehicles first.');
                    }
                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Vehicle',
                      ),
                      initialValue: _selectedVehicleId,
                      items: vehicles.map((v) {
                        return DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.registrationNumber} (${v.type})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedVehicleId = val),
                      validator: (val) => val == null ? 'Please select a vehicle' : null,
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, _) => Text('Error loading vehicles: $err'),
                ),
                16.h,
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Service Type'),
                  initialValue: _selectedType,
                  items: _serviceTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
                16.h,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_dueDate == null
                            ? 'Select Date'
                            : DateFormat('MMM d, yyyy').format(_dueDate!)),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                        ),
                      ),
                    ),
                    if (_dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _dueDate = null),
                      ),
                  ],
                ),
                16.h,
                TextFormField(
                  controller: _kmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Due at KM (Optional)',
                    hintText: 'e.g. 50000',
                  ),
                ),
                16.h,
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: crmColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
