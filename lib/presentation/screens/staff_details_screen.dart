import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../../core/models/employee.dart';
import '../../core/theme/crm_theme.dart';
import '../../services/employee_service.dart';
import '../../core/models/salary_increment.dart';
import '../../providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/hr/data/evaluation_models.dart';
import 'package:nizan_crm/features/hr/service/evaluation_service.dart';

final staffIncrementsProvider = FutureProvider.family.autoDispose<List<SalaryIncrement>, String>((ref, employeeId) {
  return ref.watch(employeeServiceProvider).getIncrements(employeeId);
});

class StaffDetailsScreen extends ConsumerStatefulWidget {
  final Employee employee;

  const StaffDetailsScreen({super.key, required this.employee});

  @override
  ConsumerState<StaffDetailsScreen> createState() => _StaffDetailsScreenState();
}

class _StaffDetailsScreenState extends ConsumerState<StaffDetailsScreen> {
  late Employee _employee;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 1080,
      );
      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      final Uint8List bytes = await image.readAsBytes();
      
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: image.name,
        ),
      });

      final dio = ref.read(dioProvider);
      final response = await dio.post('/upload', data: formData);
      
      if (response.statusCode == 200) {
        final imageUrl = response.data['url'] as String;
        
        final updatedEmployee = await ref.read(employeeServiceProvider).saveEmployee(
          id: _employee.id,
          name: _employee.name,
          email: _employee.email,
          type: _employee.type,
          artistRole: _employee.artistRole,
          specialization: _employee.specialization,
          phone: _employee.phone,
          status: _employee.status,
          regionId: _employee.regionId,
          category: _employee.category,
          department: _employee.department,
          profileImage: imageUrl,
          zoneId: _employee.zoneId,
          stateId: _employee.stateId,
          districtId: _employee.districtId,
          pincodeId: _employee.pincodeId,
        );

        setState(() {
          _employee = updatedEmployee;
        });

        ref.invalidate(employeesProvider);
        ref.invalidate(paginatedEmployeesProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _showAddIncrementDialog() async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Salary Increment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New Base Salary', prefixText: '₹'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (e.g. Annual Review)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newSalary = double.tryParse(amountCtrl.text);
              if (newSalary == null || newSalary <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid salary amount')));
                return;
              }
              try {
                await ref.read(employeeServiceProvider).addIncrement(
                  _employee.id,
                  newSalary: newSalary,
                  reason: reasonCtrl.text,
                );
                
                final updatedEmp = await ref.read(employeeServiceProvider).getEmployeeById(_employee.id);
                setState(() => _employee = updatedEmp);
                ref.invalidate(employeesProvider);
                ref.invalidate(paginatedEmployeesProvider);
                ref.invalidate(staffIncrementsProvider(_employee.id));
                
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
      'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  Color _scoreColor(double v) {
    if (v >= 4) return const Color(0xFF16A34A);
    if (v >= 2.5) return const Color(0xFFF59E0B);
    if (v > 0) return const Color(0xFFDC2626);
    return const Color(0xFF6B7280);
  }

  /// 5-Pillar Scorecard — latest evaluation's pillar bars + composite, with a
  /// link to the HR Evaluation screen to add/edit. Read-only here.
  Widget _scorecardCard(ThemeData theme, CrmTheme crmColors) {
    final async = ref.watch(employeeEvaluationsProvider(_employee.id));
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crmColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5-Pillar Scorecard',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => context.go('/hr/evaluation'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Evaluate'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Scorecard unavailable',
                  style: TextStyle(color: crmColors.textSecondary)),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                      'No evaluations yet. Use the HR → 5-Pillar Evaluation screen.',
                      style: TextStyle(color: crmColors.textSecondary));
                }
                final latest = list.first; // sorted desc by backend
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(latest.composite.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: _scoreColor(latest.composite))),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                              'composite · ${_mon[latest.month]} ${latest.year}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: crmColors.textSecondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final p in kPillars)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(kPillarLabels[p]!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: crmColors.textSecondary)),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: LinearProgressIndicator(
                                  value: (latest.pillar(p) / 5).clamp(0, 1),
                                  minHeight: 8,
                                  backgroundColor: crmColors.border,
                                  valueColor: AlwaysStoppedAnimation(
                                      _scoreColor(latest.pillar(p))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(latest.pillar(p).toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    if (list.length > 1) ...[
                      const SizedBox(height: 12),
                      Text('History',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: crmColors.textPrimary)),
                      const SizedBox(height: 6),
                      for (final ev in list.take(6))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_mon[ev.month]} ${ev.year}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: crmColors.textSecondary)),
                              Text(ev.composite.toStringAsFixed(1),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _scoreColor(ev.composite))),
                            ],
                          ),
                        ),
                    ],
                    if (latest.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('"${latest.notes}"',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: crmColors.textSecondary)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    
    final isArtist = _employee.artistRole == 'artist';
    final isDriver = _employee.artistRole == 'driver';
    final isAssistant = _employee.artistRole == 'assistant';
    final isOps = isDriver || isArtist || isAssistant || _employee.category == 'operations' || _employee.category == 'creative';
    final isAdmin = !isOps;
    
    final levelLabel = isAdmin
        ? (_employee.department ?? 'Administrative')
        : (isArtist ? 'Artist' : (isDriver ? 'Fleet Driver' : 'Assistant'));
    final levelColor = isAdmin
        ? Colors.indigo
        : (isArtist 
            ? crmColors.accent 
            : (isDriver ? Colors.orange : crmColors.primary));
    final levelBackground = levelColor.withValues(alpha: 0.12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Details'),
        backgroundColor: crmColors.surface,
        foregroundColor: crmColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: crmColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: levelColor.withValues(alpha: 0.1),
                    backgroundImage: _employee.profileImage.isNotEmpty 
                        ? NetworkImage(_employee.profileImage) 
                        : null,
                    child: _employee.profileImage.isEmpty
                        ? Text(
                            _employee.name.isNotEmpty
                                ? _employee.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: levelColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 48,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _isUploading
                        ? const CircularProgressIndicator()
                        : CircleAvatar(
                            backgroundColor: crmColors.primary,
                            radius: 20,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              onPressed: _pickAndUploadImage,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _employee.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: crmColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    levelLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: levelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isAdmin ? Colors.teal : crmColors.accent).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAdmin ? 'Administrative' : 'Operations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isAdmin ? Colors.teal : crmColors.accent,
                    ),
                  ),
                ),
                if (_employee.type == 'in-house') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: crmColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'In-House',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: crmColors.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: crmColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact & Role Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 32),
                    if (isAdmin) ...[
                      _buildInfoRow(Icons.apartment_outlined, 'Department', _employee.department ?? 'General', crmColors),
                      const SizedBox(height: 16),
                      if (_employee.role?.isNotEmpty == true || _employee.specialization.isNotEmpty) ...[
                        _buildInfoRow(Icons.badge_outlined, 'Designation', _employee.role?.isNotEmpty == true ? _employee.role! : _employee.specialization, crmColors),
                        const SizedBox(height: 16),
                      ],
                    ] else ...[
                      _buildInfoRow(Icons.work_outline, 'Specialization', _employee.specialization.isEmpty ? 'General' : _employee.specialization, crmColors),
                      const SizedBox(height: 16),
                    ],
                    _buildInfoRow(Icons.phone_outlined, 'Phone', _employee.phone.isEmpty ? 'Not provided' : _employee.phone, crmColors),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.email_outlined, 'Email', _employee.email.isEmpty ? 'Not provided' : _employee.email, crmColors),
                    const SizedBox(height: 16),
                    if (!isAdmin) ...[
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        'Assigned Area',
                        [
                          if (_employee.zoneName.isNotEmpty) _employee.zoneName,
                          if (_employee.stateName.isNotEmpty) _employee.stateName,
                          if (_employee.regionName.isNotEmpty) _employee.regionName,
                          if (_employee.districtName.isNotEmpty) _employee.districtName,
                          if (_employee.pincodeCode.isNotEmpty) _employee.pincodeCode,
                        ].isEmpty
                            ? 'Not assigned'
                            : [
                                if (_employee.zoneName.isNotEmpty) _employee.zoneName,
                                if (_employee.stateName.isNotEmpty) _employee.stateName,
                                if (_employee.regionName.isNotEmpty) _employee.regionName,
                                if (_employee.districtName.isNotEmpty) _employee.districtName,
                                if (_employee.pincodeCode.isNotEmpty) _employee.pincodeCode,
                              ].join(' → '),
                        crmColors,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _scorecardCard(theme, crmColors),
            const SizedBox(height: 32),
            if (isAdmin)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: crmColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Salary History',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showAddIncrementDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Increment'),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      _buildInfoRow(Icons.payments_outlined, 'Current Base Salary', '₹${_employee.baseSalary.toStringAsFixed(0)}', crmColors),
                      const SizedBox(height: 24),
                      Consumer(
                        builder: (context, ref, child) {
                          final asyncIncrements = ref.watch(staffIncrementsProvider(_employee.id));
                          return asyncIncrements.when(
                            data: (increments) {
                              if (increments.isEmpty) {
                                return const Text('No salary increments recorded.');
                              }
                              return Column(
                                children: increments.map((inc) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Increment to ₹${inc.newSalary.toStringAsFixed(0)}'),
                                  subtitle: Text('Previous: ₹${inc.previousSalary.toStringAsFixed(0)} • ${inc.reason}'),
                                  trailing: Text(inc.effectiveDate.toLocal().toString().split(' ')[0]),
                                )).toList(),
                              );
                            },
                            loading: () => const CircularProgressIndicator(),
                            error: (err, stack) => Text(friendlyErrorMessage(err)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, dynamic crmColors) {
    return Row(
      children: [
        Icon(icon, color: crmColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: crmColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: crmColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
