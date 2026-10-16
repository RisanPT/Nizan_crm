import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/employee.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../services/employee_service.dart';
import '../../service/timebox_service.dart';
import '../../../../core/error/errors.dart';
import '../../../../core/state/data_refresh.dart';

/// Shows an interactive dialog to link or unlink an employee to their
/// Timebox biometric/attendance account.
Future<Employee?> showTimeboxLinkDialog(
  BuildContext context,
  WidgetRef ref,
  Employee employee,
) async {
  return showDialog<Employee>(
    context: context,
    builder: (ctx) => _TimeboxLinkDialog(employee: employee),
  );
}

class _TimeboxLinkDialog extends ConsumerStatefulWidget {
  final Employee employee;

  const _TimeboxLinkDialog({required this.employee});

  @override
  ConsumerState<_TimeboxLinkDialog> createState() => _TimeboxLinkDialogState();
}

class _TimeboxLinkDialogState extends ConsumerState<_TimeboxLinkDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _manualIdCtrl = TextEditingController();
  int? _selectedTimeboxId;
  String _selectedTimeboxName = '';
  bool _isSaving = false;
  bool _showManualEntry = false;

  @override
  void initState() {
    super.initState();
    _selectedTimeboxId = widget.employee.timeboxEmployeeId;
    _selectedTimeboxName = widget.employee.timeboxName;
    if (_selectedTimeboxId != null) {
      _manualIdCtrl.text = _selectedTimeboxId.toString();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _manualIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLink([int? overrideId, String? overrideName]) async {
    final targetId = overrideId ??
        (_showManualEntry
            ? int.tryParse(_manualIdCtrl.text.trim())
            : _selectedTimeboxId);
    final targetName = overrideName ??
        (_showManualEntry
            ? (widget.employee.name)
            : _selectedTimeboxName);

    setState(() => _isSaving = true);
    try {
      final updated = await ref.read(employeeServiceProvider).linkTimebox(
            widget.employee.id,
            timeboxEmployeeId: targetId,
            timeboxName: targetName,
          );

      // Invalidate relevant providers to update the UI everywhere
      ref.invalidate(paginatedEmployeesProvider);
      ref.invalidate(employeesProvider);
      ref.invalidate(employeeByIdProvider(widget.employee.id));
      ref.refreshData.employees();
      ref.refreshData.hr();

      if (mounted) {
        Navigator.of(context).pop(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: targetId != null ? Colors.teal.shade800 : Colors.blueGrey.shade800,
            content: Text(
              targetId != null
                  ? 'Successfully linked ${widget.employee.name} to Timebox #$targetId ($targetName)'
                  : 'Unlinked ${widget.employee.name} from Timebox',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(friendlyErrorMessage(e)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final timeboxEmpsAsync = ref.watch(timeboxEmployeesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: crm.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fingerprint, color: Colors.teal, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Timebox Biometric Binding',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.employee.name} (${widget.employee.displayCode})',
                          style: TextStyle(
                            fontSize: 13,
                            color: crm.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Current Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.employee.isTimeboxLinked
                      ? Colors.teal.withValues(alpha: 0.08)
                      : Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.employee.isTimeboxLinked
                        ? Colors.teal.withValues(alpha: 0.25)
                        : Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.employee.isTimeboxLinked
                          ? Icons.check_circle_outline
                          : Icons.link_off,
                      size: 20,
                      color: widget.employee.isTimeboxLinked ? Colors.teal : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.employee.isTimeboxLinked
                                ? 'Currently Linked to Timebox #${widget.employee.timeboxEmployeeId}'
                                : 'Not Linked to Timebox',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: widget.employee.isTimeboxLinked
                                  ? Colors.teal
                                  : Colors.amber.shade900,
                            ),
                          ),
                          if (widget.employee.timeboxName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Profile Name: ${widget.employee.timeboxName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: crm.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.employee.isTimeboxLinked)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: _isSaving ? null : () => _saveLink(null, ''),
                        icon: const Icon(Icons.link_off, size: 14),
                        label: const Text('Unlink', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mode toggle: Select from live Timebox vs Manual ID
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showManualEntry
                        ? 'Enter Timebox Biometric ID Manually:'
                        : 'Select Timebox Account from Live Sync:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: crm.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showManualEntry = !_showManualEntry;
                      });
                    },
                    child: Text(
                      _showManualEntry ? 'Browse Live Profiles' : 'Manual ID Entry',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Body content
              if (_showManualEntry) ...[
                TextField(
                  controller: _manualIdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Timebox Employee ID (Integer)',
                    hintText: 'e.g. 14',
                    prefixIcon: const Icon(Icons.numbers, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tip: Check your Timebox dashboard for the staff member\'s numeric employee ID.',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
                const Spacer(),
              ] else ...[
                // Search field
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, department, or #ID...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),

                // List of Timebox employees
                Expanded(
                  child: timeboxEmpsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 36, color: crm.destructive),
                          const SizedBox(height: 8),
                          Text('Failed to load Timebox staff', style: TextStyle(fontWeight: FontWeight.bold, color: crm.textPrimary)),
                          const SizedBox(height: 4),
                          Text(friendlyErrorMessage(err), style: TextStyle(fontSize: 11, color: crm.textSecondary), textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            onPressed: () => ref.invalidate(timeboxEmployeesProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (tbList) {
                      final query = _searchCtrl.text.trim().toLowerCase();
                      final empNameNorm = widget.employee.name.toLowerCase().trim();
                      final empEmailNorm = widget.employee.email.toLowerCase().trim();

                      final filtered = tbList.where((tb) {
                        if (query.isEmpty) return true;
                        final name = tb.fullName.toLowerCase();
                        final email = tb.email.toLowerCase();
                        final dept = tb.department.toLowerCase();
                        final idStr = tb.id.toString();
                        return name.contains(query) ||
                            email.contains(query) ||
                            dept.contains(query) ||
                            idStr.contains(query);
                      }).toList();

                      // Sort with recommended matches first
                      filtered.sort((a, b) {
                        final aMatch = (empEmailNorm.isNotEmpty && a.email.toLowerCase() == empEmailNorm) ||
                            a.fullName.toLowerCase() == empNameNorm;
                        final bMatch = (empEmailNorm.isNotEmpty && b.email.toLowerCase() == empEmailNorm) ||
                            b.fullName.toLowerCase() == empNameNorm;
                        if (aMatch && !bMatch) return -1;
                        if (!aMatch && bMatch) return 1;
                        return a.fullName.compareTo(b.fullName);
                      });

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            'No Timebox employees matching "$query"',
                            style: TextStyle(color: crm.textSecondary, fontSize: 13),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final tb = filtered[i];
                          final isSelected = _selectedTimeboxId == tb.id;
                          final isExactName = tb.fullName.toLowerCase().trim() == empNameNorm;
                          final isExactEmail = empEmailNorm.isNotEmpty && tb.email.toLowerCase().trim() == empEmailNorm;
                          final isRecommended = isExactEmail || isExactName;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            tileColor: isSelected
                                ? Colors.teal.withValues(alpha: 0.12)
                                : (isRecommended
                                    ? Colors.amber.withValues(alpha: 0.05)
                                    : null),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected
                                  ? Colors.teal
                                  : (isRecommended ? Colors.amber.shade700 : crm.primary.withValues(alpha: 0.15)),
                              child: Text(
                                tb.fullName.isNotEmpty ? tb.fullName.substring(0, 1).toUpperCase() : '#',
                                style: TextStyle(
                                  color: isSelected || isRecommended ? Colors.white : crm.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    tb.fullName,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#${tb.id}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                  ),
                                ),
                                if (isRecommended) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isExactEmail ? 'Email Match' : 'Name Match',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '${tb.department.isNotEmpty ? tb.department : "General"} • ${tb.email.isNotEmpty ? tb.email : "No email"}',
                              style: TextStyle(fontSize: 11, color: crm.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.teal, size: 20)
                                : (isRecommended
                                    ? const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.amber)
                                    : null),
                            onTap: () {
                              setState(() {
                                _selectedTimeboxId = tb.id;
                                _selectedTimeboxName = tb.fullName;
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Bottom Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving
                        ? null
                        : () {
                            if (_showManualEntry) {
                              final id = int.tryParse(_manualIdCtrl.text.trim());
                              if (id == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid numeric Timebox ID')),
                                );
                                return;
                              }
                              _saveLink(id, widget.employee.name);
                            } else {
                              if (_selectedTimeboxId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a Timebox account to link')),
                                );
                                return;
                              }
                              _saveLink(_selectedTimeboxId, _selectedTimeboxName);
                            }
                          },
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.link, size: 16),
                    label: Text(_isSaving ? 'Saving...' : 'Save Binding'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
