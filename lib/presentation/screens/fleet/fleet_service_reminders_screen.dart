import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/fleet_service.dart';
import '../../../models/fleet_models.dart';
import '../../../services/vehicle_service.dart';
import 'package:intl/intl.dart';

class FleetServiceRemindersScreen extends ConsumerStatefulWidget {
  const FleetServiceRemindersScreen({super.key});

  @override
  ConsumerState<FleetServiceRemindersScreen> createState() => _FleetServiceRemindersScreenState();
}

class _FleetServiceRemindersScreenState extends ConsumerState<FleetServiceRemindersScreen> {
  bool _hasShownPopup = false;

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(managerServiceRemindersProvider);

    // Show popup for urgent reminders after build phase
    if (remindersAsync.hasValue && !_hasShownPopup) {
      final reminders = remindersAsync.value!;
      final urgentReminders = reminders.where((r) {
        if (r.status == 'completed') return false;
        
        // Check date
        if (r.dueDate != null) {
          final diff = r.dueDate!.difference(DateTime.now()).inDays;
          if (diff <= 3) return true; // Due within 3 days or overdue
        }
        
        // Check KM
        if (r.dueKm != null && r.vehicle != null && r.vehicle is Map) {
          final currentKm = (r.vehicle['currentKm'] as num?)?.toDouble() ?? 0.0;
          if (r.dueKm! - currentKm <= 500) return true; // Due within 500 km or overdue
        }
        
        return false;
      }).toList();

      if (urgentReminders.isNotEmpty) {
        _hasShownPopup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showUrgentRemindersPopup(urgentReminders);
        });
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: remindersAsync.when(
              data: (reminders) {
                if (reminders.isEmpty) {
                  return const Center(child: Text('No service reminders found.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reminders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    return _buildReminderCard(context, reminder);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderDialog(context),
        backgroundColor: const Color(0xFF4A1942),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Reminder', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Service Reminders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              SizedBox(height: 4),
              Text('Manage vehicle maintenance, pollution, tax, and insurance', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, ServiceReminder reminder) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isCompleted = reminder.status == 'completed';
    
    // Determine urgency color
    Color statusColor = Colors.grey;
    String statusText = 'Normal';
    
    if (isCompleted) {
      statusColor = const Color(0xFF4CAF50);
      statusText = 'Completed';
    } else {
      bool isUrgent = false;
      bool isOverdue = false;
      
      if (reminder.dueDate != null) {
        final diff = reminder.dueDate!.difference(DateTime.now()).inDays;
        if (diff < 0) {
          isOverdue = true;
        } else if (diff <= 3) {
          isUrgent = true;
        }
      }
      
      if (reminder.dueKm != null && reminder.vehicle != null && reminder.vehicle is Map) {
        final currentKm = (reminder.vehicle['currentKm'] as num?)?.toDouble() ?? 0.0;
        final diffKm = reminder.dueKm! - currentKm;
        if (diffKm < 0) {
          isOverdue = true;
        } else if (diffKm <= 500) {
          isUrgent = true;
        }
      }
      
      if (isOverdue) {
        statusColor = Colors.red;
        statusText = 'Overdue';
      } else if (isUrgent) {
        statusColor = Colors.orange;
        statusText = 'Due Soon';
      } else {
        statusColor = Colors.blue;
        statusText = 'Upcoming';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getIconForType(reminder.serviceType), color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reminder.serviceType,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        _extractVehicleName(reminder.vehicle),
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (reminder.dueDate != null)
             _buildDetailRow(Icons.calendar_month, 'Due Date: ', dateFormat.format(reminder.dueDate!)),
          if (reminder.dueKm != null)
             _buildDetailRow(Icons.speed, 'Due KM: ', '${reminder.dueKm} km'),
          if (reminder.notes != null && reminder.notes!.isNotEmpty)
             _buildDetailRow(Icons.notes, 'Notes: ', reminder.notes!),
          
          if (!isCompleted) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _completeReminder(reminder.id),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Mark as Completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'pollution': return Icons.cloud_outlined;
      case 'insurance': return Icons.shield_outlined;
      case 'tax': return Icons.receipt_long_outlined;
      case 'maintenance': return Icons.build_outlined;
      case 'oil change': return Icons.water_drop_outlined;
      default: return Icons.car_repair_outlined;
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

  void _showUrgentRemindersPopup(List<ServiceReminder> urgentReminders) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
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
                      color: Colors.orange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notification_important_rounded, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Urgent Service Reminders',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: urgentReminders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final r = urgentReminders[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(_getIconForType(r.serviceType), color: Colors.red, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.serviceType} for ${_extractVehicleName(r.vehicle)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E)),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.warning_rounded, color: Colors.red, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      r.dueDate != null ? 'Due: ${DateFormat('MMM d, yyyy').format(r.dueDate!)}' : 'Due at ${r.dueKm} km',
                                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF4A1942),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Acknowledge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as completed!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                      decoration: const InputDecoration(
                        labelText: 'Select Vehicle',
                        border: OutlineInputBorder(),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Service Type',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _selectedType,
                  items: _serviceTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
                const SizedBox(height: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _kmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Due at KM (Optional)',
                    hintText: 'e.g. 50000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
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
            backgroundColor: const Color(0xFF4A1942),
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

